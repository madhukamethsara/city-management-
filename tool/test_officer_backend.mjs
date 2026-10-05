// Uses the existing ephemeral PostgreSQL test dependency; no live project access.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '../.dart_tool/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';

const db = new PGlite();
const admin = '11111111-1111-4111-8111-111111111111';
const resident = '22222222-2222-4222-8222-222222222222';
const outsider = '33333333-3333-4333-8333-333333333333';
let checks = 0;
async function asUser(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [id ?? '']);
  await db.exec('set role ' + role);
}
async function rpc(name, values = [], types = []) {
  const args = values.map((_, i) => `$${i + 1}::${types[i]}`).join(',');
  return (await db.query(`select public.${name}(${args}) as value`, values)).rows[0].value;
}
async function denied(action, code = '42501') {
  await assert.rejects(action, e => e.code === code); checks++;
}
function check(condition) { assert.ok(condition); checks++; }
try {
  await db.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create schema auth;
    create schema storage;
    create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create table storage.buckets(id text primary key,name text,public boolean,
      file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert on storage.objects to authenticated;
  `);
  for (const file of ['202609290001_report_workflow.sql','202609300001_project_workflow.sql',
    '202610020001_announcement_workflow.sql','202610040001_officer_management.sql',
    '202610050001_department_lifecycle.sql']) {
    await db.exec(await readFile(new URL('../supabase/migrations/' + file, import.meta.url), 'utf8'));
  }
  await db.exec(`
    insert into civic_private.authorities values ('a','{}'),('b','{}');
    insert into civic_private.departments(id,authority_id,data) values
      ('roads','a','{"name":"Roads","categories":["Road Damage"],"officerCount":0}'),
      ('other','b','{"name":"Other"}');
  `);
  for (const [id, authority, role] of [[admin,'a','localAuthorityAdmin'],
    [resident,'a','citizen'],[outsider,'b','citizen']]) {
    await db.query('insert into auth.users(id,email) values($1,$2)',[id,id+'@example.test']);
    await db.query(`insert into civic_private.profiles(id,authority_id,role,data)
      values($1,$2,$3,'{"fullName":"Test User","onboardingComplete":true}')`,[id,authority,role]);
  }
  const edit = (id, role = 'officer', active = true, expectedRole = 'citizen', expectedActive = true) =>
    rpc('civic_manage_user',[JSON.stringify({id,role,isActive:active,fullName:'Tampered'}),
      expectedRole,expectedActive],['jsonb','text','boolean']);
  const department = {id:'roads',name:'Tampered',headName:'New Head',officerCount:4,
    categories:['Road Damage','Drainage']};
  const saveDepartment = d => rpc('civic_save_department',[JSON.stringify(d)],['jsonb']);
  await asUser(null,'anon');
  check((await rpc('civic_bootstrap')).users.length === 0);
  await denied(() => edit(resident));
  await asUser(resident);
  check((await rpc('civic_bootstrap')).users.length === 1);
  await denied(() => edit(admin));
  await denied(() => saveDepartment(department));
  await asUser(admin);
  const users = (await rpc('civic_bootstrap')).users;
  check(users.length === 2 && !users.some(u => u.id === outsider));
  check(users.find(u => u.id === resident).email.endsWith('@example.test'));
  await denied(() => edit(admin));
  await denied(() => edit(outsider));
  await denied(() => edit(resident,'platformAdmin'));
  const saved = await edit(resident);
  check(saved.role === 'officer' && saved.fullName === 'Test User');
  await denied(() => edit(resident,'citizen'), '40001');
  check((await edit(resident,'officer',false,'officer')).isActive === false);
  await asUser(resident);
  await denied(() => rpc('civic_bootstrap'));
  await asUser(admin);
  check((await edit(resident,'departmentAdmin',true,'officer',false)).isActive === true);
  await denied(() => saveDepartment({...department,id:'other'}));
  await denied(() => saveDepartment({...department,officerCount:-1}), '22023');
  await denied(() => saveDepartment({...department,categories:[]}), '22023');
  await denied(() => saveDepartment({...department,categories:[5]}), '22023');
  const updated = await saveDepartment(department);
  check(updated.name === 'Roads' && updated.headName === 'New Head' && updated.officerCount === 4);
  await asUser(resident);
  check((await saveDepartment({...department,officerCount:5})).officerCount === 5);
  await denied(() => edit(admin));
  check((await rpc('civic_bootstrap')).departments[0].officerCount === 5);
  const newDepartment = {id:'parks',name:'Parks',headName:'Park Head',officerCount:0,
    categories:['Parks']};
  const createDepartment = d => rpc('civic_create_department',[JSON.stringify(d)],['jsonb']);
  const removeDepartment = d => rpc('civic_remove_department',[JSON.stringify(d)],['jsonb']);
  // Department admins retain editing permission but cannot create or remove departments.
  await denied(() => createDepartment(newDepartment));
  await denied(() => removeDepartment(updated));
  await asUser(null,'anon');
  await denied(() => createDepartment(newDepartment));
  await denied(() => removeDepartment(updated));
  await asUser(outsider);
  await denied(() => createDepartment(newDepartment));
  await asUser(admin);
  for (const invalid of [{name:''},{headName:''},{officerCount:-1},{officerCount:1.5},
    {categories:[]},{categories:[null]},{id:'bad id'}]) {
    await denied(() => createDepartment({...newDepartment,...invalid}), '22023');
  }
  await denied(() => createDepartment({...newDepartment,id:'other'}));
  const created = await createDepartment({...newDepartment,authorityId:'b',unexpected:'ignored'});
  check(created.name === 'Parks' && !('authorityId' in created) && !('unexpected' in created));
  check((await createDepartment(newDepartment)).id === created.id);
  await denied(() => createDepartment({...newDepartment,headName:'Changed'}), '40001');
  await denied(() => createDepartment({...newDepartment,id:'duplicate',name:' parks '}), '23505');
  await denied(() => removeDepartment({...created,headName:'stale'}), '40001');
  await denied(() => removeDepartment({id:'other'}));
  // Every civic ownership collection blocks removal, including drafts and historical cases.
  for (const table of ['reports','projects','announcements']) {
    await db.exec('reset role');
    if (table === 'reports') {
      await db.query(`insert into civic_private.reports(id,authority_id,owner_id,case_number,data)
        values('reference','a',$1,'CASE-REF','{"department":"Parks"}')`,[resident]);
    } else {
      await db.query(`insert into civic_private.${table}(id,authority_id,created_by,data,initial_payload)
        values('reference','a',$1,'{"department":"Parks"}','{}')`,[admin]);
    }
    await asUser(admin);
    await denied(() => removeDepartment(created), '23503');
    check((await rpc('civic_bootstrap')).departments.some(d => d.id === created.id));
    await db.exec('reset role');
    await db.exec(`delete from civic_private.${table} where id='reference'`);
  }
  await asUser(admin);
  await removeDepartment(created);
  await removeDepartment(created); // repeat after a lost response
  check(!(await rpc('civic_bootstrap')).departments.some(d => d.id === created.id));
  await db.exec('reset role');
  await db.query('update civic_private.profiles set active=false where id=$1',[admin]);
  await asUser(admin);
  await denied(() => createDepartment(newDepartment));
  await denied(() => removeDepartment(created));
  console.log(`Officer backend: ${checks} checks passed.`);
} finally { await db.close(); }
