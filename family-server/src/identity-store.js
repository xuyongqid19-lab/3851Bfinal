import { randomUUID } from 'node:crypto';
import { FamilyError } from './errors.js';
const fail=(status,message)=>{throw new FamilyError(status,message);};
export const paletteIds = Array.from({length:30},(_,i)=>`c${i+1}`);
const normalize=s=>s.normalize('NFKC').trim().replace(/\s+/gu,' ').toLowerCase();
export function validateTags(value) {
  if(!Array.isArray(value)||value.length>5) fail(400,'Choose up to five tags.');
  const seen=new Set();
  return value.map(t=>{
    if(!t||typeof t.label!=='string'||typeof t.color!=='string'||(t.value!==undefined&&typeof t.value!=='string'))fail(400,'Invalid tag.');
    const label=t.label.trim(),v=(t.value??'').trim();
    if(!label||[...label].length>30||[...v].length>60||!paletteIds.includes(t.color))fail(400,'Invalid tag label, value or colour.');
    const key=normalize(label);if(seen.has(key))fail(400,'Tag labels must be unique.');seen.add(key);
    return {label,value:v,color:t.color};
  });
}
/** Family-owned identity directory. No Auth or Chat database access. */
export class FamilyIdentityStore {
  constructor(s) {
    this.s=s;
    s.tx(()=>{
      s.db.exec(`CREATE TABLE IF NOT EXISTS family_schema_versions(version INTEGER PRIMARY KEY,appliedAt TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS family_tags(groupId TEXT PRIMARY KEY REFERENCES families(id) ON DELETE CASCADE,tags TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS member_profiles(groupId TEXT NOT NULL,userId TEXT NOT NULL,publicId TEXT UNIQUE NOT NULL,tags TEXT NOT NULL DEFAULT '[]',introduction TEXT NOT NULL DEFAULT '',PRIMARY KEY(groupId,userId),FOREIGN KEY(groupId,userId) REFERENCES members(groupId,userId) ON DELETE CASCADE);
        CREATE TABLE IF NOT EXISTS family_notifications(id TEXT PRIMARY KEY,kind TEXT NOT NULL,message TEXT NOT NULL,createdAt TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS family_notification_deliveries(eventId TEXT REFERENCES family_notifications(id) ON DELETE CASCADE,userId TEXT NOT NULL,groupsJson TEXT NOT NULL,isRead INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(eventId,userId));
        CREATE INDEX IF NOT EXISTS family_notification_user ON family_notification_deliveries(userId,isRead);
        CREATE TABLE IF NOT EXISTS family_demo_groups(groupId TEXT PRIMARY KEY REFERENCES families(id) ON DELETE CASCADE,sourceId TEXT UNIQUE NOT NULL REFERENCES families(id) ON DELETE CASCADE);
        CREATE TABLE IF NOT EXISTS family_demo_people(id TEXT PRIMARY KEY,groupId TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,name TEXT NOT NULL,tags TEXT NOT NULL);`);
      s.run('INSERT OR IGNORE INTO family_schema_versions VALUES(1,?)',s.clock());
      this.backfill();
    });
  }
  backfill() {
    for(const m of this.s.all('SELECT groupId,userId FROM members WHERE NOT EXISTS(SELECT 1 FROM member_profiles p WHERE p.groupId=members.groupId AND p.userId=members.userId)'))
      this.s.run('INSERT INTO member_profiles(groupId,userId,publicId) VALUES(?,?,?)',m.groupId,m.userId,randomUUID());
  }
  familyTags(groupId){return JSON.parse(this.s.get('SELECT tags FROM family_tags WHERE groupId=?',groupId)?.tags??'[]');}
  profile(groupId,userId){
    const r=this.s.get('SELECT tags,introduction FROM member_profiles WHERE groupId=? AND userId=?',groupId,userId);
    const tags=JSON.parse(r?.tags??'[]'),name=this.s.get('SELECT realName FROM members WHERE groupId=? AND userId=?',groupId,userId)?.realName;
    return {personalTags:tags.map(t=>normalize(t.label)==='name'?{...t,value:name??t.value}:t),introduction:r?.introduction??''};
  }
  saveFamily(groupId,tags){if(tags===undefined)return;const clean=validateTags(tags);this.s.run('INSERT INTO family_tags VALUES(?,?) ON CONFLICT(groupId) DO UPDATE SET tags=excluded.tags',groupId,JSON.stringify(clean));}
  saveMember(groupId,userId,body){
    const old=this.profile(groupId,userId),tags=body.personalTags===undefined?old.personalTags:validateTags(body.personalTags);
    const intro=body.introduction===undefined?old.introduction:body.introduction;
    if(typeof intro!=='string'||[...intro].length>500)fail(400,'Personal introduction must be at most 500 characters.');
    this.s.run('INSERT INTO member_profiles(groupId,userId,publicId,tags,introduction) VALUES(?,?,?,?,?) ON CONFLICT(groupId,userId) DO UPDATE SET tags=excluded.tags,introduction=excluded.introduction',groupId,userId,randomUUID(),JSON.stringify(tags),intro.trim());
  }
  people(groupId){
    this.backfill();
    const real=this.s.all('SELECT m.userId,m.realName,p.publicId FROM members m JOIN member_profiles p ON p.groupId=m.groupId AND p.userId=m.userId WHERE m.groupId=? ORDER BY m.realName,p.publicId',groupId)
      .map(m=>({id:m.publicId,name:m.realName,tags:this.profile(groupId,m.userId).personalTags,demo:false}));
    const demo=this.s.all('SELECT id,name,tags FROM family_demo_people WHERE groupId=? ORDER BY name,id',groupId).map(m=>({...m,tags:JSON.parse(m.tags),demo:true}));
    return [...real,...demo];
  }
  directoryNode(id,userId){return {id,name:this.s.get('SELECT name FROM families WHERE id=?',id).name,canOpen:!!this.s.tree.role(id,userId),familyTags:this.familyTags(id),people:this.people(id),demo:!!this.s.get('SELECT 1 FROM family_demo_groups WHERE groupId=?',id)};}
  search(groupId,userId,params){
    this.s.member(groupId,userId);
    const q=params.get('q')??'',offset=Number(params.get('offset')??0);
    if(q.length>100||!Number.isSafeInteger(offset)||offset<0||offset>100000)fail(400,'Invalid search query or page.');
    const needle=normalize(q);if(!needle)return {items:[],nextOffset:null};
    const items=[];
    for(const id of this.s.tree.component(groupId).groups){
      const familyName=this.s.get('SELECT name FROM families WHERE id=?',id).name,familyTags=this.familyTags(id);
      for(const p of this.people(id))if(normalize(p.name).includes(needle))items.push({...p,groupId:id,familyName,familyTags,personalTags:p.tags});
    }
    items.sort((a,b)=>a.name.localeCompare(b.name)||a.familyName.localeCompare(b.familyName)||a.id.localeCompare(b.id));
    return {items:items.slice(offset,offset+20),nextOffset:offset+20<items.length?offset+20:null};
  }
  resolve(groupId,userId,targetGroup,personId){
    this.s.member(groupId,userId);
    if(!this.s.tree.component(groupId).groups.includes(targetGroup))fail(404,'This person is no longer in the connected tree.');
    const p=this.people(targetGroup).find(p=>p.id===personId);if(!p)fail(404,'This person is no longer in the connected tree.');
    return {...p,groupId:targetGroup,familyName:this.s.get('SELECT name FROM families WHERE id=?',targetGroup).name,familyTags:this.familyTags(targetGroup),personalTags:p.tags};
  }
  notify(id,kind,groups,message){
    // The committed event and recipient ledger ARE the durable in-app outbox. No external delivery is required.
    this.s.run('INSERT OR IGNORE INTO family_notifications VALUES(?,?,?,?)',id,kind,message,this.s.clock());
    const recipients=new Map();
    for(const g of groups)for(const m of this.s.all('SELECT userId FROM members WHERE groupId=?',g)){
      const list=recipients.get(m.userId)??[];list.push(g);recipients.set(m.userId,list);
    }
    for(const [userId,gs] of recipients)this.s.run('INSERT OR IGNORE INTO family_notification_deliveries VALUES(?,?,?,0)',id,userId,JSON.stringify(gs));
  }
  notifications(userId){
    const rows=this.s.all('SELECT n.*,d.isRead,d.groupsJson FROM family_notifications n JOIN family_notification_deliveries d ON d.eventId=n.id WHERE d.userId=? ORDER BY n.createdAt DESC,n.id DESC',userId);
    const items=rows.map(r=>{const groupId=JSON.parse(r.groupsJson).find(g=>this.s.tree.role(g,userId));return groupId?{id:r.id,kind:r.kind,message:r.message,createdAt:r.createdAt,isRead:!!r.isRead,groupId}:null;}).filter(Boolean);
    return {items:items.slice(0,100),unread:items.filter(r=>!r.isRead).length};
  }
  readNotification(userId,id,body){
    if(typeof body.isRead!=='boolean')fail(400,'Choose a read state.');
    const row=this.s.get('SELECT groupsJson FROM family_notification_deliveries WHERE eventId=? AND userId=?',id,userId);
    if(!row||!JSON.parse(row.groupsJson).some(g=>this.s.tree.role(g,userId)))fail(404,'Notification not found.');
    this.s.run('UPDATE family_notification_deliveries SET isRead=? WHERE eventId=? AND userId=?',body.isRead?1:0,id,userId);return {ok:true};
  }
}
