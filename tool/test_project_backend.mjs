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
  const now = '2026-09-30T00:00:00.000Z';
  const draft = {
    id:'p-test-001', authorityId:'a', revision:0, title:'School road improvements',
    description:'Repair the road surface and provide a safer crossing for residents.',
    category:'Roads',locationLabel:'School entrance',location:{latitude:7,longitude:80},
    status:'planned',progress:0,startDate:now,expectedCompletion:'2027-09-30T00:00:00.000Z',
    department:'Roads',budget:500000,spent:25000,isBudgetPublic:false,contractor:'Builder',projectManager:'Officer',
    milestones:[{title:'Survey',description:'Survey the route',percentage:10,expectedDate:now,completedDate:null,isComplete:false}],
    updates:[{title:'Internal review',message:'Confidential tender note',date:now,isPublic:false}],
    documents:[{name:'Plan',kind:'PDF',sizeLabel:'Public document',url:'https://example.org/plan.pdf'}],
  };
  const save = p => rpc('civic_save_project',[JSON.stringify(p)],['jsonb']);
  const get = id => rpc('civic_get_project',[id],['text']);
  const list = (search='',status=null,sort='Latest',offset=0,size=25) =>
    rpc('civic_list_projects',[search,status,sort,offset,size],['text','text','text','integer','integer']);
  const follow = (id,value) => rpc('civic_follow_project',[id,value],['text','boolean']);
  await asUser(null,'anon');
  check((await list()).total===0,'anonymous listing has no authority data');
  await denied(() => save(draft));
  await asUser(resident);
  await denied(() => save(draft));
  await denied(() => db.query('select * from civic_private.projects'));
  await asUser(officer);
  let saved = await save(draft);
  check(saved.revision===1 && saved.authorityId==='a','server creates owned project');
  check(saved.budget===500000 && saved.updates.length===1,'officer can read private fields');
  check((await save(draft)).revision===1,'creation retry is idempotent');
  await denied(() => save({...draft,title:'Changed retry title'}),'40001');
  await denied(() => save({...saved,authorityId:'b'}));
  await denied(() => save({...saved,department:'Missing department'}),'22023');
  await denied(() => save({...saved,progress:101}),'22023');
  await denied(() => save({...saved,progress:'50'}),'22023');
  await denied(() => save({...saved,title:12345678}),'22023');
  await denied(() => save({...saved,contractor:{name:'Bad type'}}),'22023');
  await denied(() => save({...saved,milestones:[{...draft.milestones[0],percentage:'10'}]}),'22023');
  await denied(() => save({...saved,updates:[{...draft.updates[0],message:123}]}),'22023');
  await denied(() => save({...saved,documents:[{...draft.documents[0],name:123}]}),'22023');
  await denied(() => save({...saved,budget:-1}),'22023');
  await denied(() => save({...saved,expectedCompletion:'bad-date'}),'22023');
  await denied(() => save({...saved,documents:[{name:'Unsafe',url:'javascript:alert(1)'}]}),'22023');
  await denied(() => save({...saved,milestones:[{...draft.milestones[0],isComplete:true}]}),'22023');
  await asUser(other);
  check((await list()).total===0,'other authority cannot list project');
  await denied(() => get(saved.id));
  await denied(() => follow(saved.id,true));
  await asUser(resident);
  let visible = await get(saved.id);
  check(visible.budget===0 && visible.spent===0 && visible.updates.length===0,'private fields are removed server-side');
  check(visible.documents[0].url===draft.documents[0].url && visible.milestones.length===1,'documents and milestones persist');
  visible = await follow(saved.id,true);
  check(visible.followerIds.length===1 && visible.followerIds[0]===resident,'subscription identifies only caller');
  await follow(saved.id,true);
  await asUser(neighbour);
  check((await get(saved.id)).followerIds.length===0,'subscriber identity is private');
  await follow(saved.id,true);
  await asUser(officer);
  saved = await save({...saved,progress:20,updates:[...saved.updates,{title:'Works start',message:'Survey is complete.',date:now,isPublic:true}]});
  check(saved.revision===2 && saved.followerIds.length===0,'project edit does not overwrite subscriptions');
  await denied(() => save({...saved,revision:1,progress:40}),'40001');
  saved = await save({...saved,updates:[...saved.updates,{title:'Private',message:'Internal budget discussion.',date:now,isPublic:false}]});
  check((await save(saved)).revision===saved.revision,'unchanged save does not create a revision');
  await asUser(resident);
  let data = await rpc('civic_bootstrap');
  check(data.notifications.length===1 && data.notifications[0].route==='/projects/'+saved.id,'public change notifies subscriber once');
  check((await get(saved.id)).updates.length===1,'resident receives public updates only');
  await follow(saved.id,false);
  await asUser(officer);
  saved = await save({...saved,progress:40,isBudgetPublic:true});
  await asUser(resident);
  check((await rpc('civic_bootstrap')).notifications.length===1,'unfollow stops future notifications');
  check((await get(saved.id)).budget===500000,'published budget becomes visible');
  await asUser(neighbour);
  check((await rpc('civic_bootstrap')).notifications.length===2,'remaining subscriber receives next update');
  await asUser(officer);
  for(let i=0;i<27;i++) await save({...draft,id:'p-page-'+String(i).padStart(2,'0'),title:'Road project '+String(i).padStart(2,'0'),status:i%2?'completed':'planned',progress:i});
  const first = await list('Road project',null,'A-Z',0,25);
  const second = await list('Road project',null,'A-Z',25,25);
  check(first.total===27 && first.projects.length===25 && second.projects.length===2,'search is paginated');
  check(new Set([...first.projects,...second.projects].map(p=>p.id)).size===27,'stable pages do not duplicate IDs');
  check((await list('Road project','completed')).total===13,'status filter is applied before pagination');
  check((await list('Road project',null,'Most progress')).projects[0].progress===26,'server sorts all matching projects');
  check((await list('%')).total===0,'search treats wildcard characters literally');
  await denied(() => list('',null,'Latest',-1),'22023');
  await denied(() => list('',null,'Latest',0,101),'22023');
  await db.exec('reset role');
  await db.query('update civic_private.profiles set active=false where id=$1',[resident]);
  await asUser(resident);
  await denied(() => list());
  await denied(() => get(saved.id));
  await denied(() => follow(saved.id,true));
  await db.exec('reset role');
  await db.query('update civic_private.profiles set active=false where id=$1',[officer]);
  await asUser(officer);
  await denied(() => save(saved));
  console.log('Project backend: '+checks+' checks passed.');
} finally { await db.close(); }
