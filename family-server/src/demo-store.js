import { randomUUID,randomBytes } from 'node:crypto';
import { FamilyError } from './errors.js';
/** Explicit synthetic fixtures, enabled only by an isolated demo server. */
export class FamilyDemoStore {
  constructor(s,enabled){this.s=s;this.enabled=enabled;}
  check(groupId,userId){if(!this.enabled)throw new FamilyError(404,'Demo mode is not enabled.');this.s.member(groupId,userId,['owner','admin']);}
  add(groupId,userId){
    this.check(groupId,userId);
    return this.s.tx(()=>{
      const existing=this.s.get('SELECT groupId FROM family_demo_groups WHERE sourceId=?',groupId);
      let id=existing?.groupId;
      if(!id){
        id=randomUUID();this.s.run('INSERT INTO families VALUES(?,?,?,?,?)',id,'John Prince Family','Fictional demonstration family. No real accounts.',randomBytes(24).toString('hex'),this.s.clock());
        this.s.run('INSERT INTO family_demo_groups VALUES(?,?)',id,groupId);
        this.s.identityData.saveFamily(id,[{label:'Prince Family',color:'c7'},{label:'Demo data',color:'c30'}]);
        for(const name of ['John Prince','Emily Prince','Daniel Prince','Olivia Prince','William Prince'])this.s.run('INSERT INTO family_demo_people VALUES(?,?,?,?)',randomUUID(),id,name,JSON.stringify([{label:'Name',value:name,color:'c15'},{label:'Demo data',value:'Fictional',color:'c30'}]));
      }
      if(!this.s.tree.component(groupId).groups.includes(id)){
        const p=this.s.tree.proposal(groupId,id),[a,b]=[groupId,id].sort(),edge=randomUUID();
        this.s.run('INSERT INTO tree_connections VALUES(?,?,?,?,?)',edge,a,b,'Demo connection',this.s.clock());
        this.s.identityData.notify(`demo:${edge}`,'connected',p.groups,'John Prince Family (Demo data) was linked. Fictional names and tags are visible in this tree.');
      }
      return {groupId:id};
    });
  }
  cleanupSource(groupId){
    const demo=this.s.get('SELECT groupId FROM family_demo_groups WHERE sourceId=?',groupId);
    if(demo){this.s.tree.closing(demo.groupId);this.s.run('DELETE FROM families WHERE id=?',demo.groupId);}
  }
  remove(groupId,userId,body){
    this.check(groupId,userId);
    if(body.confirmed!==true)throw new FamilyError(400,'Confirm removing demo data.');
    return this.s.tx(()=>{
      const demo=this.s.get('SELECT groupId FROM family_demo_groups WHERE sourceId=?',groupId);if(!demo)return {ok:true};
      this.s.tree.closing(demo.groupId);this.s.run('DELETE FROM families WHERE id=?',demo.groupId);this.s.tree.refreshPending();return {ok:true};
    });
  }
}
