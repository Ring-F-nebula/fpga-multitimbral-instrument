import test from 'node:test';
import assert from 'node:assert/strict';
import {AirNotes} from '../public/air-bridge-core.js';
import {GuitarOutput} from '../public/air-guitar-output.js';
import {PianoLink,configPacket} from '../public/piano-link.js';
import {PerformanceAudio} from '../public/performance-audio.js';
const state=()=>({attack:10,decay:200,sustain:55,release:400,volume:60});
function setup(){
 const packets=[],errors=[],link=new PianoLink();
 Object.assign(link,{ready:true,connected:true,session:'piano-test',slotNotes:Array.from({length:32},(_,i)=>60+i),mappingRequired:true,
  performanceStatus:{guitar:true,instrument:1,stopped:true},fxStatus:{values:Array(16).fill(0)}});
 link.writer={write:async b=>packets.push([...b])};
 const audio=new PerformanceAudio(link,e=>errors.push(e));
 const notes=new AirNotes({link,audio,state,notify:e=>errors.push(e)});notes.enabled=true;notes.precise=false;
 return {notes,link,audio,packets,errors};
}
function frames(packets){const out=[];for(const b of packets)for(let i=0;i<b.length;){const n=b[i]===0xf7?6:4;const f=b.slice(i,i+n);assert.equal(f.reduce((a,v)=>a^v,0),0);out.push(f);i+=n;}return out;}
const mask=f=>(f[1]|f[2]<<8|((f[0]===0xf7?f[3]:0)<<16)|((f[0]===0xf7?f[4]:0)<<24))>>>0;
test('piano entry clears latched STOP, replay, practice, test and hold before first key, preserving mapping and FX',async()=>{
 const {notes,link,packets}=setup(),mapping=[...link.slotNotes];
 await notes.init();notes.on(0);notes.on(15);await link.tail;
 const fs=frames(packets),cfg=fs.filter(f=>f[0]===0xf5);
 for(const id of [0x1f,0x50,0x2e,0x27,0x2a,0x23])assert.ok(cfg.some(f=>f[1]===id&&f[2]===0));
 assert.ok(cfg.some(f=>f[1]===5&&f[2]===9));
 const live=fs.findIndex(f=>f[0]===0xf7&&mask(f)!==0);
 assert.ok(fs.findIndex(f=>f[1]===0x1f&&f[0]===0xf5)<live);
 assert.equal(mask(fs.at(-1)),0x8001);assert.deepEqual(link.slotNotes,mapping);
 assert.ok(!cfg.some(f=>(f[1]>=0x30&&f[1]<=0x32)||(f[1]>=0x10&&f[1]<=0x1e)));
 notes.stop();await link.tail;assert.equal(mask(frames(packets).at(-1)),0);
});
test('repeated touch init does not clear a held chord or keep switching instruments',async()=>{
 const {notes,link,packets}=setup();await notes.init();notes.on(0);await link.tail;
 // A previous STOP status can still be in flight while notes are already held.
 const count=packets.length;await notes.init();notes.on(4);await link.tail;
 const added=frames(packets.slice(count));assert.deepEqual(added.filter(f=>f[0]===0xf7).map(mask),[17]);
 assert.ok(!added.some(f=>f[0]===0xf5&&f[1]===0x23));
});
test('rejected mapped pitch is not remembered as held and can be retried after mapping recovers',()=>{
 const {notes,link,errors}=setup();link.slotNotes=Array(32).fill(40);
 assert.equal(notes.on(0),false);assert.equal(notes.notes.size,0);assert.equal(link.voices.size,0);assert.ok(errors.length);
 link.slotNotes[31]=60;assert.equal(notes.on(0),true);assert.equal(link.voices.get('air-0').slot,31);
});
test('guitar to piano releases wide ownership and leaves the normal F7 note path usable',async()=>{
 const {notes,link,packets}=setup();const guitar=new GuitarOutput({link,state});guitar.enabled=true;
 await guitar.begin();guitar.push({notes:[48,55,60,64],volume:1});await link.tail;
 assert.notEqual(link.wideMask,null);await guitar.end();await notes.init();
 assert.equal(link.wideMask,null);assert.equal(notes.on(3),true);await link.tail;
 assert.equal(mask(frames(packets).at(-1)),8);assert.ok(frames(packets).some(f=>f.join()===[...configPacket(0x23,0)].join()));
});
test('reconnect prepares the new session again, and closing during preparation cannot mark it initialized',async()=>{
 const {notes,link,packets}=setup();await notes.init();link.performanceStatus.stopped=false;
 link.session='next';const before=packets.length;await notes.init();await link.tail;assert.ok(packets.length>before);
 notes.end();let finish;link.writer.write=()=>new Promise(r=>finish=r);
 const init=notes.init();await new Promise(r=>setImmediate(r));notes.end();notes.enabled=false;
 // Drain the all-off and initialization writes, one serialized task at a time.
 for(let i=0;i<4;i++){finish?.();await new Promise(r=>setImmediate(r));}
 assert.equal(await init,false);assert.equal(notes.initializedSession,null);
});
test('native disconnected entry never creates phone preview audio',async()=>{
 const {notes,link,audio,packets}=setup();link.ready=link.connected=false;
 Object.defineProperty(link,'native',{value:true});audio.init=()=>{throw Error('phone audio forbidden');};
 assert.equal(await notes.init(),false);assert.equal(notes.on(0),false);assert.equal(packets.length,0);
});
