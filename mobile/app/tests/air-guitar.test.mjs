import test from 'node:test';import assert from 'node:assert/strict';
import {GuitarOutput,guitarMask} from '../public/air-guitar-output.js';import {PianoLink,StatusParser,configPacket,keysPacket,keys32Packet} from '../public/piano-link.js';
const state=()=>({volume:60,attack:10,decay:200,sustain:55,release:400});
const effects=[0,18,90,64,8,30,51,45,4,64,3,50,18,32,100,0];
function setup(){const packets=[],link=new PianoLink();Object.assign(link,{connected:true,ready:true,session:'test',performanceStatus:{guitar:true,instrument:0},fxStatus:{values:[...effects]}});link.write=async b=>{packets.push([...b]);};const output=new GuitarOutput({link,state});output.enabled=true;return {link,output,packets};}
const tick=()=>new Promise(r=>setImmediate(r));
function commands(packets){const out=[];for(const a of packets)for(let i=0;i<a.length;){const size=a[i]===0xf7?6:4;out.push(a.slice(i,i+size));i+=size;}return out;}
const masks=packets=>commands(packets).filter(a=>a[0]===0xf7).map(a=>(a[1]|a[2]<<8|a[3]<<16|a[4]<<24)>>>0);
test('F7 transmits all 32 fixed pitches including sign bit with real checksum',()=>{assert.deepEqual([...keys32Packet(0x80018001)],[0xf7,1,128,1,128,0xf7]);assert.equal(guitarMask([40,55,56,71]),0x80018001);assert.throws(()=>guitarMask([39]),/E2/);assert.throws(()=>guitarMask([48,48]),/独立音/);});
test('fragmented V6 confirms guitar support and reads instrument correctly without becoming legacy status',()=>{
 const f=new Uint8Array(48);f.set([0xa5,0x5a,6,0x66]);f[4]=1;f[7]=128;f[31]=128;f[32]=32;f[47]=f.slice(2,47).reduce((a,b)=>a^b,0);
 const parser=new StatusParser();assert.deepEqual(parser.feed(f.slice(0,23)),[]);const [s]=parser.feed(f.slice(23));assert.equal(s.type,'performance');assert.equal(s.instrument,1);assert.equal(s.guitar,true);assert.equal(s.keys,0x80000001);
 f[20]^=1;assert.deepEqual(new StatusParser().feed(f),[]);
 const {link}=setup();link.receive(f);assert.equal(link.status,null);
});
test('enter uses FPGA guitar then all four notes, and hardware heartbeat retains the upper voices',async()=>{
 const {link,output,packets}=setup();assert.equal(await output.begin(),true);output.push({notes:[48,55,60,64],volume:.8,space:.7},1000);await tick();
 assert.ok(commands(packets).some(a=>a.join()===[...configPacket(0x23,1)].join()));assert.equal(masks(packets).at(-1),guitarMask([48,55,60,64]));
 await link.sendKeys();assert.equal(masks(packets).at(-1),guitarMask([48,55,60,64]));assert.ok(link.wideMask>65535);assert.equal(link.noteOn('stray',60),false);
 output.stop();await tick();assert.equal(masks(packets).at(-1),0);
});
test('stable held chord is not retriggered; changed chord is released then replucked atomically',async()=>{
 const {output,packets}=setup();await output.begin();output.push({notes:[48,55,60,64],volume:.5},1000);await tick();const n=masks(packets).length;
 for(let i=0;i<20;i++)output.push({notes:[48,55,60,64],volume:.5},1010+i);await tick();assert.equal(masks(packets).length,n);
 output.push({notes:[50,57,62,66],volume:.5},1200);await tick();assert.deepEqual(masks(packets).slice(-2),[0,guitarMask([50,57,62,66])]);
 output.push({notes:[]},1250);await tick();assert.equal(masks(packets).at(-1),0);
});
test('expressions are bounded and coalesced to 10Hz without rewriting all ADSR parameters',async()=>{
 const {output,packets}=setup();await output.begin();packets.length=0;output.push({notes:[48,55,60,64],volume:1,space:1},1000);await tick();
 for(let i=1;i<90;i++)output.push({notes:[48,55,60,64],volume:i/100,space:.2},1000+i);await tick();
 const cfg=commands(packets).filter(a=>a[0]===0xf5);assert.ok(cfg.length<=2);assert.ok(cfg.every(a=>[5,0x19].includes(a[1])));assert.ok(cfg.some(a=>a[1]===5&&a[2]===9));
 output.setLevel(0);output.push({notes:[48,55,60,64],volume:1},1200);await tick();assert.ok(commands(packets).some(a=>a[1]===5&&a[2]===0));
});
test('unconnected and unsupported firmware never use phone synthesis or send guitar commands',async()=>{
 for(const kind of ['offline','legacy']){const {output,link,packets}=setup();if(kind==='offline')link.ready=false;else link.performanceStatus=null;
  assert.equal(await output.begin(),false);output.push({notes:[48,55,60,64],volume:.8});await tick();assert.equal(packets.length,0);assert.equal(output.status().kind,'waiting');
 }
});
test('exit restores original instrument, complete FX values and ADSR then releases 32-bit ownership',async()=>{
 const {output,link,packets}=setup();await output.begin();output.push({notes:[48,55,60,64],volume:1},1000);await tick();packets.length=0;await output.end();
 assert.equal(link.wideMask,null);assert.equal(masks(packets).at(-1),0);const cfg=commands(packets).filter(a=>a[0]===0xf5);
 assert.ok(cfg.some(a=>a[1]===0x23&&a[2]===0));for(let i=0;i<15;i++)assert.ok(cfg.some(a=>a[1]===0x10+i&&a[2]===effects[i]));assert.ok(cfg.some(a=>a[1]===4&&a[2]===8));
 assert.ok(!cfg.some(a=>[0x30,0x31,0x32].includes(a[1])));await link.noteOn('piano',60);assert.deepEqual(packets.at(-1),[...keysPacket(1)]);
});
test('iframe heartbeat loss and disconnect release once without flooding a waiting connection',async()=>{
 const {output,link,packets}=setup();await output.begin();output.push({notes:[48,55,60,64],volume:1},1000);await tick();output.heartbeat(1000);output.watchdog(1601);await tick();assert.equal(masks(packets).at(-1),0);
 const n=packets.length;link.ready=false;for(let i=0;i<100;i++)output.push({notes:[48,55,60,64],volume:1},2000+i);await tick();assert.equal(packets.length,n);
});
test('late queued write cannot restart a chord after pause',async()=>{
 const {output,link,packets}=setup();await output.begin();let finish;link.write=b=>{packets.push([...b]);return new Promise(r=>finish=r);};
 output.push({notes:[48,55,60,64],volume:1},1000);const first=finish;output.stop();const stopped=finish;first();stopped();await tick();assert.equal(masks(packets).at(-1),0);assert.equal(link.wideMask,0);
});
