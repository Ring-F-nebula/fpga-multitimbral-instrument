import test from 'node:test';import assert from 'node:assert/strict';import {AirNotes} from '../public/air-bridge-core.js';
import {PianoLink} from '../public/piano-link.js';import {PerformanceAudio} from '../public/performance-audio.js';
function setup(link={ready:true}){const calls=[];const audio={init:async()=>calls.push('init'),setVolume:v=>calls.push(['volume',v]),on:(...v)=>calls.push(['on',...v]),off:i=>calls.push(['off',i])};const bridge=new AirNotes({link,audio,state:()=>({volume:60,release:400}),notify:()=>{}});bridge.precise=false;return {bridge,calls};}
test('gesture indices map to firmware C4-D#5 and repeated frames do not repeat note-on',()=>{
 const {bridge,calls}=setup();bridge.enabled=true;assert.equal(bridge.on(-1),false);assert.equal(bridge.on(16),false);bridge.on(0);bridge.on(15);bridge.on(0);
 assert.deepEqual(calls.filter(x=>x[0]==='on').map(x=>x[2]),[60,75]);bridge.stop();assert.equal(calls.filter(x=>x[0]==='off').length,2);
});
test('native/disconnected hardware never falls back to phone audio',()=>{const {bridge,calls}=setup({ready:false,native:true});bridge.enabled=true;assert.equal(bridge.on(0),false);assert.equal(calls.length,0);});
test('iframe heartbeat loss releases every held voice',()=>{const {bridge,calls}=setup();bridge.enabled=true;bridge.heartbeat(1000);bridge.on(1);bridge.on(4);bridge.watchdog(1601);assert.equal(bridge.notes.size,0);assert.equal(calls.filter(x=>x[0]==='off').length,2);});
test('new gesture input sends the real STREAM3 16-key masks including all-off',()=>{
 const packets=[],link=new PianoLink();link.ready=link.connected=true;link.write=b=>{packets.push([...b]);return Promise.resolve();};
 const state=()=>({attack:10,decay:200,sustain:55,release:400,volume:60});
 const bridge=new AirNotes({link,audio:new PerformanceAudio(link,()=>{}),state,notify:()=>{}});bridge.enabled=true;bridge.precise=false;
 bridge.on(0);bridge.on(15);bridge.on(0);bridge.off(0);bridge.stop();
 assert.deepEqual(packets.filter(p=>p[0]===0xf6),[[0xf6,1,0,0xf7],[0xf6,1,128,0x77],[0xf6,0,128,0x76],[0xf6,0,0,0xf6]]);
});

test('precision transport never holds two FPGA keys and keeps release short',()=>{
 const packets=[],link=new PianoLink();link.ready=link.connected=true;link.write=b=>{packets.push([...b]);return Promise.resolve();};
 const bridge=new AirNotes({link,audio:new PerformanceAudio(link,()=>{}),state:()=>({attack:10,decay:200,sustain:55,release:400,volume:60}),notify:()=>{}});bridge.enabled=true;
 bridge.on(0);bridge.on(15);bridge.on(15);bridge.stop();const masks=packets.filter(p=>p[0]===0xf6).map(p=>p[1]|p[2]<<8);
 assert.deepEqual(masks,[1,0,32768,0]);assert.ok(masks.every(n=>n===0||(n&(n-1))===0));assert.equal(bridge.parameters().release,50);
});
