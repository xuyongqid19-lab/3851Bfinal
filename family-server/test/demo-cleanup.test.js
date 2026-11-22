import test from 'node:test';
import assert from 'node:assert/strict';
import {FamilyStore} from '../src/store.js';
test('closing a source family cleans only its marked demo fixtures',()=>{
 const s=new FamilyStore(':memory:',undefined,{demoMode:true});
 try {const a=s.create('owner',{name:'Source',realName:'Owner',kinship:'Dad'});s.demo.add(a.id,'owner');s.leave(a.id,'owner');assert.equal(s.get('SELECT count(*) n FROM family_demo_people').n,0);assert.equal(s.get('SELECT count(*) n FROM families').n,0);}finally{s.close();}
});
