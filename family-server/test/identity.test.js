import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,copyFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {DatabaseSync} from 'node:sqlite';
import {FamilyStore,FamilyError} from '../src/store.js';
import {familyServer} from '../src/app.js';
import {validateTags,paletteIds} from '../src/identity-store.js';
const status=n=>e=>e instanceof FamilyError&&e.status===n;
const create=(s,u,name=u,extra={})=>s.create(u,{name:`${u} Home`,realName:name,kinship:'Relative',...extra});
function setup(t,demoMode=false){const s=new FamilyStore(':memory:',undefined,{demoMode});t.after(()=>s.close());return s;}
function propose(s,a,b){const code=s.tree.view(b.id,b.me.userId).code,p=s.tree.preview(a.id,a.me.userId,{code});return s.tree.send(a.id,a.me.userId,{code,snapshot:p.snapshot,label:'Family',confirmed:true});}
function connect(s,a,b){const r=propose(s,a,b);s.tree.decide(b.id,b.me.userId,r.id,{decision:'approve'});return r;}
const query=(s,a,u,q,offset=0)=>s.identityData.search(a.id,u,new URLSearchParams({q,offset:String(offset)}));
const tag=(label='Family',color='c1',value='')=>({label,color,value});

test('30 palette IDs; strict optional values, duplicate and length validation',()=>{
 assert.equal(new Set(paletteIds).size,30);for(const color of paletteIds)assert.equal(validateTags([tag('Test',color)])[0].color,color);
 for(const tags of [[tag('','c1')],[tag('x','c31')],[tag('A'),tag(' a ')],Array.from({length:6},(_,i)=>tag(String(i))),[tag('x'.repeat(31))],[tag('Name','c1','x'.repeat(61))]])assert.throws(()=>validateTags(tags),status(400));
});
test('create and join are atomic with tags; membership identity is per family',t=>{
 const s=setup(t);assert.throws(()=>create(s,'bad','Bad',{personalTags:[tag('x','bad')]}),status(400));assert.equal(s.get('SELECT count(*) n FROM families').n,0);
 const a=create(s,'a','Alice',{familyTags:[tag('A')],personalTags:[tag('Name','c2','Wrong')],introduction:'Private introduction'});
 assert.equal(a.me.personalTags[0].value,'Alice');assert.equal(a.familyTags[0].label,'A');
 assert.throws(()=>s.join('b',{invite:a.invite,realName:'Bob',kinship:'Cousin',familyTags:[]}),status(403));
 assert.throws(()=>s.join('b',{invite:a.invite,realName:'Bob',kinship:'Cousin',personalTags:[tag('X','no')]}),status(400));assert.equal(s.get('SELECT count(*) n FROM members').n,1);
 s.join('b',{invite:a.invite,realName:'Bob',kinship:'Cousin',personalTags:[tag('Gender','c5','Self described')]});
 assert.throws(()=>s.update(a.id,'b',{name:'Changed',familyTags:[]}),status(403));
 s.identity(a.id,'b',{realName:'Bob',kinship:'Cousin',userId:'a',personalTags:[]});assert.equal(s.detail(a.id,'a').me.personalTags[0].value,'Alice');
 const c=create(s,'b','Robert',{personalTags:[tag('Role','c3','Uncle')]});assert.equal(s.detail(c.id,'b').me.personalTags.length,1);assert.equal(s.detail(a.id,'b').me.personalTags.length,0);
});
test('linked directory reveals names/tags only and revalidates after disconnection',t=>{
 const s=setup(t),a=create(s,'a','Alice'),b=create(s,'b','John Prince',{personalTags:[tag('Gender','c2','Male')],introduction:'Do not share my intro',familyTags:[tag('Prince')]});
 s.addRecord(b.id,'b','notes',{title:'Private note',note:'Private health'});
 assert.equal(query(s,a,'a','john').items.length,0);assert.throws(()=>query(s,a,'outsider','john'),status(404));
 connect(s,a,b);const p=query(s,a,'a',' JoHN ').items[0];assert.equal(p.name,'John Prince');assert.equal(p.familyTags[0].label,'Prince');assert.equal(p.personalTags[0].value,'Male');
 const str=JSON.stringify(s.tree.view(a.id,'a'));assert(!str.includes('Private health'));assert(!str.includes('Do not share my intro'));assert(!str.includes('"userId"'));assert(!str.includes(b.invite));
 assert.equal(s.identityData.resolve(a.id,'a',b.id,p.id).name,'John Prince');const v=s.tree.view(a.id,'a');s.tree.disconnect(a.id,'a',v.connections[0].id,{version:v.version});
 assert.equal(query(s,a,'a','John').items.length,0);assert.throws(()=>s.identityData.resolve(a.id,'a',b.id,p.id),status(404));assert.equal(s.detail(b.id,'b').records.length,1);
});
test('unicode normalization, repeated spaces, duplicate names and paging retain stable identities',t=>{
 const s=setup(t),a=create(s,'a','John  Prince'),b=create(s,'b','John Prince');connect(s,a,b);
 assert.equal(query(s,a,'a','john prince').items.length,2);
 s.join('a',{invite:b.invite,realName:'John Prince',kinship:'Brother'});assert.equal(new Set(query(s,a,'a','john').items.map(p=>p.id)).size,3);
 for(let i=0;i<24;i++)s.join(`p${i}`,{invite:a.invite,realName:`王 Test ${i}`,kinship:'Relative'});
 const first=query(s,a,'a','王');assert.equal(first.items.length,20);assert.equal(first.nextOffset,20);assert.equal(query(s,a,'a','王',20).items.length,4);
 assert.equal(query(s,a,'a','').items.length,0);assert.throws(()=>query(s,a,'a','a',-1),status(400));
});
test('notifications reach every affected member after final consent once; persisted read authorization',t=>{
 const s=setup(t),a=create(s,'a'),b=create(s,'b'),c=create(s,'c');s.join('m',{invite:a.invite,realName:'Member',kinship:'Relative'});
 const r=propose(s,a,b);assert.equal(s.identityData.notifications('m').unread,0);s.tree.decide(b.id,'b',r.id,{decision:'approve'});s.tree.decide(b.id,'b',r.id,{decision:'approve'});
 for(const u of ['a','b','m'])assert.equal(s.identityData.notifications(u).unread,1);
 const r2=propose(s,a,c);s.tree.decide(c.id,'c',r2.id,{decision:'approve'});assert.equal(s.identityData.notifications('c').unread,0);s.tree.decide(b.id,'b',r2.id,{decision:'approve'});assert.equal(s.identityData.notifications('c').unread,1);assert.equal(s.identityData.notifications('m').unread,2);
 const n=s.identityData.notifications('m').items[0];assert.throws(()=>s.identityData.readNotification('c',r.id,{isRead:true}),status(404));
 s.identityData.readNotification('m',n.id,{isRead:true});assert.equal(s.identityData.notifications('m').unread,1);s.identityData.readNotification('m',n.id,{isRead:false});assert.equal(s.identityData.notifications('m').unread,2);
 s.leave(a.id,'m');assert.equal(s.identityData.notifications('m').items.length,0);assert.throws(()=>s.identityData.readNotification('m',n.id,{isRead:true}),status(404));
 const v=s.tree.view(a.id,'a');s.tree.disconnect(a.id,'a',v.connections[0].id,{version:v.version});for(const u of ['a','b','c'])assert(s.identityData.notifications(u).items.some(n=>n.kind==='disconnected'));
});
test('rollback does not leave a success notification or incomplete link',t=>{
 const s=setup(t),a=create(s,'a'),b=create(s,'b'),r=propose(s,a,b);
 s.db.exec("CREATE TRIGGER fail_event BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'test'); END;");
 assert.throws(()=>s.tree.decide(b.id,'b',r.id,{decision:'approve'}));assert.equal(s.tree.component(a.id).groups.length,1);assert.equal(s.identityData.notifications('a').unread,0);
});
test('demo fixtures are explicit, isolated, five people, idempotent and unlinkable',t=>{
 const disabled=setup(t),a0=create(disabled,'a');assert.throws(()=>disabled.demo.add(a0.id,'a'),status(404));
 const s=setup(t,true),a=create(s,'a');s.join('m',{invite:a.invite,realName:'Member',kinship:'Relative'});assert.throws(()=>s.demo.add(a.id,'m'),status(403));
 const d=s.demo.add(a.id,'a');s.demo.add(a.id,'a');assert.equal(query(s,a,'a','prince').items.length,5);assert.equal(s.get('SELECT count(*) n FROM members WHERE groupId=?',d.groupId).n,0);assert.equal(s.identityData.notifications('a').items.length,1);
 const v=s.tree.view(a.id,'a');s.tree.disconnect(a.id,'a',v.connections[0].id,{version:v.version});assert.equal(query(s,a,'a','prince').items.length,0);assert.equal(s.get('SELECT count(*) n FROM family_demo_people').n,5);
 s.demo.add(a.id,'a');assert.equal(query(s,a,'a','prince').items.length,5);assert.throws(()=>s.demo.remove(a.id,'a',{}),status(400));s.demo.remove(a.id,'a',{confirmed:true});assert.equal(s.get('SELECT count(*) n FROM family_demo_people').n,0);assert.equal(s.detail(a.id,'a').members.length,2);
});
test('additive legacy migration, restart and backup restore keep original records and read state',t=>{
 const dir=mkdtempSync(join(tmpdir(),'family-migration-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));const file=join(dir,'family.sqlite');
 const db=new DatabaseSync(file);db.exec("CREATE TABLE families(id TEXT PRIMARY KEY,name TEXT NOT NULL,description TEXT NOT NULL,invite TEXT UNIQUE NOT NULL,createdAt TEXT NOT NULL); INSERT INTO families VALUES('old','Legacy','Original description','INVITE','2026-01-01'); CREATE TABLE members(groupId TEXT REFERENCES families(id) ON DELETE CASCADE,userId TEXT NOT NULL,realName TEXT NOT NULL,kinship TEXT NOT NULL,role TEXT NOT NULL,joinedAt TEXT NOT NULL,lastRead INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(groupId,userId)); INSERT INTO members VALUES('old','owner','Original Name','Dad','owner','2026-01-01',0);");db.close();copyFileSync(file,join(dir,'before.sqlite'));
 let s=new FamilyStore(file);assert.equal(s.detail('old','owner').description,'Original description');assert.deepEqual(s.detail('old','owner').familyTags,[]);const id=s.identityData.people('old')[0].id;
 s.identity('old','owner',{realName:'Original Name',kinship:'Dad',personalTags:[tag('Name','c1','Ignored')]});s.identityData.notify('test-event','connected',['old'],'Test');s.identityData.readNotification('owner','test-event',{isRead:true});s.close();
 s=new FamilyStore(file);assert.equal(s.identityData.people('old')[0].id,id);assert.equal(s.identityData.notifications('owner').unread,0);assert.equal(s.detail('old','owner').me.personalTags[0].value,'Original Name');s.close();
 const oldReader=new DatabaseSync(file);assert.equal(oldReader.prepare('SELECT realName FROM members').get().realName,'Original Name');oldReader.close();
 const restored=new FamilyStore(join(dir,'before.sqlite'));assert.equal(restored.detail('old','owner').name,'Legacy');assert.equal(restored.identityData.notifications('owner').items.length,0);restored.close();
});
test('HTTP search, resolve, demo and notification routes enforce auth and actor identity',async t=>{
 const s=setup(t,true),a=create(s,'a');s.join('member',{invite:a.invite,realName:'M',kinship:'Cousin'});s.demo.add(a.id,'a');
 const server=familyServer(s,async h=>{if(!h)throw new FamilyError(401,'Login required');return {id:h};});await new Promise(r=>server.listen(0,'127.0.0.1',r));t.after(()=>new Promise(r=>server.close(r)));const base=`http://127.0.0.1:${server.address().port}`;
 const get=async(path,user='a')=>fetch(base+path,{headers:user?{Authorization:user}:{}});
 assert.equal((await get(`/families/${a.id}/tree/people?q=Prince`,null)).status,401);assert.equal((await get(`/families/${a.id}/tree/people?q=Prince`,'outsider')).status,404);
 const list=await(await get(`/families/${a.id}/tree/people?q=Prince`)).json();assert.equal(list.items.length,5);const p=list.items[0];assert.equal((await get(`/families/${a.id}/tree/people/${p.groupId}/${p.id}`)).status,200);
 const resp=await fetch(base+`/families/${a.id}/tree/remove-demo`,{method:'POST',headers:{Authorization:'member','Content-Type':'application/json'},body:JSON.stringify({confirmed:true,userId:'a'})});assert.equal(resp.status,403);
 const ns=await(await get('/family-notifications','member')).json();assert.equal(ns.unread,1);
});
