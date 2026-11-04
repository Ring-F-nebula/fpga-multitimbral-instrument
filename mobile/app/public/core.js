export const DEFAULT_NOTES = [72,73,74,75,68,69,70,71,64,65,66,67,60,61,62,63];
export const KEY_BINDINGS = ['1','2','3','4','q','w','e','r','a','s','d','f','z','x','c','v'];
export const DRUMS = ['吊镲','叮叮镲','镲边','牛铃','高嗵鼓','中嗵鼓','低嗵鼓','落地嗵鼓','闭镲','开镲','踏镲','边击','底鼓','军鼓','拍手','铃鼓'];
export const INSTRUMENTS = [
  {id:'piano', name:'钢琴',category:'键盘', description:'清晰、温暖，留住每一次触碰。', tags:'清晰 · 自然 · 温暖', preset:'柔和长音',color:'blue'},
  {id:'guzheng', name:'古筝',category:'民族', description:'指尖轻落，弦音悠长。', tags:'清亮 · 空灵 · 弦韵',preset:'自然拨弦',color:'peach'},
  {id:'drums', name:'架子鼓',category:'打击乐', description:'把你的节奏，交给指尖。', tags:'节奏 · 力度 · 律动',preset:'标准鼓组',color:'lavender'}
];
export function noteName(midi) { return ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'][midi%12]+(Math.floor(midi/12)-1); }
export function frequency(midi){ return 440*2**((midi-69)/12); }
export function duration(ms){ const s=Math.floor(ms/1000);return `${Math.floor(s/60).toString().padStart(2,'0')}:${(s%60).toString().padStart(2,'0')}`; }
export function pressureValue(value,curve='standard'){const n=Math.max(0,Math.min(1,value));return curve==='soft'?Math.sqrt(n):curve==='firm'?n*n:n;}
export function makeScore(notes){return notes.map((note,i)=>({note,beats:(i%7===6?2:1)}));}
export const SONGS = [
  {id:'star',name:'小星星',subtitle:'一闪一闪，指尖的第一段旋律。',level:'入门',key:'C 大调',bpm:80,color:'blue',art:'star',score:makeScore([60,60,67,67,69,69,67,65,65,64,64,62,62,60,67,67,65,65,64,64,62,67,67,65,65,64,64,62,60,60,67,67,69,69,67,65,65,64,64,62,62,60])},
  {id:'joy',name:'欢乐颂',subtitle:'让简单的音符，变成快乐。',level:'入门',key:'C 大调',bpm:92,color:'peach',art:'sun',score:makeScore([64,64,65,67,67,65,64,62,60,60,62,64,64,62,62,64,64,65,67,67,65,64,62,60,60,62,64,62,60,60])},
  {id:'scale',name:'指尖热身',subtitle:'从低音到高音，熟悉每一个触点。',level:'基础',key:'C 大调',bpm:72,color:'lavender',art:'wave',score:makeScore([60,62,64,65,67,69,71,72,72,71,69,67,65,64,62,60])}
];
// Explicit quarter-note durations for the two 4/4 practice phrases.
SONGS[1].score.forEach((n,i)=>n.beats=[1,1,1,1,1,1,1,1,1,1,1,1,1.5,.5,2][i%15]);
SONGS[2].score.forEach((n,i)=>n.beats=i===15?2:1);
export function validEnvelope(p){return !!p&&['attack','decay','release'].every(k=>Number.isFinite(p[k])&&p[k]>=1&&p[k]<=2000)&&Number.isFinite(p.sustain)&&p.sustain>=0&&p.sustain<=100;}
export function validateRecord(r){return !!r && typeof r.name==='string' && r.name.length<=200 && Number.isFinite(r.duration) && r.duration>=0 && r.duration<=601000 && Array.isArray(r.events) && r.events.length<=20000 && r.events.every(e=>['on','off'].includes(e.type)&&Number.isFinite(e.time)&&e.time>=0&&e.time<=r.duration+1000&&Number.isInteger(e.midi)&&e.midi>=0&&e.midi<=127&&Number.isInteger(e.pad)&&e.pad>=0&&e.pad<16&&Number.isFinite(e.velocity)&&e.velocity>=0&&e.velocity<=1)&&INSTRUMENTS.some(i=>i.id===r.instrument)&&(!r.params||validEnvelope(r.params));}
export function accuracy(correct,wrong){return correct+wrong?Math.round(correct/(correct+wrong)*100):0;}
export function loadState(storage){
  const defaults={instrument:'piano',volume:60,attack:10,decay:200,sustain:55,release:400,notes:[...DEFAULT_NOTES],curve:'standard',records:[],favorites:[],presets:[],practiceMinutes:0};
  try { const s=JSON.parse(storage.getItem('touch-piano-v1')||'null');if(!s)return defaults;
    for(const key of ['volume','sustain'])if(Number.isFinite(s[key]))defaults[key]=Math.max(0,Math.min(100,s[key]));
    for(const key of ['attack','decay','release'])if(Number.isFinite(s[key]))defaults[key]=Math.max(1,Math.min(2000,s[key]));
    if(INSTRUMENTS.some(i=>i.id===s.instrument))defaults.instrument=s.instrument;
    if(['soft','standard','firm'].includes(s.curve))defaults.curve=s.curve;
    if(Array.isArray(s.notes)&&s.notes.length===16&&s.notes.every(n=>Number.isInteger(n)&&n>=0&&n<=127))defaults.notes=s.notes;
    defaults.records=Array.isArray(s.records)?s.records.filter(validateRecord).slice(0,30):[];
    defaults.favorites=Array.isArray(s.favorites)?s.favorites.filter(id=>SONGS.some(x=>x.id===id)):[];
    defaults.presets=Array.isArray(s.presets)?s.presets.filter(p=>typeof p.name==='string'&&p.name.length<=80&&validEnvelope(p)).slice(0,12):[];
    defaults.practiceMinutes=Number.isFinite(s.practiceMinutes)?Math.max(0,s.practiceMinutes):0;
  }catch{}return defaults;
}
