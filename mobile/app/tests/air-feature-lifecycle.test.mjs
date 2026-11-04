import test from 'node:test';import assert from 'node:assert/strict';
import {installAirPiano} from '../public/air-feature.js';
import {PianoLink} from '../public/piano-link.js';
import {PerformanceAudio} from '../public/performance-audio.js';
test('page entry, guitar/piano switch and close serialize hardware setup without admitting late piano keys',async()=>{
 const saved=Object.fromEntries(['window','document','location','setInterval'].map(k=>[k,globalThis[k]]));
 const handlers={},packets=[],link=new PianoLink();let returned=0;
 Object.assign(link,{connected:true,ready:true,session:'page',performanceStatus:{guitar:true,instrument:0,stopped:true},fxStatus:{values:Array(16).fill(0)}});
 link.writer={write:async b=>packets.push([...b])};
 const state=()=>({attack:10,decay:200,sustain:55,release:400,volume:60});
 try{
 globalThis.window={addEventListener(){}};globalThis.location={origin:'http://localhost'};globalThis.setInterval=()=>0;
 globalThis.document={addEventListener:(name,fn)=>handlers[name]=fn,body:{append(){}},
 createElement:()=>({setAttribute(){},append(){},remove(){},contentWindow:{postMessage(){}}})};
 installAirPiano({link,audio:new PerformanceAudio(link,()=>{}),state,notify:()=>{},beforeOpen(){},onReturn(){returned++;}});
 handlers.click({target:{closest:()=>({dataset:{action:'air-piano'}})}});
 const api=window.TouchAirPiano;await api.selectInstrument('piano');await api.init();
 assert.equal(api.on(0),true);api.stop();await api.selectInstrument('guitar');assert.equal(api.on(0),false);
 api.guitarFrame({notes:[48,55,60,64],volume:1});await link.tail;
 const switching=api.selectInstrument('piano');await switching;await api.init();
 assert.equal(link.wideMask,null);assert.equal(api.on(15),true);
 const closing=api.close();assert.equal(api.on(0),false);await closing;
 assert.equal(returned,1);assert.equal(link.voices.size,0);assert.equal(await api.init(),false);
 // A queued selection must not reopen the hardware after the dialog closes.
 await api.selectInstrument('piano');assert.equal(api.on(1),false);
 }finally{for(const [key,value] of Object.entries(saved)){if(value===undefined)delete globalThis[key];else globalThis[key]=value;}}
});
