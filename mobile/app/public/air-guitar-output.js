import {configPacket,keys32Packet,quantizeParameters} from './piano-link.js';

const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
const pack=commands=>Uint8Array.from(commands.flatMap(([id,n])=>[...configPacket(id,n)]));
export function guitarMask(notes){
 if(!Array.isArray(notes)||notes.length>4||notes.some(n=>!Number.isInteger(n)||n<40||n>71)||new Set(notes).size!==notes.length)throw Error('吉他音符必须为 E2–B4 内至多四个独立音');
 return notes.reduce((mask,n)=>(mask|2**(n-40))>>>0,0);
}
// Owns the existing SPP session only while the gesture-guitar page is active.
// It never imports PreviewAudio, AudioContext or an audio file.
export class GuitarOutput{
 constructor({link,state,notify=()=>{}}){Object.assign(this,{link,state,notify});this.enabled=false;this.started=false;this.preparing=null;this.flushTask=null;this.desired=null;this.mask=0;this.silent=true;this.level=state().volume;this.lastExpression=-Infinity;this.qVolume=-1;this.qSpace=-1;this.epoch=0;this.version=0;this.lastBeat=0;}
 status(){
  if(!this.link.ready)return {kind:'waiting',label:'请连接 FPGA · 手机不发声'};
  if(!this.link.performanceStatus?.guitar)return {kind:'waiting',label:'需要配套的 32 声部吉他固件'};
  if(!this.link.fxStatus?.values||this.link.fxStatus.values.length!==16)return {kind:'waiting',label:'等待 FPGA 音效状态'};
  return {kind:'fpga',label:'FPGA 吉他 · 4 声部'};
 }
 async begin(){
  if(this.started&&this.session===this.link.session)return true;
  if(!this.enabled||this.status().kind!=='fpga')return false;
  if(this.preparing)return this.preparing;
  const epoch=this.epoch,session=this.link.session;
  if(!this.restore||this.session!==session)this.restore={instrument:this.link.performanceStatus.instrument,fx:[...this.link.fxStatus.values]};
  this.session=session;this.level=this.state().volume;this.link.allOff();this.link.wideMask=0;
  const q=quantizeParameters({...this.state(),attack:2,decay:100,sustain:75,release:100,volume:0});
  const commands=[[0x2e,0],[0x50,0],[0x27,0],[0x2a,0],[0x1f,0],[0x23,1],[1,q.attack],[2,q.decay],[3,q.sustain],[4,q.release],[5,0],[0x10,4],[0x19,48]];
  this.preparing=(async()=>{
   try{await this.link.write(Uint8Array.from([...keys32Packet(0),...pack(commands)]));
    if(epoch!==this.epoch||session!==this.link.session||!this.enabled||!this.link.ready)return false;
    this.started=true;this.mask=0;this.qVolume=0;this.qSpace=48;return true;
   }catch(e){this.notify(e.message);return false;}finally{this.preparing=null;}
  })();return this.preparing;
 }
 push({notes=[],volume=0,space=.5}={},now=Date.now()){
  if(!this.enabled||!Number.isFinite(volume)||!Number.isFinite(space))return;
  const mask=guitarMask(notes);this.desired={mask,volume:clamp(volume,0,1),space:clamp(space,0,1),now};
  if(this.status().kind!=='fpga'){this.stop();this.started=false;return;}
  if(this.session!==this.link.session)this.started=false;
  if(!this.started){void this.begin().then(ok=>{if(ok)this.flush();});return;}
  this.flush();
 }
 flush(){
  if(this.flushTask||!this.started||!this.desired||!this.enabled||!this.link.ready||this.session!==this.link.session)return;
  const d=this.desired,version=this.version,epoch=this.epoch,maskChanged=d.mask!==this.mask;
  const qVolume=Math.round(this.level/100*d.volume*15),qSpace=Math.round(d.space*32)*3;
  const expression=d.now-this.lastExpression>=100;
  if(!maskChanged&&(!expression||(qVolume===this.qVolume&&qSpace===this.qSpace)))return;
  this.link.wideMask=d.mask;
  if(d.mask)this.silent=false;
  const bytes=[];
  if(maskChanged){if(this.mask&&d.mask)bytes.push(...keys32Packet(0));bytes.push(...keys32Packet(d.mask));}
  if(expression){if(qVolume!==this.qVolume)bytes.push(...configPacket(5,qVolume));if(qSpace!==this.qSpace)bytes.push(...configPacket(0x19,qSpace));}
  this.flushTask=(async()=>{
   try{await this.link.write(Uint8Array.from(bytes));
    if(epoch===this.epoch&&version===this.version){this.mask=d.mask;if(expression){this.qVolume=qVolume;this.qSpace=qSpace;this.lastExpression=d.now;}}
   }catch(e){this.notify(e.message);this.stop();}
   finally{this.flushTask=null;if(epoch===this.epoch&&version===this.version&&this.desired!==d)this.flush();}
  })();
 }
 stop(){
  const sounding=!this.silent;this.silent=true;
  this.version++;this.desired=null;this.mask=0;
  if(this.link.wideMask!==null)this.link.wideMask=0;
  if(this.started&&this.link.connected&&sounding)void this.link.write(Uint8Array.from([...keys32Packet(0),...configPacket(0x2b,1)])).catch(()=>{});
 }
 setLevel(value){if(Number.isFinite(value))this.level=clamp(value,0,100);}
 heartbeat(now=Date.now()){this.lastBeat=now;}
 watchdog(now=Date.now()){if(this.enabled&&now-this.lastBeat>600)this.stop();}
 async end(){
  const restore=this.restore,same=this.session===this.link.session;
  this.stop();this.epoch++;this.enabled=false;this.started=false;this.restore=null;
  if(this.link.connected&&same){
   await this.link.releaseWideKeys();
   if(restore)await this.link.write(pack([[0x23,restore.instrument],...restore.fx.slice(0,15).map((n,i)=>[0x10+i,n])]));
   await this.link.configure(this.state());
  }else this.link.wideMask=null;
 }
}
