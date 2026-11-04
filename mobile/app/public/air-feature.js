import {AirNotes} from './air-bridge-core.js';
import {GuitarOutput} from './air-guitar-output.js';
export function installAirPiano({link,audio,state,notify,beforeOpen,onReturn}){
 const notes=new AirNotes({link,audio,state,notify}),guitar=new GuitarOutput({link,state,notify});
 let overlay=null,frame=null,mode='piano',selection=Promise.resolve(),closing=false;
 const stop=()=>{notes.stop();guitar.stop();};
 const selectInstrument=next=>{
  selection=selection.then(async()=>{
   if(closing||!overlay)return;
   notes.enabled=false;notes.end();guitar.stop();if(guitar.enabled||guitar.restore)await guitar.end();
   if(closing||!overlay)return;
   mode=next==='guitar'?'guitar':'piano';notes.enabled=mode==='piano';guitar.enabled=mode==='guitar';
   if(guitar.enabled)await guitar.begin();else if(link.ready)await notes.init();
  });return selection;
 };
 const close=async()=>{
  if(closing||!overlay)return;closing=true;notes.enabled=false;guitar.enabled=false;notes.end();guitar.stop();
  frame?.contentWindow?.postMessage('air-close',location.origin);overlay?.remove();overlay=frame=null;
  try{await selection;if(guitar.restore)await guitar.end();else if(link.ready)await link.configure(state());}
  finally{audio.setVolume(state().volume);if(link.native)void link.request('orientation',{landscape:false}).catch(()=>{});closing=false;onReturn();}
 };
 window.TouchAirPiano={init:async()=>{await selection;if(closing||!overlay)return false;return mode==='guitar'?guitar.begin():notes.init();},on:i=>notes.on(i),off:i=>notes.off(i),stop,
  status:()=>mode==='guitar'?guitar.status():notes.status(),getVolume:()=>mode==='guitar'?guitar.level:notes.level,
  volume:v=>mode==='guitar'?guitar.setLevel(v):notes.volume(v),precision:v=>notes.setPrecision(v),selectInstrument,
  guitarFrame:value=>{if(mode==='guitar')guitar.push(value);},
  heartbeat:()=>{notes.heartbeat();guitar.heartbeat();},close};
 document.addEventListener('click',e=>{
  const button=e.target.closest('[data-action="air-piano"],[data-action="air-guitar"]');if(!button||overlay||closing)return;
  beforeOpen();notes.level=state().volume;mode=button.dataset.action==='air-guitar'?'guitar':'piano';notes.enabled=mode==='piano';guitar.enabled=mode==='guitar';notes.heartbeat();guitar.heartbeat();
  overlay=document.createElement('div');overlay.className='air-overlay';overlay.setAttribute('role','dialog');overlay.setAttribute('aria-label','空中演奏');
  frame=document.createElement('iframe');frame.src='/air-piano/index.html'+(mode==='guitar'?'?instrument=guitar':'');frame.title='手势钢琴与吉他';frame.allow='camera \'self\'; fullscreen';overlay.append(frame);document.body.append(overlay);
  if(link.native)void link.request('orientation',{landscape:true}).catch(()=>{});
 });
 document.addEventListener('keydown',e=>{if(overlay&&e.key==='Escape'){e.preventDefault();e.stopImmediatePropagation();void close();}},true);
 window.addEventListener('pagehide',stop);document.addEventListener('visibilitychange',()=>{if(document.hidden)stop();});
 setInterval(()=>{if(notes.enabled){if(notes.status().kind==='waiting')notes.stop();notes.watchdog();}if(guitar.enabled){if(guitar.status().kind==='waiting')guitar.stop();guitar.watchdog();}},150);
}
