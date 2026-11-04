import test from 'node:test';
import assert from 'node:assert/strict';
import {PianoLink,StatusParser,keys32Packet} from '../public/piano-link.js';
import {decodePerformance,FpgaSync,DEFAULT_MAPPING,encodeScore,mappingForScore,pcmToWav,FPGA_SAMPLE_RATE} from '../public/fpga-sync.js';
import {PerformanceAudio} from '../public/performance-audio.js';
import {readFile} from 'node:fs/promises';
import {DOMParser} from './vendor/xmldom/lib/index.js';
import {ONLINE_SCORES,musicXmlScore} from '../public/online-scores.js';
const packet=(version,payload)=>{const a=[0xa5,0x5a,version,0x66,...payload];a.push(a.slice(2).reduce((a,b)=>a^b,0));return a;};
const pcmPacket=(block,samples)=>packet(7,[block&255,block>>8,samples.length&255,samples.length>>8,...samples.flatMap(n=>[n&255,(n>>8)&255])]);
function performance(values={}){
 const p=new Uint8Array(42),put=(at,width,n)=>{for(let j=0;j<width;j++)if(Math.floor(n/2**j)%2)p[(at+j)>>3]|=1<<((at+j)&7);};
 for(const [key,at,width] of [['keys',0,32],['selected',102,5],['uploadReceived',94,8],['uploadReady',108,1],['selectedMidi',128,8],['audioCountLow',200,17],['audioCountHigh',219,1],['audioRecording',217,1],['audioArmed',239,1],['instrument',223,2],['uploadMatrixOK',231,1],['practiceRunning',221,1],['song',79,2]])put(at,width,values[key]||0);
 put(220,1,1);return packet(6,[...p,0]); // V6 reserves byte46; checksum is byte47.
}
function boardFixture({count=529,dropBlockOnce=-1,corruptBlock=-1}={}){
 const link=new PianoLink(),sync=new FpgaSync(link,{timeout:80,blockTimeout:30,retries:2});link.connected=link.ready=true;link.session='test';
 const board={mapping:[...DEFAULT_MAPPING],selected:0,mapIndex:0,audioCount:count,audioRecording:false,audioArmed:false,instrument:0,uploadReceived:0,uploadReady:false,uploadMatrixOK:false,events:[],expected:0,crc:0,blockHigh:0,requests:[],writes:[]};
 const emit=()=>link.receive(performance({...board,selectedMidi:board.mapping[board.selected],audioCountLow:board.audioCount%131072,audioCountHigh:Math.floor(board.audioCount/131072)}));
 let dropped=false;
 link.writer={write:async bytes=>{board.writes.push([...bytes]);for(let i=0;i<bytes.length;){
  const code=bytes[i];if(code===0xf7){i+=6;continue;}if(code===0xf6){i+=4;continue;}if(code!==0xf5){i++;continue;}
  const id=bytes[i+1],v=bytes[i+2];assert.equal(code^id^v,bytes[i+3]);i+=4;
  switch(id){case 0x23:board.instrument=v;break;case 0x28:board.selected=v;break;case 0x30:board.mapIndex=v;break;case 0x31:board.mapping[board.mapIndex]=v;break;case 0x32:board.mapping=[...DEFAULT_MAPPING];break;
   case 0x2c:board.bpm=v;break;case 0x2d:board.song=v;break;case 0x2e:board.practiceRunning=v===1;break;
   case 0x40:board.expected=v;board.uploadReceived=0;board.uploadReady=false;board.events=[];board.crc=v;break;
   case 0x41:board.uploadIndex=v;break;case 0x42:board.uploadNote=v;break;case 0x43:board.uploadDuration=v;break;
   case 0x44:assert.equal(board.uploadIndex,board.uploadReceived);board.events.push([board.uploadNote,board.uploadDuration]);board.uploadReceived++;board.crc^=board.uploadNote^board.uploadDuration;break;
   case 0x45:board.uploadReady=board.uploadReceived===board.expected&&board.crc===v;board.uploadMatrixOK=board.uploadReady&&board.events.every(e=>e[0]<16||e[0]===255);break;
   case 0x60:board.audioArmed=v===3;board.audioRecording=v===1;if(v===1||v===3)board.audioCount=0;break;
   case 0x62:board.blockHigh=v;break;case 0x61:{
    const block=board.blockHigh*256+v;board.requests.push(block);
    if(block===dropBlockOnce&&!dropped){dropped=true;continue;}
    const n=Math.min(256,board.audioCount-block*256),samples=Array.from({length:n},(_,j)=>((block*256+j)%65536)-32768),frame=pcmPacket(block,samples);
    if(block===corruptBlock)frame[frame.length-1]^=1;
    queueMicrotask(()=>{link.receive(frame.slice(0,7));link.receive(frame.slice(7));});break;}
  }
  queueMicrotask(emit);
 }}};
 return {link,sync,board,emit};
}

for(const item of ONLINE_SCORES)test(`full software chain ${item.id}: parse / map / actual protocol echo / upload CRC / silent practice start`,async()=>{
 const xml=await readFile(new URL('./fixtures/'+item.file,import.meta.url),'utf8');
 const song=musicXmlScore(xml,{Parser:DOMParser,name:item.name}),mapping=mappingForScore(song);
 const {sync,board}=boardFixture();await sync.writeMapping(mapping);const result=await sync.uploadScore(song,mapping);
 assert.equal(board.events.length,32);assert.equal(board.uploadReady,true);assert.equal(board.uploadMatrixOK,true);
 assert.deepEqual(board.events,result.events.map(x=>[x.note,x.duration]));assert.equal(board.song,3);assert.equal(board.bpm,80);
 await sync.operation('start',()=>sync.reply(()=>sync.commands([[0x2d,3],[0x2e,1]]),p=>p.type==='performance'&&p.practiceRunning&&p.song===3));
 assert.equal(board.practiceRunning,true);
 // No command in the complete flow asks the FPGA to play a key for the user.
 assert.ok(board.writes.filter(x=>x[0]===0xf7).every(x=>x.slice(1,5).every(v=>v===0)));
});
test('V6 byte offsets decode the production 256-bit info including 131072 and upper voice',()=>{
 const raw=performance({keys:0x80000001,selected:31,selectedMidi:91,uploadReceived:128,uploadReady:1,audioCountHigh:1,instrument:2,uploadMatrixOK:1,audioArmed:1});
 const [s]=new StatusParser().feed(raw);assert.equal(s.keys,0x80000001);assert.equal(s.selected,31);assert.equal(s.selectedMidi,91);assert.equal(s.audioCount,131072);assert.equal(s.audioArmed,true);assert.equal(s.uploadReceived,128);assert.equal(s.uploadMatrixOK,true);assert.equal(s.instrument,2);
});
test('V7 signed PCM, high block bit, fragmented and interleaved V8/V6, CRC rejection',()=>{
 const p=new StatusParser(),samples=[-32768,-1,0,32767],f=pcmPacket(511,samples),bad=[...f];bad[bad.length-1]^=1;
 const wax=packet(8,Array(98).fill(0));assert.equal(wax.length,103);
 assert.deepEqual(p.feed([0,99,...bad,...f.slice(0,7)]),[]);
 const frames=p.feed([...f.slice(7),...wax,...performance()]);assert.deepEqual([...frames[0].samples],samples);assert.equal(frames[0].block,511);assert.equal(frames[1].type,'pressure');assert.equal(frames[2].type,'performance');
});
test('V7 parser keeps all packets in a read larger than 4096 bytes',()=>{
 const stream=Array.from({length:12},(_,i)=>pcmPacket(i,Array(256).fill(i))).flat();assert.equal(new StatusParser().feed(stream).length,12);
});
test('32-slot write/read/reset uses actual board echo; highest slot plays F7 bit31',async()=>{
 const {link,sync,board}=boardFixture();const mapping=Array.from({length:32},(_,i)=>48+i);assert.deepEqual(await sync.writeMapping(mapping),mapping);assert.deepEqual(board.mapping,mapping);
 assert.deepEqual(await sync.readMapping(),mapping);link.noteOn('upper',79,31);await link.tail;assert.deepEqual(board.writes.at(-1),[...keys32Packet(0x80000000)]);
 assert.throws(()=>link.noteOn('unsynced',80,31),/同步/);assert.deepEqual(await sync.resetMapping(),DEFAULT_MAPPING);assert.deepEqual(board.mapping,DEFAULT_MAPPING);
});
test('score maps MIDI to physical slots, preserves rests, validates CRC and matrix flag',async()=>{
 const {sync,board}=boardFixture();const song={bpm:120,score:[{note:48,beats:1},{note:null,beats:.5},{note:55,beats:2}]},mapping=mappingForScore(song);
 await sync.writeMapping(mapping);await sync.uploadScore(song,mapping);assert.deepEqual(board.events,[[0,4],[255,2],[1,8]]);assert.equal(board.uploadReady,true);assert.equal(board.uploadMatrixOK,true);
 assert.throws(()=>encodeScore({score:[{note:60,beats:16}]},DEFAULT_MAPPING),/15.75/);assert.throws(()=>encodeScore({score:[{note:1,beats:1}]},DEFAULT_MAPPING),/缺少/);
});
test('score upload refuses an edited local map that has not been confirmed by FPGA',async()=>{
 const {sync,board}=boardFixture(),score={bpm:80,score:[{note:60,beats:1}]};await assert.rejects(sync.uploadScore(score,DEFAULT_MAPPING),/确认当前键位/);assert.equal(board.events.length,0);
 await sync.writeMapping(DEFAULT_MAPPING);const dirty=[...DEFAULT_MAPPING];dirty[31]=50;await assert.rejects(sync.uploadScore(score,dirty),/确认当前键位/);
});
test('PCM download handles final short block and retries missing blocks without local synthesis',async()=>{
 const {sync,board}=boardFixture({dropBlockOnce:1});const pcm=await sync.downloadCapture();assert.equal(pcm.length,529);assert.equal(pcm[0],-32768);assert.equal(pcm[528],-32240);assert.deepEqual(board.requests,[0,1,1,2]);assert.equal(sync.pcm,pcm);
});
test('capture start clears the old state then confirms actual armed/recording status',async()=>{
 const {sync,board}=boardFixture({count:131072});await sync.startCapture();assert.equal(board.audioArmed,true);assert.equal(board.audioCount,0);assert.match(sync.message,/待录/);assert.equal(await sync.stopCapture(),0);assert.equal(board.audioArmed,false);
});
test('bad PCM checksums exhaust bounded retries and never publish an incomplete recording',async()=>{
 const {sync}=boardFixture({corruptBlock:1});await assert.rejects(sync.downloadCapture(),/第2块回传失败/);assert.equal(sync.pcm,null);assert.equal(sync.busy,false);
});
test('PCM blocks 255/256 cross the request high byte; last block511 works',async()=>{
 const {sync,board}=boardFixture({count:131072});const pcm=await sync.downloadCapture();assert.equal(pcm.length,131072);assert.equal(board.requests.length,512);assert.deepEqual(board.requests.slice(255,258),[255,256,257]);assert.equal(board.requests.at(-1),511);
});
test('cancelling and disconnecting abort waiters; cancellation permits a new operation',async()=>{
 const {sync,link}=boardFixture();const p=sync.operation('waiting',()=>link.waitFrame(()=>false,{timeout:1000,signal:sync.controller.signal}));sync.cancel();await assert.rejects(p,/取消/);assert.equal(link.frameListeners.size,0);
 await sync.readMapping();const pending=link.waitFrame(()=>false,{timeout:1000});await link.disconnect();await assert.rejects(pending,/断开/);
});
test('WAV resamples fractional FPGA sample rate, preserves signed levels and duration',()=>{
 const pcm=new Int16Array(45573).fill(-1000),wav=pcmToWav(pcm),v=new DataView(wav.buffer);assert.equal(new TextDecoder().decode(wav.slice(0,4)),'RIFF');assert.equal(v.getUint32(24,true),48000);assert.equal(v.getInt16(44,true),-1000);assert.equal(v.getUint32(40,true)/2,Math.round(pcm.length*48000/FPGA_SAMPLE_RATE));assert.equal(v.getUint32(4,true),wav.length-8);
});
test('physical pad uses its confirmed slot while gesture piano preserves its fixed pitch labels',async()=>{
 const {link,board}=boardFixture();link.slotNotes=[...DEFAULT_MAPPING];[link.slotNotes[0],link.slotNotes[1]]=[61,60];const errors=[],audio=new PerformanceAudio(link,m=>errors.push(m));
 const params={attack:1,decay:50,sustain:60,release:50,volume:60};assert.equal(audio.on('pad0',60,1,'piano',params,0),false);assert.match(errors.at(-1),/同步/);
 assert.equal(audio.on('air-0',60,1,'piano',params,0),true);await link.tail;assert.deepEqual(board.writes.at(-1),[...keys32Packet(2)]);
});
