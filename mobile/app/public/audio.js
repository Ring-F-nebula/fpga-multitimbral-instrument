import { frequency } from './core.js';
export class PreviewAudio {
  constructor(){this.ctx=null;this.voices=new Map();this.volume=.6;this.active=false;}
  async init(){if(!this.ctx){this.ctx=new AudioContext();this.master=this.ctx.createGain();this.master.gain.value=this.volume*.28;const limit=this.ctx.createDynamicsCompressor();limit.threshold.value=-14;limit.ratio.value=8;this.master.connect(limit);limit.connect(this.ctx.destination);}if(this.ctx.state!=='running')await this.ctx.resume();this.active=true;}
  setVolume(v){this.volume=v/100;if(this.ctx)this.master.gain.setTargetAtTime(this.volume*.28,this.ctx.currentTime,.02);}
  on(id,midi,velocity,instrument,params,pad=0){
    if(!this.ctx||this.ctx.state!=='running')return;
    this.off(id,true);const c=this.ctx,t=c.currentTime,env=c.createGain();env.connect(this.master);const sources=[];const A=Math.max(.002,params.attack/1000),D=Math.max(.01,params.decay/1000),S=params.sustain/100;
    env.gain.setValueAtTime(0,t);env.gain.linearRampToValueAtTime(velocity,t+A);env.gain.exponentialRampToValueAtTime(Math.max(.001,velocity*S),t+A+D);
    const osc=(freq,type='sine',gain=1)=>{const o=c.createOscillator(),g=c.createGain();o.type=type;o.frequency.value=freq;g.gain.value=gain;o.connect(g);g.connect(env);o.start();sources.push(o);return o;};
    const noise=(secs,highpass=0)=>{const b=c.createBuffer(1,Math.floor(c.sampleRate*secs),c.sampleRate),d=b.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=(Math.random()*2-1);const src=c.createBufferSource();src.buffer=b;const f=c.createBiquadFilter();f.type='highpass';f.frequency.value=highpass;src.connect(f);f.connect(env);src.start();sources.push(src);};
    let autoStop=null;
    if(instrument==='drums'){
      env.gain.cancelScheduledValues(t);env.gain.setValueAtTime(Math.max(.001,velocity),t);
      let len=.25;
      if(pad===12){const o=osc(150);o.frequency.exponentialRampToValueAtTime(42,t+.15);len=.35;}
      else if(pad>=4&&pad<=7){const o=osc([190,150,110,80][pad-4]);o.frequency.exponentialRampToValueAtTime([90,70,55,40][pad-4],t+.18);len=.4;}
      else if(pad===13||pad===14||pad===11){noise(.3,900);osc(180,'triangle',.22);len=pad===11?.12:.24;}
      else if(pad===3){osc(560,'square',.15);osc(845,'square',.15);len=.2;}
      else {len=[0,1,9].includes(pad)?1.1:.13;noise(len,6000);}
      env.gain.exponentialRampToValueAtTime(.0001,t+len);autoStop=len+.05;
    }else if(instrument==='guzheng'){
      const f=frequency(midi),len=c.sampleRate*4,buf=c.createBuffer(1,len,c.sampleRate),data=buf.getChannelData(0),period=Math.max(2,Math.round(c.sampleRate/f));
      for(let i=0;i<period;i++)data[i]=(Math.random()*2-1)*.7;
      for(let i=period;i<len;i++)data[i]=.498*(data[i-period]+data[i-period+1]);
      const src=c.createBufferSource();src.buffer=buf;src.connect(env);src.start();sources.push(src);autoStop=4.1;
    }else {
      const f=frequency(midi);osc(f,'sine',.7);osc(f*2,'sine',.18);osc(f*3,'sine',.08);osc(f*4.002,'sine',.04);
    }
    const voice={env,sources,release:params.release/1000,timer:null,instrument};this.voices.set(id,voice);
    if(autoStop)voice.timer=setTimeout(()=>{if(this.voices.get(id)===voice)this.off(id,true);},autoStop*1000);
  }
  off(id,immediate=false){const v=this.voices.get(id);if(!v||!this.ctx)return;if(v.instrument==='drums'&&!immediate)return;this.voices.delete(id);clearTimeout(v.timer);const t=this.ctx.currentTime,r=immediate?.015:Math.max(.02,v.release);v.env.gain.cancelAndHoldAtTime(t);v.env.gain.linearRampToValueAtTime(0,t+r);for(const s of v.sources){try{s.stop(t+r+.02);}catch{}}setTimeout(()=>v.env.disconnect(),(r+.1)*1000);}
  stop(){for(const id of [...this.voices.keys()])this.off(id,true);}
}
