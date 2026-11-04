// Protocol constants match the released KNOB_FX32 HDL. No audio is synthesized here.
export const FPGA_SAMPLE_RATE=26250000/576;
export const DEFAULT_MAPPING=Array.from({length:32},(_,i)=>60+i);
export function decodePerformance(p){
  const b=(start,width)=>{let n=0;for(let i=0;i<width;i++)n+=((p[(start+i)>>3]>>((start+i)&7))&1)*2**i;return n;};
  return {keys:b(0,32),activeCount:b(32,6),bank:b(38,1),hold:!!b(39,1),testCount:b(40,6),bpm:b(71,8),song:b(79,2),
    eventRecording:!!b(82,1),recordCount:b(84,10),uploadReceived:b(94,8),selected:b(102,5),uploadReady:!!b(108,1),
    practiceProgress:b(109,8),practiceLength:b(117,8),stopped:!!b(127,1),selectedMidi:b(128,8),
    audioCount:b(200,17)+b(219,1)*131072,audioRecording:!!b(217,1),audioFull:!!b(218,1),audioCapable:!!b(220,1),
    practiceRunning:!!b(221,1),instrument:b(223,2),mappingResetDone:!!b(225,1),uploadMatrixOK:!!b(231,1),audioArmed:!!b(239,1)};
}
export function validateMapping(notes){if(!Array.isArray(notes)||notes.length!==32||!notes.every(n=>Number.isInteger(n)&&n>=0&&n<=127))throw Error('键位必须是32个0～127的MIDI音符');return [...notes];}
export function encodeScore(song,mapping){
  validateMapping(mapping);
  if(!Array.isArray(song.score)||!song.score.length||song.score.length>128)throw Error('FPGA曲谱支持1～128个音符或休止事件');
  const events=song.score.map(e=>{
    const duration=Math.round(e.beats*4);if(!Number.isFinite(e.beats)||duration<1||duration>63||Math.abs(e.beats*4-duration)>.0001)throw Error('音长须为1/4拍的整数倍，最长15.75拍');
    const note=e.note===null?255:mapping.indexOf(e.note);
    if(note<0)throw Error(`键位中缺少MIDI ${e.note}，请先适配曲谱键位`);
    return {note,duration};
  });
  return {events,checksum:events.reduce((c,e)=>c^e.note^e.duration,events.length),matrix:events.every(e=>e.note<16||e.note===255)};
}
export function mappingForScore(song,current=DEFAULT_MAPPING){
  const notes=[...new Set(song.score.filter(e=>e.note!==null).map(e=>e.note))];
  if(notes.length>16)throw Error('压力垫跟练最多16种不同音高，请选更短片段');
  const result=validateMapping(current),ordered=notes.sort((a,b)=>a-b);
  ordered.forEach((n,i)=>result[i]=n);return result;
}
// RIFF requires an integer rate. Resample instead of silently changing pitch/duration.
export function pcmToWav(pcm,sourceRate=FPGA_SAMPLE_RATE,targetRate=48000){
  if(!(pcm instanceof Int16Array)||!pcm.length)throw Error('没有可保存的FPGA录音');
  const count=Math.max(1,Math.round(pcm.length*targetRate/sourceRate));
  const out=new Uint8Array(44+count*2),v=new DataView(out.buffer),str=(at,s)=>[...s].forEach((c,i)=>v.setUint8(at+i,c.charCodeAt(0)));
  str(0,'RIFF');v.setUint32(4,out.length-8,true);str(8,'WAVE');str(12,'fmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);v.setUint32(24,targetRate,true);v.setUint32(28,targetRate*2,true);v.setUint16(32,2,true);v.setUint16(34,16,true);str(36,'data');v.setUint32(40,count*2,true);
  for(let i=0;i<count;i++){const pos=i*sourceRate/targetRate,a=Math.min(pcm.length-1,Math.floor(pos)),b=Math.min(pcm.length-1,a+1);v.setInt16(44+i*2,Math.round(pcm[a]+(pcm[b]-pcm[a])*(pos-a)),true);}return out;
}
const delay=ms=>new Promise(r=>setTimeout(r,ms));
export class FpgaSync {
  constructor(link,{onProgress=()=>{},timeout=5500,blockTimeout=5000,retries=2}={}){Object.assign(this,{link,onProgress,timeout,blockTimeout,retries});this.busy=false;this.label='';this.progress=0;this.message='';this.pcm=null;this.cancelled=false;}
  cancel(){this.cancelled=true;this.controller?.abort();}
  check(){if(this.cancelled)throw Error('已取消，未完成的数据不会保存');if(!this.link.connected||!this.link.ready)throw Error('请先连接并确认FPGA');}
  update(message,progress=this.progress){this.message=message;this.progress=progress;this.onProgress(this);}
  async operation(label,fn){if(this.busy)throw Error('请等待当前同步完成');this.cancelled=false;this.check();this.busy=true;this.link.transferBusy=true;this.controller=new AbortController();this.label=label;this.progress=0;this.update(label);
    try{return await fn();}finally{this.busy=false;this.link.transferBusy=false;this.controller=null;this.onProgress(this);}}
  async command(id,value){this.check();await this.link.write(Uint8Array.of(0xf5,id,value,0xf5^id^value));this.check();}
  async commands(pairs){this.check();await this.link.write(Uint8Array.from(pairs.flatMap(([id,v])=>[0xf5,id,v,0xf5^id^v])));this.check();}
  async reply(action,predicate,timeout=this.timeout){
    this.check();const reply=this.link.waitFrame(predicate,{timeout,signal:this.controller?.signal});reply.catch(()=>{});
    try{await action();return await reply;}catch(e){this.controller?.abort();await reply.catch(()=>{});throw e;}}
  async prepare(){this.link.allOff();await this.commands([[0x2e,0],[0x27,0],[0x2a,0],[0x2b,1],[0x23,0]]);}
  async readOne(slot,expected){return this.reply(()=>this.command(0x28,slot),s=>s.type==='performance'&&s.instrument===0&&s.selected===slot&&(expected===undefined||s.selectedMidi===expected));}
  async readMapping(){return this.operation('读取32槽键位',async()=>{
    await this.prepare();this.link.slotNotes=null;this.link.mappingRequired=true;const result=[];
    for(let i=0;i<32;i++){const s=await this.readOne(i);result.push(s.selectedMidi);this.update(`已读取 ${i+1}/32 槽`,(i+1)/32);}
    this.link.slotNotes=validateMapping(result);await this.command(0x28,0);return [...result];});}
  async writeMapping(notes){const target=validateMapping(notes);return this.operation('写入并核对键位',()=>this.writeMappingInside(target));}
  async writeMappingInside(notes){
    await this.prepare();this.link.slotNotes=null;this.link.mappingRequired=true;
    for(let i=0;i<32;i++){
      await this.commands([[0x30,i],[0x31,notes[i]]]);await this.readOne(i,notes[i]);this.update(`FPGA已确认 ${i+1}/32 槽`,(i+1)/32);
    }
    this.link.slotNotes=[...notes];await this.command(0x28,0);return [...notes];
  }
  async resetMapping(){return this.operation('恢复FPGA默认键位',async()=>{
    await this.prepare();this.link.slotNotes=null;this.link.mappingRequired=true;await this.command(0x32,1);
    for(let i=0;i<32;i++){await this.readOne(i,60+i);this.update(`默认键位已确认 ${i+1}/32`,(i+1)/32);}
    this.link.slotNotes=[...DEFAULT_MAPPING];await this.command(0x28,0);return [...DEFAULT_MAPPING];});}
  async uploadScore(song,mapping){const encoded=encodeScore(song,mapping);
    if(!this.link.slotNotes||mapping.some((n,i)=>n!==this.link.slotNotes[i]))throw Error('请先读取或写入并确认当前键位，再上传曲谱');
    return this.operation('上传脱机曲谱',async()=>{
    await this.prepare();await this.command(0x40,encoded.events.length);
    for(let i=0;i<encoded.events.length;i++){
      const e=encoded.events[i];await this.commands([[0x41,i],[0x42,e.note],[0x43,e.duration],[0x44,1]]);
      // At 9600 baud a bounded chunk prevents UART/native queue flooding.
      if((i+1)%8===0||i===encoded.events.length-1){await this.reply(()=>this.command(0x28,0),s=>s.type==='performance'&&s.uploadReceived===i+1&&!s.uploadReady);this.update(`已接收 ${i+1}/${encoded.events.length} 事件`,(i+1)/encoded.events.length*.9);}
    }
    await this.reply(()=>this.command(0x45,encoded.checksum),s=>s.type==='performance'&&s.uploadReady&&s.uploadReceived===encoded.events.length&&(!encoded.matrix||s.uploadMatrixOK));
    await this.commands([[0x2c,Math.max(40,Math.min(80,Math.round(song.bpm)))],[0x2d,3]]);
    this.update('曲谱校验通过，已选为板端上传曲谱；可断开手机后在屏幕开始跟练',1);return encoded;});}
  async startCapture(){return this.operation('启动FPGA录音',async()=>{
    this.pcm=null;
    await this.reply(()=>this.command(0x60,0),s=>s.type==='performance'&&s.audioCapable&&!s.audioRecording&&!s.audioArmed);
    await this.reply(()=>this.command(0x60,3),s=>s.type==='performance'&&s.audioCapable&&!s.audioFull&&(s.audioArmed||s.audioRecording));
    this.update('已待录：首个非零声音开始抓取，最长约2.876秒',1);});}
  async stopCapture(){return this.operation('停止FPGA录音',async()=>{const s=await this.reply(()=>this.command(0x60,0),s=>s.type==='performance'&&!s.audioRecording&&!s.audioArmed);this.update(`录音已停止，共 ${s.audioCount} 样本`,1);return s.audioCount;});}
  async downloadCapture(){return this.operation('回传真实FPGA录音',async()=>{
    const meta=await this.reply(()=>this.command(0x60,0),s=>s.type==='performance'&&s.audioCapable&&!s.audioRecording&&!s.audioArmed);
    const count=meta.audioCount;if(!count||count>131072)throw Error('板端没有有效录音，请先待录并演奏');
    this.pcm=null;const pcm=new Int16Array(count),blocks=Math.ceil(count/256);const start=Date.now();
    for(let block=0;block<blocks;block++){
      let packet,error;
      for(let attempt=0;attempt<=this.retries;attempt++){
        this.check();
        try{
          // Install a fresh waiter for each retry; corrupt or old blocks are ignored.
          const pending=this.link.waitFrame(s=>s.type==='pcm'&&s.block===block&&s.samples.length===Math.min(256,count-block*256),{timeout:this.blockTimeout,signal:this.controller.signal});pending.catch(()=>{});
          try{await this.commands([[0x62,block>>8],[0x61,block&255]]);packet=await pending;break;}catch(e){await pending.catch(()=>{});throw e;}
        }catch(e){error=e;this.check();if(attempt<this.retries){this.update(`第 ${block+1} 块重试 ${attempt+1}/${this.retries}`);await delay(100);}}
      }
      if(!packet)throw Error(`第${block+1}块回传失败：${error?.message||'超时'}，未保存不完整录音`);
      pcm.set(packet.samples,block*256);const elapsed=(Date.now()-start)/1000,eta=elapsed/(block+1)*(blocks-block-1);
      this.update(`已回传 ${block+1}/${blocks} 块 · 预计剩余 ${Math.ceil(eta)} 秒`,(block+1)/blocks);
    }
    // A capture started on another controller invalidates a partially read buffer.
    const end=await this.reply(()=>this.command(0x28,meta.selected),s=>s.type==='performance'&&!s.audioRecording&&!s.audioArmed&&s.audioCount===count);
    if(end.audioCount!==count)throw Error('录音已改变，请重新回传');this.pcm=pcm;this.update('真实PCM回传完成，可保存WAV',1);return pcm;
  });}
}
