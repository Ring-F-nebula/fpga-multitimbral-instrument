import {buildTimeline,RhythmRun,HIT_WINDOW,calibrationResult} from './rhythm.js';
import {noteName,duration,DEFAULT_NOTES} from './core.js';
import {icon} from './visuals.js';

export function createRhythmFeature(host) {
  const $=s=>document.querySelector(s);
  const preferences={mode:'rhythm',bpm:80,countin:true,metronome:true,continueOnError:true,offset:0,calibrated:false};
  try { const p=JSON.parse(localStorage.getItem('touch-rhythm-v1')||'null');
    if(p){for(const k of ['countin','metronome','continueOnError','calibrated'])if(typeof p[k]==='boolean')preferences[k]=p[k];
      if(Number.isFinite(p.offset))preferences.offset=Math.max(-250,Math.min(250,p.offset));}
  }catch{}
  let session=null,lastReport=null,range=null,raf=0,timer=0,clicks=[],cal=null,lastSong=null,starting=false;
  const save=()=>{try{localStorage.setItem('touch-rhythm-v1',JSON.stringify(preferences));}catch{host.toast('无法保存节奏设置');}};
  const bpm=()=>preferences.bpm,beatMs=()=>60000/bpm();
  const signed=n=>(n>0?'+':'')+Math.round(n);
  const persistAndRender=()=>{save();host.render();};
  const action=(label,name,style='primary')=>`<button class="button ${style}" data-rhythm="${name}">${label}</button>`;
  const toggle=(label,key,symbol)=>`<button class="rh-setting" data-rhythm="toggle-${key}" role="switch" aria-checked="${preferences[key]}" aria-label="${label}">${icon(symbol,20)}<span>${label}</span><i class="rh-switch ${preferences[key]?'on':''}"></i></button>`;
  const head=(title,extra='')=>`<header class="rh-header"><button data-rhythm="back" class="icon-button" aria-label="返回">${icon('back',22)}</button><h1>${title}</h1>${extra}</header>`;
  const songCard=(detail='')=>`<div class="rh-song-card"><div>${icon('music',29)}</div><span><strong>${host.song().name}</strong><small>${detail||`${host.state().instrument==='guzheng'?'古筝':'钢琴'} · ${host.song().key} · 4/4`}</small></span></div>`;
  function openSetup(){const s=host.song();if(lastSong!==s.id){preferences.bpm=s.bpm;lastSong=s.id;}range=null;host.go('rhythm-setup');}
  function setupView(){return `${head('练习设置')}${songCard()}<div class="segments rh-modes"><button data-rhythm="mode-wait" class="${preferences.mode==='wait'?'active':''}">等音练习</button><button data-rhythm="mode-rhythm" class="${preferences.mode==='rhythm'?'active':''}">节奏跟练</button></div>${preferences.mode==='rhythm'?`
    <section class="rh-speed"><h3>${icon('music',20)}练习速度</h3><div><strong id="rh-bpm">${bpm()}</strong> BPM</div><p id="rh-rate">原速 ${host.song().bpm} BPM · ${(bpm()/host.song().bpm).toFixed(2)}×</p><input id="rh-tempo" aria-label="练习速度" type="range" min="40" max="160" step="1" value="${bpm()}"><div class="rh-speed-pills"><button data-rhythm="slow">慢速 0.75×</button><button data-rhythm="original">原速</button><label>自定义 <input id="rh-tempo-number" aria-label="自定义 BPM" type="number" min="40" max="160" value="${bpm()}"></label></div></section>
    <div class="rh-group">${toggle('四拍倒数','countin','clock')}${toggle('节拍器','metronome','wave')}${toggle('错音继续','continueOnError','play')}<button class="rh-setting" data-rhythm="calibrate">${icon('sliders',20)}<span>输入延迟校准</span><small>${preferences.calibrated?signed(preferences.offset)+' ms':'未校准'}</small>${icon('right',16)}</button></div>
    <section class="rh-guide"><h3>${icon('info',18)}怎么玩</h3><div><div><span class="rh-guide-note"></span><i>↓</i><b></b><p>音块到线，按对应触点</p></div><div><span class="rh-guide-note long"></span><i>↓</i><b></b><p>长条音符，按住直到结束</p></div></div></section>
    ${action(icon('play',18)+'开始跟练','start')}<p class="preview-note">先放慢，再弹准 · 错音继续关闭时会暂停纠错</p>`:
    `<div class="rh-wait-guide">${icon('music',46)}<h2>先把音符弹对</h2><p>亮起哪个触点，就按哪个。<br>弹对后再继续，不限制按键时间。</p></div>${action(icon('play',18)+'开始等音练习','start-wait')}`}`;}

  function gameView(){return `${head('节奏跟练',`<button class="rh-pause" data-rhythm="pause" aria-label="暂停练习">${icon('pause',19)}</button>`)}
    <div class="rh-now">${icon('music',23)}<span><strong>${host.song().name}</strong><small>${bpm()} BPM · ${(bpm()/host.song().bpm).toFixed(2)}×${range?` · 第 ${range.from}–${range.to} 小节`:''}</small></span></div>
    <div class="rh-time"><div><i id="rh-progress"></i></div><span id="rh-time">00:00 / ${duration(session.run.totalMs)}</span></div>
    <div class="rh-live-stats"><span>连击 <strong id="rh-combo">0</strong></span><span>节拍准确率 <strong id="rh-accuracy">—</strong></span></div>
    <div class="rh-field" id="rh-field" aria-label="四列下落音符轨道"><div class="rh-lanes">${[1,2,3,4].map(i=>`<div><small>${i}</small></div>`).join('')}</div><span class="rh-fall-arrow">↓</span><div id="rh-notes"></div><div class="rh-judge-line"><span>判定线</span></div><div id="rh-feedback" role="status" aria-live="polite"></div><div id="rh-countdown"></div></div>
    <p class="rh-pad-hint">看音名和编号，按对应触点 <span id="rh-beat-dots">${[0,1,2,3].map(()=>'<i></i>').join('')}</span></p>
    ${host.pads({drums:false})}<div class="rh-game-actions">${action(icon('repeat',17)+'重练本段','restart','secondary')}${action(icon('stop',16)+'结束练习','end','secondary')}</div>
    ${session.paused?`<div class="rh-pause-overlay"><div>${icon('pause',30)}<h2>${session.reason||'练习已暂停'}</h2><p>继续时先倒数四拍，重练当前小节。<br>之前小节的成绩会保留。</p>${action('继续练习','resume')}${action('结束并查看结果','end','secondary')}</div></div>`:''}`;}

  function reportView(){const r=lastReport;if(!r)return setupView();const totalPress=r.early+r.perfect+r.late;
    return `${head('练习结果')}${songCard(`${r.bpm} BPM · ${r.complete?'已完成':'提前结束'} · ${r.judged} / ${r.total} 音符`)}<div class="rh-result-hero"><div class="rh-ring" style="--score:${r.timing}%"><div><strong>${r.judged?r.timing:'—'}${r.judged?'<small>%</small>':''}</strong><span>节拍准确率</span></div></div><span>${!r.judged?'还没开始，准备再试试':r.timing>=85?'节奏越来越稳了':r.timing>=60?'慢一点，更稳一点':'先跟着节拍，找到感觉'}</span></div>
    <div class="rh-result-stats"><div>${icon('music',23)}<span>音符正确率<strong>${r.judged||r.wrong?r.pitch+'%':'—'}</strong></span></div><div>${icon('wave',23)}<span>最长连击<strong>${r.maxCombo}</strong></span></div></div>
    <section class="rh-timing-card"><h3>${icon('clock',21)}按键时机<small>命中 ${totalPress} 个音符</small></h3>${[['偏早',r.early,'early'],['准确',r.perfect,'perfect'],['偏晚',r.late,'late']].map(([name,n,kind])=>`<div class="rh-timing-row ${kind}"><span>${name}</span><div><i style="width:${totalPress?n/totalPress*100:0}%"></i></div><b>${n}</b></div>`).join('')}<p>漏按 <b>${r.miss}</b> 次 · 额外按键 <b>${r.wrong}</b> 次</p>${r.holds?`<p>长音完成 <b>${r.held} / ${r.holds}</b></p>`:''}</section>
    <div class="rh-result-tip">${icon('info',21)}<div><strong>${r.weak?'再巩固一下这一段':'继续保持自己的节奏'}</strong><p>${r.weak?`第 ${r.weak.from}–${r.weak.to} 小节，建议用本次速度的 0.75× 再练一次。`:r.judged?'可以回到设置，逐步提高速度。':'开始后，让第一个音块中心落到线上再按。'}</p></div></div>
    ${r.weak?action(icon('repeat',17)+'重练薄弱段落','retry-weak'):''}${action('再练一遍','retry',r.weak?'secondary':'primary')}<button class="rh-text-link" data-route="library">返回曲库</button><p class="rh-result-note">${r.complete?'已完成':'提前结束'} · 已判定 ${r.judged} / ${r.total} 音符<br>节拍准确率 = 准确 ÷ 已判定音符（含漏按）<br>准确 ±90 ms · 可命中 ±220 ms · 长音另计</p>`;}

  function clickAt(wall,accent=false){const c=host.audio.ctx;if(!c||c.state!=='running')return;
    const at=c.currentTime+Math.max(0,(wall-performance.now())/1000),o=c.createOscillator(),g=c.createGain();
    o.frequency.value=accent?1200:850;g.gain.setValueAtTime(.001,at);g.gain.linearRampToValueAtTime(.3,at+.003);g.gain.exponentialRampToValueAtTime(.001,at+.055);o.connect(g);g.connect(host.audio.master);o.start(at);o.stop(at+.07);clicks.push(o);o.onended=()=>{g.disconnect();clicks=clicks.filter(x=>x!==o);};
  }
  function stopClicks(){for(const c of clicks){try{c.stop();}catch{}}clicks=[];clearInterval(timer);timer=0;}
  function elapsed(now=performance.now()){return session?(session.paused?session.pauseAt:now-session.origin):0;}
  function corrected(now=performance.now()){return elapsed(now)-preferences.offset;}
  function runTicker(){cancelAnimationFrame(raf);stopClicks();
    timer=setInterval(()=>{if(!session||session.paused)return;const now=performance.now();while(session.nextTick<=session.run.totalMs){const wall=session.origin+session.nextTick;if(wall>now+100)break;
      const countIn=session.nextTick<session.resumeAt;if(wall>now-40&&(preferences.metronome||countIn&&(preferences.countin||session.forceCountin)))clickAt(wall,Math.round(session.nextTick/beatMs())%4===0);
      session.nextTick+=beatMs();}},25);
    raf=requestAnimationFrame(frame);
  }
  async function start(keepRange=false){
    if(starting)return;starting=true;
    cancelAnimationFrame(raf);stopClicks();session=null;host.allOff();
    try{await host.audio.init();}catch{starting=false;host.toast('无法启动声音，请重试');return;}
    if(!keepRange)range=null;
    const s=host.state();if(s.instrument==='drums')s.instrument='piano';
    if(host.song().score.some(n=>!s.notes.includes(n.note))){s.notes=[...DEFAULT_NOTES];host.toast('已恢复半音排列，以覆盖曲目音符');}
    host.save();host.audio.setVolume(s.volume);
    const lead=preferences.countin?beatMs()*4:2000;
    session={run:new RhythmRun(buildTimeline(host.song().score,bpm(),s.notes,range)),origin:performance.now()+lead,paused:false,resumeAt:0,forceCountin:false,nextTick:-lead,startedAt:performance.now(),pauseTotal:0,reason:'',nodes:new Map(),lastFeedback:null};
    host.go('rhythm');runTicker();starting=false;
  }
  function frame(now){if(!session||session.paused||host.page()!=='rhythm')return;
    const t=elapsed(now),judgedTime=t-preferences.offset;
    if(t>=session.resumeAt-HIT_WINDOW)session.run.advance(judgedTime);
    paint(t);
    const feedback=session.run.last;
    if(!preferences.continueOnError&&feedback&&feedback!==session.lastFeedback&&['miss','wrong','broken'].includes(feedback.kind)){
      session.lastFeedback=feedback;pause(feedback.kind==='wrong'?'音符还没对上':'停一下，找准这一拍');return;
    }
    session.lastFeedback=feedback;
    if(t>session.run.totalMs+HIT_WINDOW+Math.max(0,preferences.offset)+100){finish(true);return;}
    raf=requestAnimationFrame(frame);
  }
  function paint(t){const field=$('#rh-field');if(!field||!session)return;
    const line=field.clientHeight-32,travel=beatMs()*4,scale=line/travel,run=session.run;
    const layer=$('#rh-notes');
    for(const n of run.notes){
      const held=n.status==='holding',head=line-(n.on-t)*scale,tail=line-(n.end-t)*scale;
      const visible=['pending','holding'].includes(n.status)&&head>=-30&&(n.hold?tail:head)<line+24;
      let el=session.nodes.get(n.id);
      if(!visible){if(el){el.remove();session.nodes.delete(n.id);}continue;}
      if(!el||!el.isConnected){el=document.createElement('div');el.className=`rh-falling tone-${Math.floor(n.pad/4)} ${n.hold?'long':''}`;el.dataset.noteId=n.id;el.setAttribute('aria-label',`${noteName(n.midi)}，触点 ${n.pad+1}${n.hold?'，长音':''}`);el.innerHTML=`<span class="rh-note-head"><b>${noteName(n.midi)}</b><small>${String(n.pad+1).padStart(2,'0')}${n.hold?' · 按住':''}</small></span>`;layer.appendChild(el);session.nodes.set(n.id,el);}
      const top=n.hold?tail-18:head-18,height=n.hold?Math.max(36,(held?line:head)-tail+36):36;
      el.style.left=`calc(${n.pad%4*25}% + 8px)`;el.style.top=top+'px';el.style.height=height+'px';el.classList.toggle('held',held);
    }
    const r=run.result();$('#rh-combo').textContent=run.combo;$('#rh-accuracy').textContent=r.judged?r.timing+'%':'—';
    $('#rh-progress').style.width=Math.min(100,Math.max(0,t)/run.totalMs*100)+'%';$('#rh-time').textContent=duration(Math.max(0,t))+' / '+duration(run.totalMs);
    const count=$('#rh-countdown'),counting=t<session.resumeAt-HIT_WINDOW;
    const numbered=preferences.countin||session.forceCountin;
    count.hidden=!counting;count.innerHTML=counting?`<span>${session.forceCountin?'重新找到节拍':'准备好了吗'}</span><strong>${numbered?Math.max(1,Math.ceil((session.resumeAt-t)/beatMs())):'准备'}</strong><small>${numbered?'跟着四拍，准备落指':'音块到线时开始'}</small>`:'';
    const f=run.last,feedback=$('#rh-feedback');
    if(f&&t-preferences.offset-f.at<1000){const labels={perfect:'准确',early:'偏早',late:'偏晚',wrong:'音符或时机不对',miss:'漏按',broken:'长音松早了',held:'长音完成'};const label=labels[f.kind]+(f.delta!==null?' · '+signed(f.delta)+' ms':'');if(feedback.textContent!==label)feedback.textContent=label;feedback.className=['early','late','wrong','miss','broken'].includes(f.kind)?'rh-warn':'';}else if(feedback.textContent)feedback.textContent='';
    const dots=[...document.querySelectorAll('#rh-beat-dots i')],beat=((Math.floor(t/beatMs())%4)+4)%4;dots.forEach((d,i)=>d.classList.toggle('active',i===beat));
  }
  function press(midi,now){if(!session||session.paused||elapsed(now)<session.resumeAt-HIT_WINDOW)return;session.run.press(midi,corrected(now));paint(elapsed(now));}
  function release(midi,now){if(!session||session.paused)return;session.run.release(midi,corrected(now));}
  function pause(reason='练习已暂停'){
    if(cal?.running){cal.running=false;cancelAnimationFrame(raf);stopClicks();host.render();if($('#rh-cal-status'))$('#rh-cal-status').textContent='校准已中断，请重新开始';}
    if(!session||session.paused)return;session.pauseAt=elapsed();session.pauseWall=performance.now();session.paused=true;session.reason=reason;cancelAnimationFrame(raf);stopClicks();host.allOff();host.render();paint(session.pauseAt);
  }
  function resume(){if(!session?.paused)return;let from=Math.floor(Math.max(0,session.pauseAt)/(beatMs()*4))*beatMs()*4;
    const crossing=session.run.notes.find(n=>n.hold&&n.on<from&&n.end>from);if(crossing)from=Math.floor(crossing.on/(beatMs()*4))*beatMs()*4;
    session.run.rewind(from);session.resumeAt=from;session.forceCountin=true;session.origin=performance.now()-from+4*beatMs();session.nextTick=from-4*beatMs();session.pauseTotal+=performance.now()-session.pauseWall;session.paused=false;session.nodes=new Map();session.lastFeedback=null;host.render();runTicker();
  }
  function finish(complete=false){if(!session)return;const t=elapsed();session.run.advance(t-preferences.offset);
    lastReport={...session.run.result(),complete,bpm:bpm(),range:range?{...range}:null};
    const activeMs=Math.max(0,performance.now()-session.startedAt-session.pauseTotal-(session.paused?performance.now()-session.pauseWall:0));host.state().practiceMinutes+=activeMs/60000;host.save();
    cancelAnimationFrame(raf);stopClicks();session=null;host.allOff();host.go('rhythm-report');
  }
  function leave(next){if(next!=='rhythm'&&session){cancelAnimationFrame(raf);stopClicks();session=null;}if(next!=='rhythm-calibrate'&&cal){stopClicks();cancelAnimationFrame(raf);cal=null;}}

  function calibrationView(){return `${head('输入延迟校准')}<div class="rh-cal-intro"><h2>听到节拍，就轻触</h2><p>前四拍先听，后八拍跟着按。<br>也可以用空格键。</p></div><div class="rh-cal-orbit" id="rh-cal-orbit">${icon('wave',48)}</div><p class="center-caption" id="rh-cal-status">使用平时演奏的耳机或扬声器</p><button class="rh-tap" data-rhythm="cal-tap" ${cal?.running?'':'disabled'}>轻触打拍</button>${action(cal?.running?'重新开始':'开始校准','cal-start','secondary')}<div class="rh-cal-current"><span>当前补偿</span><strong>${preferences.calibrated?signed(preferences.offset)+' ms':'未校准'}</strong><button data-rhythm="cal-reset">重置</button></div><p class="rh-result-note">估计的是你的按拍偏移，包含音频与操作延迟。<br>不是蓝牙硬件延迟测量；更换设备后请重新校准。</p>`;}
  async function startCalibration(){stopClicks();cancelAnimationFrame(raf);try{await host.audio.init();}catch{host.toast('无法启动音频');return;}host.audio.setVolume(host.state().volume);
    cal={running:true,start:performance.now()+900,next:0,samples:[],used:new Set()};host.render();
    timer=setInterval(()=>{if(!cal?.running)return;const now=performance.now();while(cal.next<12&&cal.start+cal.next*600<now+100){clickAt(cal.start+cal.next*600,cal.next%4===0);cal.next++;}},25);
    const tick=now=>{if(!cal?.running)return;const t=(now-cal.start)/600,idx=Math.floor(t),phase=t-idx;
      $('#rh-cal-orbit')?.classList.toggle('pulse',idx>=0&&phase<.15);
      if($('#rh-cal-status'))$('#rh-cal-status').textContent=idx<0?'准备听节拍':idx<4?`先听四拍 · ${idx+1} / 4`:`跟着轻触 · 已采集 ${cal.samples.length} / 8`;
      if(t>12){const result=calibrationResult(cal.samples);cal.running=false;stopClicks();host.render();$('#rh-cal-status').textContent=result===null?'本次节拍不够稳定，请重新校准':`本次偏移 ${signed(result)} ms · 已保存`;if(result!==null){preferences.offset=result;preferences.calibrated=true;save();$('.rh-cal-current strong').textContent=signed(result)+' ms';}return;}
      raf=requestAnimationFrame(tick);
    };raf=requestAnimationFrame(tick);
  }
  function tapCalibration(){if(!cal?.running)return;const now=performance.now(),i=Math.round((now-cal.start)/600),delta=now-(cal.start+i*600);
    if(i<4||i>11||cal.used.has(i)||Math.abs(delta)>280)return;cal.used.add(i);cal.samples.push(delta);$('#rh-cal-status').textContent=`已采集 ${cal.samples.length} / 8`;
  }
  async function actionHandler(name){
    if(name.startsWith('toggle-')){const k=name.slice(7);preferences[k]=!preferences[k];persistAndRender();return;}
    switch(name){
      case 'setup':openSetup();break;
      case 'mode-wait':preferences.mode='wait';host.render();break;
      case 'mode-rhythm':preferences.mode='rhythm';host.render();break;
      case 'slow':preferences.bpm=Math.max(40,Math.round(host.song().bpm*.75));host.render();break;
      case 'original':preferences.bpm=host.song().bpm;host.render();break;
      case 'start':await start();break;
      case 'start-wait':host.startWait();break;
      case 'pause':pause();break;
      case 'resume':resume();break;
      case 'end':finish(false);break;
      case 'restart':await start(true);break;
      case 'retry':range=lastReport.range;preferences.bpm=lastReport.bpm;await start(true);break;
      case 'retry-weak':range=lastReport.weak;preferences.bpm=Math.max(40,Math.round(lastReport.bpm*.75));await start(true);break;
      case 'calibrate':host.go('rhythm-calibrate');break;
      case 'cal-start':await startCalibration();break;
      case 'cal-tap':tapCalibration();break;
      case 'cal-reset':preferences.offset=0;preferences.calibrated=false;save();stopClicks();cancelAnimationFrame(raf);cal=null;host.render();break;
      case 'back':if(host.page()==='rhythm')pause('要离开练习吗？');else host.go(host.page()==='rhythm-calibrate'?'rhythm-setup':host.page()==='rhythm-report'?'library':'song');break;
    }
  }
  function input(t){if(!['rh-tempo','rh-tempo-number'].includes(t.id))return false;
    if(t.value==='')return true;preferences.bpm=Math.max(40,Math.min(160,Math.round(+t.value)||80));
    $('#rh-bpm').textContent=bpm();$('#rh-rate').textContent=`原速 ${host.song().bpm} BPM · ${(bpm()/host.song().bpm).toFixed(2)}×`;
    if(t.id==='rh-tempo')$('#rh-tempo-number').value=bpm();else $('#rh-tempo').value=bpm();return true;
  }
  return {openSetup,setupView,gameView,reportView,calibrationView,action:actionHandler,input,press,release,pause,leave,tapCalibration,
    canPlay:()=>!!session&&!session.paused&&elapsed()>=session.resumeAt-HIT_WINDOW,
    running:()=>!!session,paused:()=>!!session?.paused,
    afterRender:()=>{if(session){session.nodes=new Map();paint(elapsed());}}};
}
