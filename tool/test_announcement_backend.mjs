// Run after: npm install --prefix .dart_tool/sql-validation --ignore-scripts @electric-sql/pglite@0.5.8
// This ephemeral PostgreSQL database never connects to a live Supabase project.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '../.dart_tool/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';

const db = new PGlite();
const resident = '11111111-1111-4111-8111-111111111111';
const officer = '22222222-2222-4222-8222-222222222222';
const other = '33333333-3333-4333-8333-333333333333';
const neighbour = '44444444-4444-4444-8444-444444444444';
let checks = 0;
function check(condition, message) { assert.ok(condition, message); checks++; }
async function denied(action, code = '42501') {
  await assert.rejects(action, e => e.code === code); checks++;
}
async function asUser(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [id ?? '']);
  await db.exec('set role ' + role);
}
async function rpc(name, values = [], types = []) {
  const params = values.map((_, i) => '$' + (i + 1) + (types[i] ? '::' + types[i] : '')).join(',');
  const result = await db.query('select public.' + name + '(' + params + ') as value', values);
  return result.rows[0].value;
}
try {
  // Minimal Supabase platform contracts. Storage HTTP and JWT validation require staging tests.
  await db.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create schema auth;
    create schema storage;
    create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
    create table storage.buckets(id text primary key, name text, public boolean,
      file_size_limit bigint, allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(), bucket_id text, name text);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select, insert on storage.objects to authenticated;
  `);
  await db.exec(await readFile(new URL('../supabase/migrations/202609290001_report_workflow.sql', import.meta.url), 'utf8'));
  check(true, 'migration executes');
  await db.exec(`
    insert into civic_private.authorities values
      ('a', '{"name":"Authority A","type":"Council","district":"District","province":"Province","center":{"latitude":7,"longitude":80}}'),
      ('b', '{"name":"Authority B","type":"Council","district":"District","province":"Province","center":{"latitude":8,"longitude":81}}');
    insert into civic_private.departments values ('roads','a','{"name":"Roads","categories":["Road Damage"]}');
  `);
  for (const id of [resident, officer, other, neighbour]) {
    await db.query("insert into auth.users(id,email,raw_user_meta_data) values($1,$2,'{\"full_name\":\"Test Resident\"}')",
      [id, id + '@example.test']);
    await asUser(id);
    await rpc('civic_bootstrap');
    const p = {id,fullName:'Test Resident',role:'citizen',isActive:true,
      localAuthorityId:id === other ? 'b' : 'a',ward:'Ward 1',gnDivision:'Division',
      phone:'',preferredLanguage:'en',onboardingComplete:true,residentialArea:null};
    await rpc('civic_save_profile_notifications',[JSON.stringify([p]),'[]'],['jsonb','jsonb']);
    await db.exec('reset role');
  }
  await db.query("update civic_private.profiles set role='officer' where id=$1", [officer]);

  await db.exec(await readFile(new URL('../supabase/migrations/202609300001_project_workflow.sql', import.meta.url), 'utf8'));

  await db.exec(await readFile(new URL('../supabase/migrations/202610020001_announcement_workflow.sql', import.meta.url), 'utf8'));
  await db.exec('reset role');
  await db.query("update civic_private.profiles set data=data||'{\"ward\":\"Ward 2\"}'::jsonb where id=$1",[neighbour]);
  const draft={id:'a-first',authorityId:'a',revision:0,title:'Water service interruption',
    body:'Water will be unavailable during planned maintenance tomorrow.',type:'serviceInterruption',
    department:'Roads',targetWard:'Ward 1',targetDivision:'Division',targetLabel:'UNTRUSTED',
    isPinned:false,isPublished:false};
  const save=a=>rpc('civic_save_announcement',[JSON.stringify(a)],['jsonb']);
  const list=(offset=0,size=25)=>rpc('civic_list_announcements',[offset,size],['integer','integer']);
  const get=id=>rpc('civic_get_announcement',[id],['text']);
  const preference=(id,reacted=null,saved=null)=>rpc('civic_set_feed_preference',[id,reacted,saved],['text','boolean','boolean']);
  const comment=(id,cid,message)=>rpc('civic_add_feed_comment',[id,cid,message],['text','text','text']);
  await asUser(null,'anon');
  check((await list()).total===0,'anonymous has no notices');
  await denied(()=>save(draft));
  await asUser(resident);
  await denied(()=>save(draft));
  await denied(()=>db.query('select * from civic_private.announcements'));
  await asUser(officer);
  let a=await save(draft);
  check(a.revision===1&&!a.isPublished,'draft persisted');
  check(a.targetLabel==='Ward 1 / Division','target label comes from targeting fields');
  check((await save(draft)).revision===1,'create retry is idempotent');
  await denied(()=>save({...draft,title:'Changed request title'}),'40001');
  await denied(()=>save({...a,authorityId:'b'}));
  for(const invalid of [{title:123},{title:'short'},{body:'short'},{type:'bad'},{department:'missing'},
    {targetWard:null},{isPublished:'true'},{revision:'1'}]) {
    await denied(()=>save({...a,...invalid}),'22023');
  }
  await asUser(resident);
  check((await list()).total===0,'draft hidden from resident');
  await denied(()=>get(a.id));
  await denied(()=>preference(a.id,true));
  await denied(()=>comment(a.id,'c-draft','Not allowed'));
  await asUser(officer);
  a=await save({...a,isPublished:true});
  check(a.revision===2,'publishing advances revision');
  await denied(()=>save({...a,revision:1,title:'Stale edit title'}),'40001');
  await asUser(resident);
  check((await list()).total===1,'matching ward and division receive publication');
  check((await rpc('civic_bootstrap')).notifications.length===1,'matching recipient gets notification');
  let f=await preference(a.id,true);
  check(f.reactionCount===1&&f.reactedUserIds[0]===resident,'reaction belongs to caller');
  check((await preference(a.id,true)).reactionCount===1,'reaction retry does not double count');
  f=await preference(a.id,null,true);
  check(f.reactionCount===1&&f.savedUserIds[0]===resident,'saving preserves reaction');
  f=await comment(a.id,'c-first','  Please confirm the restoration time.  ');
  check(f.commentCount===1&&f.comments[0].message==='Please confirm the restoration time.','comment text is stored');
  check(f.comments[0].author==='Test Resident'&&!f.comments[0].isVerified,'server establishes comment identity');
  check((await comment(a.id,'c-first','Please confirm the restoration time.')).commentCount===1,'comment retry is idempotent');
  await denied(()=>comment(a.id,'c-first','Changed text'),'40001');
  await denied(()=>comment(a.id,'c-empty',' '),'22023');
  await denied(()=>comment(a.id,'c-long','x'.repeat(2001)),'22023');
  await denied(()=>preference(a.id),'22023');
  await asUser(neighbour);
  check((await list()).total===0,'wrong ward cannot list notice');
  check((await rpc('civic_bootstrap')).notifications.length===0,'wrong ward not notified');
  await denied(()=>get(a.id));
  await denied(()=>preference(a.id,true));
  await denied(()=>comment(a.id,'c-other','Wrong ward'));
  await asUser(other);
  check((await list()).total===0,'other authority cannot list');
  await denied(()=>get(a.id));
  await denied(()=>preference(a.id,true));
  await asUser(officer);
  f=await get(a.id);
  check(f.reactionCount===1&&f.reactedUserIds.length===0&&f.savedUserIds.length===0,'other participant identities stay private');
  await denied(()=>comment(a.id,'c-first','Please confirm the restoration time.'),'40001');
  a=await save({...a,targetWard:'',targetDivision:''});
  await asUser(neighbour);
  check((await list()).total===1,'all-authority target reaches second ward');
  check((await rpc('civic_bootstrap')).notifications.length===1,'new audience receives notification');
  await preference(a.id,true,true);
  await asUser(resident);
  f=await preference(a.id,false);
  check(f.reactionCount===1&&f.savedUserIds.length===1,'one caller cannot remove another reaction or overwrite saves');
  await asUser(officer);
  a=await save({...a,targetWard:'Ward 1',targetDivision:'Wrong division'});
  await asUser(resident);
  check((await list()).total===0,'division is checked as well as ward');
  await denied(()=>get(a.id));
  check((await rpc('civic_bootstrap')).notifications.length===0,'revoked audience loses stale notification content');
  await asUser(officer);
  a=await save({...a,targetDivision:'Division'});
  a=await save({...a,isPublished:false});
  await asUser(resident);
  await denied(()=>get(a.id));
  await denied(()=>preference(a.id,true));
  await denied(()=>comment(a.id,'c-archived','Unavailable'));
  await asUser(officer);
  a=await save({...a,isPublished:true});
  await asUser(resident);
  check((await rpc('civic_bootstrap')).notifications.length===0,'republishing does not repeat delivery');
  check((await get(a.id)).comments[0].message==='Please confirm the restoration time.','comments survive unpublication');
  await asUser(officer);
  for(let i=0;i<27;i++) await save({...draft,id:'a-page-'+String(i).padStart(2,'0'),isPublished:true});
  const first=await list(0,25), second=await list(25,25);
  check(first.total===28&&first.announcements.length===25&&second.announcements.length===3,'listing paginates');
  check(new Set([...first.announcements,...second.announcements].map(a=>a.id)).size===28,'stable pages have no duplicates');
  await denied(()=>list(-1),'22023');
  await denied(()=>list(0,101),'22023');
  await db.exec('reset role');
  await db.query('update civic_private.profiles set active=false where id=$1',[resident]);
  await asUser(resident);
  await denied(()=>list());
  await denied(()=>get(a.id));
  await denied(()=>preference(a.id,true));
  await denied(()=>comment(a.id,'c-inactive','Unavailable'));
  await db.exec('reset role');
  await db.query('update civic_private.profiles set active=false where id=$1',[officer]);
  await asUser(officer);
  await denied(()=>save(a));
  console.log('Announcement backend: '+checks+' checks passed.');
} finally { await db.close(); }
