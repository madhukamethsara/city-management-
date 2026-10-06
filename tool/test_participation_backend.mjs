import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '../.dart_tool/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';
const db = new PGlite();
const officer = '11111111-1111-4111-8111-111111111111';
const resident = '22222222-2222-4222-8222-222222222222';
const other = '33333333-3333-4333-8333-333333333333';
let checks = 0;
async function asUser(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [id ?? '']);
  await db.exec('set role ' + role);
}
async function rpc(name, values = [], types = []) {
  return (await db.query(`select public.${name}(${values.map((_,i)=>`$${i+1}::${types[i]}`).join(',')}) as value`,values)).rows[0].value;
}
async function denied(action, code='42501') { await assert.rejects(action,e=>e.code===code); checks++; }
function check(value) { assert.ok(value); checks++; }
const jsonRpc = (name,payload) => rpc(name,[JSON.stringify(payload)],['jsonb']);
try {
  await db.exec(`create role anon nologin; create role authenticated nologin;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated; grant select,insert on storage.objects to authenticated;`);
  for (const file of ['202609290001_report_workflow.sql','202609300001_project_workflow.sql',
    '202610020001_announcement_workflow.sql','202610040001_officer_management.sql',
    '202610050001_department_lifecycle.sql','202610060001_participation.sql',
    '202610060002_admin_observability.sql','202610060003_project_feedback.sql',
    '202610060004_project_assets.sql']) {
    await db.exec(await readFile(new URL('../supabase/migrations/'+file,import.meta.url),'utf8'));
  }
  await db.exec(`insert into civic_private.authorities values ('a','{}'),('b','{}');
    insert into civic_private.departments values ('roads','a','{"name":"Roads"}');`);
  for (const [id,authority,role] of [[officer,'a','officer'],[resident,'a','citizen'],[other,'b','citizen']]) {
    await db.query('insert into auth.users(id,email) values($1,$2)',[id,id+'@example.test']);
    await db.query(`insert into civic_private.profiles(id,authority_id,role,data)
      values($1,$2,$3,'{"fullName":"Server Author","onboardingComplete":true}')`,[id,authority,role]);
  }
  const proposal = {id:'pr-test',title:'Safer school crossing',description:'Install a safer crossing at the busy school entrance.',
    category:'Roads',locationLabel:'School road',expectedBenefit:'Children can safely cross the busy road.',attachments:[]};
  const createProposal = p => jsonRpc('civic_create_proposal',p);
  const preference = (support,follow) => rpc('civic_proposal_preference',['pr-test',support,follow],['text','boolean','boolean']);
  const comment = (id,message) => rpc('civic_proposal_comment',['pr-test',id,message],['text','text','text']);
  const review = (status,revision) => rpc('civic_review_proposal',['pr-test',status,revision],['text','text','integer']);
  await asUser(null,'anon');
  check((await rpc('civic_participation')).proposals.length===0);
  await denied(()=>createProposal(proposal));
  await asUser(resident);
  await denied(()=>rpc('civic_analytics'));
  await denied(()=>rpc('civic_audit_events'));
  await denied(()=>createProposal({...proposal,title:''}),'22023');
  await denied(()=>createProposal({...proposal,attachments:['fake.png']}),'22023');
  const created = await createProposal({...proposal,author:'Forged',status:'approved'});
  check(created.author==='Server Author' && created.status==='submitted' && created.supportCount===1);
  check((await createProposal({...proposal,author:'Forged',status:'approved'})).id===created.id);
  await denied(()=>createProposal(proposal),'40001');
  check((await preference(false,null)).supportCount===0);
  check((await preference(true,null)).supportCount===1);
  check((await preference(true,null)).supportCount===1);
  check((await comment('pc-test','Please include a raised crossing.')).comments.length===1);
  check((await comment('pc-test','Please include a raised crossing.')).comments.length===1);
  await denied(()=>comment('pc-test','Changed'),'40001');
  await denied(()=>comment('pc-empty',''),'22023');
  await denied(()=>review('approved',1));
  await asUser(other);
  check((await rpc('civic_participation')).proposals.length===0);
  await denied(()=>preference(true,true));
  await denied(()=>comment('pc-other','No access'));
  await denied(()=>createProposal(proposal));
  await asUser(officer);
  const officerView = (await rpc('civic_participation')).proposals[0];
  check(officerView.supportCount===1 && officerView.supporterIds.length===0 && officerView.followerIds.length===0);
  check((await review('technicalReview',1)).revision===2);
  await denied(()=>review('approved',1),'40001');
  await denied(()=>review('convertedToProject',2),'22023');
  check((await review('approved',2)).status==='approved');
  const consultation = {id:'con-test',title:'School crossing consultation',description:'Tell us how to make this crossing safer.',department:'Roads',
    openingDate:'2020-01-01T00:00:00Z',closingDate:'2099-01-01T00:00:00Z',
    questions:[{id:'q1',question:'Preferred crossing?',options:['Raised','Signals'],allowsLongText:false},
      {id:'q2',question:'Explain your choice',options:[],allowsLongText:true}]};
  const createConsultation = c => jsonRpc('civic_create_consultation',c);
  const answer = answers => rpc('civic_answer_consultation',['con-test',JSON.stringify(answers)],['text','jsonb']);
  await denied(()=>createConsultation({...consultation,questions:[]}),'22023');
  await denied(()=>createConsultation({...consultation,department:'Other'}),'22023');
  check((await createConsultation(consultation)).id==='con-test');
  check((await createConsultation(consultation)).id==='con-test');
  await denied(()=>createConsultation({...consultation,title:'Changed consultation'}),'40001');
  await asUser(resident);
  await denied(()=>createConsultation({...consultation,id:'con-resident'}));
  await denied(()=>answer({q1:'Raised'}),'22023');
  await denied(()=>answer({q1:'Fake',q2:'Reason'}),'22023');
  await denied(()=>answer({q1:'Raised',q2:'',extra:'No'}),'22023');
  const response = await answer({q1:'Raised',q2:'Slower traffic near school.'});
  check(response.responseCount===1 && response.answers[resident].q2==='Slower traffic near school.');
  check((await answer({q1:'Raised',q2:'Slower traffic near school.'})).responseCount===1);
  await denied(()=>answer({q1:'Signals',q2:'Changed'}),'40001');
  await asUser(officer);
  const consultations = (await rpc('civic_participation')).consultations;
  check(consultations[0].responseCount===1 && Object.keys(consultations[0].answers).length===0);
  check((await rpc('civic_bootstrap')).notifications.length===0);
  await createConsultation({...consultation,id:'con-closed',openingDate:'2020-01-01T00:00:00Z',closingDate:'2021-01-01T00:00:00Z'});
  await createConsultation({...consultation,id:'con-future',openingDate:'2098-01-01T00:00:00Z'});
  await asUser(resident);
  for (const id of ['con-closed','con-future']) {
    await denied(()=>rpc('civic_answer_consultation',[id,JSON.stringify({q1:'Raised',q2:'Reason'})],['text','jsonb']),'22023');
  }
  check((await rpc('civic_bootstrap')).notifications.length===2);
  await denied(()=>db.query('select * from civic_private.consultation_answers'));
  await asUser(other);
  check((await rpc('civic_participation')).consultations.length===0);
  await denied(()=>answer({q1:'Raised',q2:'Reason'}));
  await db.exec('reset role');
  // Analytics includes records beyond the first project page and excludes other authorities.
  for (let i=0;i<31;i++) {
    await db.query(`insert into civic_private.projects(id,authority_id,created_by,data,initial_payload)
      values($1,$2,$3,$4,'{}')`,['p-'+i,i===30?'b':'a',officer,
      JSON.stringify({title:'Project '+i,status:i===29?'delayed':'inProgress',progress:i,updates:[]})]);
  }
  await db.query(`insert into civic_private.reports(id,authority_id,owner_id,case_number,data)
    values('r-metric','a',$1,'TEST-1',$2)`,[resident,JSON.stringify({status:'resolved',category:'Roads',locationLabel:'Ward 07 school',
      submittedAt:'2026-01-01T00:00:00Z',lastUpdated:'2026-01-10T00:00:00Z',
      updates:[{status:'resolved',date:'2026-01-03T00:00:00Z'}]})]);
  await asUser(officer);
  const analytics = await rpc('civic_analytics');
  check(analytics.activeProjects===29 && analytics.delayedProjects===1 && analytics.projectProgress.length===30);
  check(analytics.received===1 && analytics.resolved===1 && analytics.averageResolutionDays===2);
  check(analytics.byWard['Ward 07']===1 && analytics.byCategory.Roads===1);
  const imagePath = `${officer}/a/p-upload/test.png`;
  await db.query("insert into storage.objects(bucket_id,name) values('project-public',$1)",[imagePath]);
  checks++;
  await denied(()=>db.query("insert into storage.objects(bucket_id,name) values('project-public',$1)",[`${officer}/b/p-upload/test.png`]));
  await denied(()=>db.query("insert into storage.objects(bucket_id,name) values('project-public',$1)",[`${resident}/a/p-upload/test.png`]));
  await denied(()=>db.query("update storage.objects set name='tamper.png' where name=$1",[imagePath]));
  const assetDraft = {id:'p-upload',authorityId:'a',revision:0,title:'Public upload project',description:'A project with public photos and plans.',
    category:'Roads',locationLabel:'School road',location:{latitude:7,longitude:80},status:'planned',progress:0,
    startDate:'2026-01-01T00:00:00Z',expectedCompletion:'2027-01-01T00:00:00Z',department:'Roads',
    budget:10,spent:0,isBudgetPublic:false,contractor:'',projectManager:'',milestones:[],updates:[],documents:[],imageLabels:[imagePath]};
  const saveAsset = d => jsonRpc('civic_save_project',d);
  check((await saveAsset(assetDraft)).imageLabels[0]===imagePath);
  check((await saveAsset(assetDraft)).revision===1);
  await denied(()=>saveAsset({...assetDraft,id:'p-missing',imageLabels:[`${officer}/a/p-missing/missing.png`]}),'22023');
  await denied(()=>jsonRpc('civic_save_project_core',assetDraft));
  await asUser(resident);
  await denied(()=>db.query("insert into storage.objects(bucket_id,name) values('project-public',$1)",[`${resident}/a/p-upload/test.pdf`]));
  check((await rpc('civic_get_project',['p-upload'],['text'])).imageLabels[0]===imagePath);
  const projectComment = (id,message) => rpc('civic_project_comment',['p-0',id,message],['text','text','text']);
  const feedback = await projectComment('pjc-test','Please keep the footpath accessible.');
  check(feedback.comments.length===1 && feedback.comments[0].author==='Server Author');
  check((await projectComment('pjc-test','Please keep the footpath accessible.')).comments.length===1);
  await denied(()=>projectComment('pjc-test','Changed'),'40001');
  await denied(()=>projectComment('pjc-empty',''),'22023');
  check((await rpc('civic_get_project',['p-0'],['text'])).comments.length===1);
  await asUser(other);
  await denied(()=>projectComment('pjc-other','No access'));
  await asUser(officer);
  await denied(()=>rpc('civic_audit_events'));
  await db.exec('reset role');
  await db.query("update civic_private.profiles set role='localAuthorityAdmin' where id=$1",[officer]);
  await asUser(officer);
  const audit = await rpc('civic_audit_events');
  check(audit.length>30 && audit.every(e=>e.recordId!=='p-30'));
  check(!JSON.stringify(audit).includes('Slower traffic near school.'));
  check((await rpc('civic_audit_events',[audit.at(-1).id],['bigint'])).every(e=>e.id<audit.at(-1).id));
  await db.exec('reset role');
  await denied(()=>db.exec("delete from civic_private.departments where id='roads'"),'23503');
  // A rolled-back data change also rolls back its audit entry.
  await db.exec("begin; update civic_private.profiles set active=false where id='"+resident+"'; rollback;");
  await asUser(officer);
  check((await rpc('civic_audit_events')).length===audit.length);
  await db.exec('reset role');
  await db.query('update civic_private.profiles set active=false where id=$1',[resident]);
  await asUser(resident);
  await denied(()=>rpc('civic_participation'));
  await denied(()=>preference(false,false));
  console.log(`Participation backend: ${checks} checks passed.`);
} finally { await db.close(); }
