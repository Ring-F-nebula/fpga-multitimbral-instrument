import {configPacket,quantizeParameters} from './piano-link.js';
export class AirNotes{
 constructor({link,audio,state,notify}){Object.assign(this,{link,audio,state,notify});this.notes=new Set();this.enabled=false;this.lastBeat=0;this.level=60;this.precise=true;this.initializedSession=null;this.preparing=null;this.epoch=0;}
 parameters(){return {...this.state(),volume:this.level,...(this.precise?{release:Math.min(Number.isFinite(this.state().release)?this.state().release:50,50)}:{})};}
 setPrecision(value){this.stop();this.precise=!!value;if(this.link.ready)void this.link.configure(this.parameters());}
 status(){return this.link.ready?{kind:'fpga',label:'蓝牙已连接 · FPGA 发声'}:this.link.native||this.link.connected||this.link.connecting?{kind:'waiting',label:'FPGA 待连接 · 未发声'}:{kind:'preview',label:'浏览器合成试听'};}
 async init(){
  this.audio.setVolume(this.level);
  if(this.status().kind==='preview'){await this.audio.init();return true;}
  if(!this.link.ready)return false;
  if(this.preparing)return this.preparing;
  const session=this.link.session,epoch=this.epoch;
  // init is also called on every touchscreen key. Do not clear a held chord
  // or repeatedly switch the FPGA instrument while this page owns the session.
  if(this.initializedSession===session&&!(this.link.performanceStatus?.stopped&&!this.notes.size))return true;
  this.stop();this.link.allOff();
  if(this.link.wideMask!==null)void this.link.releaseWideKeys().catch(()=>{});
  const q=quantizeParameters(this.parameters());
  // STOP is latched in competition_control; selecting piano alone cannot
  // unmute it. Leave practice/replay/test/hold before admitting live keys.
  const commands=[[0x2e,0],[0x50,0],[0x27,0],[0x2a,0],[0x1f,0],[0x23,0],
   [1,q.attack],[2,q.decay],[3,q.sustain],[4,q.release],[5,q.volume]];
  this.preparing=this.link.write(Uint8Array.from(commands.flatMap(([id,value])=>[...configPacket(id,value)])))
   .then(()=>{if(this.epoch===epoch&&this.enabled&&this.link.ready&&this.link.session===session){this.initializedSession=session;return true;}return false;})
   .catch(e=>{this.notify(e.message);return false;}).finally(()=>{this.preparing=null;});
  return this.preparing;
 }
 end(){this.stop();this.epoch++;this.initializedSession=null;}
 on(index){if(!this.enabled||!Number.isInteger(index)||index<0||index>15||this.notes.has(index))return false;
  if(this.status().kind==='waiting'){this.notify('请先返回设备页连接并确认 FPGA');return false;}
  if(this.precise)this.stop();
  if(this.audio.on('air-'+index,60+index,.72,'piano',this.parameters(),index)===false)return false;
  this.notes.add(index);return true;
 }
 off(index){if(this.notes.delete(index))this.audio.off('air-'+index,this.precise);}
 stop(){for(const n of [...this.notes])this.off(n);}
 volume(value){if(!Number.isFinite(value))return;this.level=Math.min(100,Math.max(0,Math.round(value)));this.audio.setVolume(this.level);if(this.link.ready)void this.link.configure(this.parameters());}
 heartbeat(now=Date.now()){this.lastBeat=now;}
 watchdog(now=Date.now()){if(this.enabled&&now-this.lastBeat>600)this.stop();}
}
