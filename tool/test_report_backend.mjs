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
  await db.exec(await readFile(new URL('../supabase/migrations/202610070001_notification_refresh.sql', import.meta.url), 'utf8'));
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
  await asUser(null, 'anon');
  const guest = await rpc('civic_bootstrap');
  await denied(() => rpc('civic_notifications'));
  await asUser(null);
  await denied(() => rpc('civic_notifications'));
  await asUser('55555555-5555-4555-8555-555555555555');
  await denied(() => rpc('civic_notifications'));
  await asUser(null, 'anon');
  check(guest.authorities.length === 2 && guest.reports.length === 0 && guest.users.length === 0, 'guest sees only reference data');
  await denied(() => rpc('civic_save_report',['{}',true],['jsonb','boolean']));
  await asUser(resident);
  await denied(() => db.query('select * from civic_private.reports'));
  await denied(() => rpc('civic_save_profile_notifications',[JSON.stringify([{
    id:resident,role:'platformAdmin',isActive:true
  }]),'[]'],['jsonb','jsonb']));
  const now = new Date().toISOString();
  const draft = {
    id:'r-test-001', caseNumber:'untrusted', title:'Damaged road near the school',
    description:'There is a large pothole at the entrance to the school.',
    category:'Road Damage', locationLabel:'School entrance',location:{latitude:7,longitude:80},
    status:'resolved',priority:'Normal',submittedAt:now,lastUpdated:now,department:'Fake',
    ownerUserId:resident,assignedOfficer:'Fake',attachments:[],updates:[],followerIds:[],
    internalNotes:[],revision:0,comments:[]
  };
  let saved = await rpc('civic_save_report',[JSON.stringify(draft),true],['jsonb','boolean']);
  check(saved.caseNumber.startsWith('SS-') && saved.caseNumber !== 'untrusted', 'server assigns case number');
  check(saved.status === 'submitted' && saved.department === 'Roads' && saved.assignedOfficer === null, 'server assigns initial workflow');
  const retry = await rpc('civic_save_report',[JSON.stringify(draft),true],['jsonb','boolean']);
  check(retry.id === saved.id && retry.revision === 1, 'lost-response retry is idempotent');
  let data = await rpc('civic_bootstrap');
  check(data.reports.length === 1 && data.notifications.length === 1, 'creation and notification committed once');
  await denied(() => rpc('civic_save_report',[JSON.stringify({...saved,status:'resolved'}),false],['jsonb','boolean']));
  const comment = {id:'untrusted',author:'Pretend officer',message:'Please inspect the school entrance.',
    createdAt:now,isVerified:true};
  saved = await rpc('civic_save_report',[JSON.stringify({...saved,comments:[comment]}),false],['jsonb','boolean']);
  check(saved.comments[0].author === 'Resident' && saved.comments[0].isVerified === false, 'server establishes comment identity');
  await denied(() => rpc('civic_save_report',[JSON.stringify({...saved,revision:1}),false],['jsonb','boolean']), '40001');
  await asUser(neighbour);
  check((await rpc('civic_bootstrap')).reports.length === 0, 'another resident cannot read reports');
  await denied(() => rpc('civic_save_report',[JSON.stringify(saved),false],['jsonb','boolean']));
  await db.exec('reset role');
  await db.query("update civic_private.profiles set role='officer' where id=$1", [other]);
  await asUser(other);
  check((await rpc('civic_bootstrap')).reports.length === 0, 'other authority cannot read reports');
  await denied(() => rpc('civic_save_report',[JSON.stringify(saved),false],['jsonb','boolean']));
  await asUser(officer);
  data = await rpc('civic_bootstrap');
  check(data.reports.length === 1 && data.notifications.length === 0, 'officer sees authority reports without resident notifications');
  const privateNote = 'Internal inspection note';
  const update = {...saved,status:'resolved',internalNotes:[privateNote],
    updates:[...saved.updates,{status:'resolved',message:'The road has been repaired.',date:now,isPublic:true}]};
  saved = await rpc('civic_save_report',[JSON.stringify(update),false],['jsonb','boolean']);
  check(saved.internalNotes[0] === privateNote, 'officer can save private notes');
  await asUser(resident);
  data = await rpc('civic_bootstrap');
  check(data.reports[0].status === 'resolved' && data.reports[0].internalNotes.length === 0, 'resident sees status but no internal notes');
  check(data.notifications.length === 2, 'resident receives the officer update');
  const refreshed = await rpc('civic_notifications');
  check(refreshed.length === 2, 'dedicated refresh returns recipient notifications');
  const notificationId = refreshed[0].id;
  await rpc('civic_save_profile_notifications', ['[]', JSON.stringify([
    {id:notificationId,isRead:true}
  ])], ['jsonb','jsonb']);
  check((await rpc('civic_notifications')).find(n => n.id === notificationId).isRead,
    'refresh returns persisted read state');
  await asUser(neighbour);
  check((await rpc('civic_notifications')).length === 0, 'same-authority resident cannot read another recipient');
  await asUser(officer);
  check((await rpc('civic_notifications')).length === 0, 'officer cannot read resident notifications');
  await asUser(other);
  check((await rpc('civic_notifications')).length === 0, 'another authority cannot read resident notifications');
  await asUser(resident);
  saved = data.reports[0];
  saved = await rpc('civic_save_report',[JSON.stringify({...saved,status:'inProgress',
    updates:[...saved.updates,{status:'inProgress',message:'Spoofed message',date:now,isPublic:true}]}),false],['jsonb','boolean']);
  check(saved.status === 'inProgress' && saved.updates.at(-1).message.includes('still needs attention'), 'resident can reopen with server-authored history');
  const n = data.notifications[0];
  await rpc('civic_save_profile_notifications',['[]',JSON.stringify([{id:n.id,isRead:true}])],['jsonb','jsonb']);
  check((await rpc('civic_bootstrap')).notifications.find(x=>x.id===n.id).isRead, 'notification read state persists');
  const beforeName = (await rpc('civic_bootstrap')).users[0].fullName;
  const profile = {...(await rpc('civic_bootstrap')).users[0],fullName:'Should roll back'};
  await denied(() => rpc('civic_save_profile_notifications',[JSON.stringify([profile]),
    '[{"id":"not-owned","isRead":true}]'],['jsonb','jsonb']));
  check((await rpc('civic_bootstrap')).users[0].fullName === beforeName, 'failed batch rolls back profile');
  await db.query("insert into storage.objects(bucket_id,name) values('report-evidence',$1)",[resident+'/evidence.jpg']);
  await asUser(neighbour);
  check((await db.query('select * from storage.objects')).rows.length === 0, 'unrelated residents cannot read private evidence');
  await denied(()=>db.query("insert into storage.objects(bucket_id,name) values('report-evidence',$1)",[resident+'/spoof.jpg']));
  await asUser(officer);
  let officerReport = (await rpc('civic_bootstrap')).reports[0];
  await db.query("insert into storage.objects(bucket_id,name) values('report-evidence',$1)",[officer+'/repair.jpg']);
  officerReport = await rpc('civic_save_report',[JSON.stringify({...officerReport,
    attachments:[officer+'/repair.jpg'],updates:[...officerReport.updates,
      {status:'inProgress',message:'Inspection photo attached.',date:now,isPublic:true}]}),false],['jsonb','boolean']);
  await asUser(resident);
  check((await db.query('select * from storage.objects where name=$1',[officer+'/repair.jpg'])).rows.length===1, 'resident can read attached officer evidence');
  await db.exec('reset role');
  await db.query('update civic_private.profiles set active=false where id=$1',[resident]);
  await asUser(resident);
  await denied(()=>rpc('civic_bootstrap'));
  await denied(()=>rpc('civic_notifications'));
  check((await db.query('select * from storage.objects')).rows.length===0,'inactive users cannot read evidence');
  console.log('PASS: ' + checks + ' PostgreSQL workflow and permission checks');
} finally { await db.close(); }
