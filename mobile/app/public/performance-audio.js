import {PreviewAudio} from './audio.js';
export class PerformanceAudio extends PreviewAudio {
  constructor(link,notify){super();this.link=link;this.notify=notify;this.parameterKey='';}
  on(id,midi,velocity,instrument,params,pad=0){
    if(this.link.connected||this.link.connecting){
      if(!this.link.ready){this.notify('FPGA 尚未确认连接');return false;}
      if(instrument==='drums'||instrument==='guzheng'){this.notify('当前 FPGA 提供原工程音色，请选择钢琴演奏');return false;}
      const key=JSON.stringify([params.attack,params.decay,params.sustain,params.release,params.volume]);
      if(key!==this.parameterKey){this.parameterKey=key;void this.link.configure({...params,volume:params.volume??this.volume*100}).catch(()=>{});}
      try{return this.link.noteOn(id,midi,String(id).startsWith('air-')?undefined:pad);}catch(e){this.notify(e.message);return false;}
    }
    super.on(id,midi,velocity,instrument,params,pad);
  }
  off(id,immediate=false){this.link.noteOff(id);super.off(id,immediate);}
  stop(){this.link.allOff();super.stop();}
}
