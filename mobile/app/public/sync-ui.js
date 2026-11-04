import {FpgaSync,DEFAULT_MAPPING,validateMapping,mappingForScore,pcmToWav,FPGA_SAMPLE_RATE} from './fpga-sync.js';
import {ONLINE_SCORES,fetchOnlineScore,fetchCatalogScore,bundledScore,scoreNetworkMessage,normalizeScore} from './online-scores.js';
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const note=n=>['C','C♯','D','D♯','E','F','F♯','G','G♯','A','A♯','B'][n%12]+(Math.floor(n/12)-1);
export async function saveWav(link,bytes,name='FPGA演奏.wav'){
  if(link.native){let raw='';for(let i=0;i<bytes.length;i+=8192)raw+=String.fromCharCode(...bytes.subarray(i,i+8192));await link.request('export',{name,mime:'audio/wav',base64:btoa(raw)});}
  else {const url=URL.createObjectURL(new Blob([bytes],{type:'audio/wav'})),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),30000);}
}
export function createSyncUI({link,state,save,render,toast,header,allOff}){
  let bank=0,selected=0,working=false,message='尚未同步',fraction=0,previewURL=null,selectedDownload=null,networkController=null,confirmedUpload=null;
  const scoreKey=(score,mapping)=>JSON.stringify({score:score?.score,bpm:score?.bpm,mapping});
  const s=()=>state(),busy=()=>working||sync.busy;
  try{validateMapping(s().fpgaNotes);}catch{s().fpgaNotes=[...s().notes,...DEFAULT_MAPPING.slice(16)];}
  s().notes=s().fpgaNotes.slice(0,16);
  s().downloadedScores=Array.isArray(s().downloadedScores)?s().downloadedScores.flatMap(x=>{try{return [normalizeScore(x,x)];}catch{return [];}}).slice(0,10):[];
  const sync=new FpgaSync(link,{onProgress:p=>{message=p.message;fraction=p.progress;update();}});
  const button=(label,action,extra='')=>`<button class="button secondary" data-sync="${action}" ${extra}>${label}</button>`;
  const status=()=>`<div class="sync-status" role="status" aria-live="polite"><span data-sync-message>${esc(message)}</span><progress data-sync-progress max="1" value="${fraction}"></progress><button class="text-button" data-sync="cancel" ${busy()?'':'hidden'}>取消同步</button></div>`;
  const connection=()=>`<p class="footnote">${link.ready?'FPGA已连接 · 写入后等待真实回传确认':'未连接FPGA · 可编辑本地方案，连接后才能写入和读回'}。板端配置保存在运行内存，断电后恢复开机值。</p>`;
  function update(){
    document.querySelectorAll('[data-sync-message]').forEach(e=>e.textContent=message);
    document.querySelectorAll('[data-sync-progress]').forEach(e=>e.value=fraction);
    document.querySelectorAll('[data-sync]').forEach(e=>{if(e.dataset.sync==='cancel'){e.hidden=!busy();return;}e.disabled=busy();});
    const p=link.performanceStatus;
    document.querySelectorAll('[data-capture-status]').forEach(e=>e.textContent=!p?'等待板端状态':p.audioArmed?'等待首个声音触发':p.audioRecording?`正在抓取 · ${(p.audioCount/FPGA_SAMPLE_RATE).toFixed(2)} 秒`:p.audioFull?'缓存已满 · 约2.876秒':`板端缓存 ${(p.audioCount/FPGA_SAMPLE_RATE).toFixed(3)} 秒 · ${p.audioCount} 样本`);
  }
  function adopt(notes){s().fpgaNotes=[...notes];s().notes=notes.slice(0,16);save();}
  async function run(fn,success){if(busy())return;working=true;allOff();render();try{const result=await fn();if(success)success(result);toast(message);}catch(e){message=e.name==='AbortError'?'下载已取消':e.message;toast(message);}finally{working=false;render();}}
  async function readMapping(){return run(()=>sync.readMapping(),notes=>{adopt(notes);message='32槽键位已从FPGA读回';fraction=1;});}
  function mappingView(){const notes=s().fpgaNotes;return `${header('FPGA键位映射','32槽配置 · 前16槽对应A0～A15压力垫',true)}
    <div class="segments"><button data-sync="bank0" class="${bank===0?'active':''}">1～16 · 压力垫</button><button data-sync="bank1" class="${bank===1?'active':''}">17～32 · 扩展声部</button></div>
    <div class="sync-pad-grid">${notes.slice(bank*16,bank*16+16).map((n,j)=>{const i=bank*16+j;return `<button data-sync="slot" data-slot="${i}" class="${i===selected?'chosen':''}"><small>${i<16?'A'+i:'声部 '+(i+1)}</small><strong>${note(n)}</strong><span>${i+1} · MIDI ${n}</span></button>`;}).join('')}</div>
    <div class="sync-card"><label class="note-select">${selected<16?'A'+selected:'声部 '+(selected+1)} 对应音符<select data-sync-note aria-label="FPGA槽位音高">${Array.from({length:128},(_,n)=>`<option value="${n}" ${notes[selected]===n?'selected':''}>${note(n)} · ${n}</option>`).join('')}</select></label>
    ${button('读取FPGA当前键位','read-mapping')}${button('写入32槽并核对','write-mapping')}${button('恢复FPGA默认键位','reset-mapping')}${status()}</div>${connection()}<p class="footnote">A0在左上，逐行至右下A15。读取不会把手机旧方案写入板端；写入及恢复会停止当前跟练、保持音和测试音。</p>`;}
  function onlineView(){const downloaded=s().downloadedScores;const chosen=downloaded.find(x=>x.id===selectedDownload)||downloaded[0];return `${header('在线曲谱','下载到手机，再同步到板端脱机跟练',true)}
    <div class="sync-card"><h3>示例练习 · 离线可用</h3><p class="footnote">每首32事件，不联网也能加入曲库；在线更新可获取原曲谱并提取同样的练习片段。</p>
    ${ONLINE_SCORES.map((x,i)=>`<p><strong>${esc(x.name)}</strong></p>${button('使用内置片段','bundled',`data-catalog="${i}"`)}${button('在线更新','catalog',`data-catalog="${i}"`)}`).join('')}</div>
    <div class="sync-card"><h3>自己的曲谱</h3><label>HTTPS曲谱地址<input id="online-score-url" type="url" placeholder="https://…/score.json 或 .xml" autocomplete="off"></label>${button('从地址下载','download-url')}
    <p class="footnote">支持未压缩MusicXML或JSON：{"name":"曲名","bpm":80,"score":[{"note":60,"beats":1},{"note":null,"beats":0.5}]}。最多128事件。</p></div>
    <div class="sync-card"><h3>我的曲谱 · 离线保留</h3>${downloaded.length?`<label>选择曲谱<select data-sync-score>${downloaded.map(x=>`<option value="${esc(x.id)}" ${chosen?.id===x.id?'selected':''}>${esc(x.name)}</option>`).join('')}</select></label><p class="footnote">来源：${chosen?.sourceKind==='bundled'?'安装包内置练习片段，未进行联网下载':'已保存的网络曲谱'}</p>`:'<p class="footnote">选择上方内置片段，或在线下载自己的曲谱。</p>'}
    ${chosen?`<p>${esc(chosen.name)} · ${chosen.score.length}事件 · ${new Set(chosen.score.filter(e=>e.note!==null).map(e=>e.note)).size}种音高</p><p class="sync-notes">${chosen.score.slice(0,24).map(e=>e.note===null?'休止':note(e.note)).join(' · ')}</p>${button('1. 适配压力垫键位并核对','adapt-score')}${button('2. 上传曲谱并校验','upload-score')}${button('在FPGA开始跟练','start-practice')}${button('暂停／结束板端跟练','stop-practice')}`:''}
    ${status()}</div>${connection()}<p class="footnote">上传成功后可断开蓝牙，在板端跟练页选择“上传曲谱”开始。提示不代弹，用户按压力垫才发声。曲谱和键位暂存于FPGA运行内存，断电后需要重传。</p>`;}
  function captureView(){return `${header('FPGA真实录音','抓取板端DAC输入PCM，不使用手机麦克风',true)}<div class="sync-card"><h3>短片段音频</h3><p data-capture-status>等待板端状态</p><p class="footnote">首个非零声音触发，最长约2.876秒；可录压力垫、屏幕或手机实际控制FPGA产生的声音。</p>
    ${button('待录：下一个声音开始','capture-start')}${button('停止录音','capture-stop')}${button('回传板端录音','capture-download')}${status()}
    <p class="footnote">9600波特率下完整片段需约5～8分钟，请保持App在前台，勿让其他验收软件同时读取录音。取消或失败不会保存不完整文件。</p></div>
    <div class="sync-card"><h3>回传结果</h3>${sync.pcm?`<p>${sync.pcm.length}样本 · ${(sync.pcm.length/FPGA_SAMPLE_RATE).toFixed(3)}秒 · 来源：FPGA PCM</p>${previewURL?`<audio controls src="${previewURL}" aria-label="真实FPGA录音试听"></audio>`:''}${button('保存WAV到手机／电脑','capture-save')}`:'<p class="footnote">完成回传后可试听及保存WAV。WAV重采样为48kHz，保留实际音高与时长。关闭App前请保存文件。</p>'}</div>${connection()}`;}
  async function action(action,element){
    if(action==='cancel'){sync.cancel();networkController?.abort();message='正在取消同步…';update();return;}
    if(busy())return;
    if(action==='bank0'||action==='bank1'){bank=action==='bank1'?1:0;selected=bank*16;render();return;}
    if(action==='slot'){selected=Number(element.dataset.slot);render();return;}
    if(action==='read-mapping')return readMapping();
    if(action==='write-mapping')return run(()=>sync.writeMapping(s().fpgaNotes),notes=>{adopt(notes);message='32槽写入并逐槽读回通过';fraction=1;});
    if(action==='reset-mapping'){
      if(!link.ready){adopt(DEFAULT_MAPPING);message='本地方案已恢复，尚未写入FPGA';render();return;}
      return run(()=>sync.resetMapping(),notes=>{adopt(notes);message='FPGA32槽已恢复默认并读回确认';fraction=1;});
    }
    if(action==='bundled')return run(()=>bundledScore(ONLINE_SCORES[Number(element.dataset.catalog)]),score=>{
      s().downloadedScores=[score,...s().downloadedScores.filter(x=>x.id!==score.id)].slice(0,10);selectedDownload=score.id;save();message='已加入内置练习片段，可以直接同步到FPGA';fraction=1;
    });
    if(action==='catalog'||action==='download-url'){
      const item=action==='catalog'?ONLINE_SCORES[Number(element.dataset.catalog)]:null,url=item?.url||document.querySelector('#online-score-url').value;
      return run(async()=>{networkController=new AbortController();message='正在从网络下载曲谱…';fraction=0;update();
        try{return await (item?fetchCatalogScore(item,{link,signal:networkController.signal,onSource:n=>{message=n===1?'正在连接曲谱源…':'主源不可达，正在尝试备用源…';update();}}):fetchOnlineScore(url,{link,signal:networkController.signal}));}catch(e){if(e.name==='AbortError')throw e;throw Error(scoreNetworkMessage(e));}finally{networkController=null;}},score=>{
        s().downloadedScores=[score,...s().downloadedScores.filter(x=>x.id!==score.id)].slice(0,10);selectedDownload=score.id;save();message='曲谱已从网络下载并保存在手机';fraction=1;
      });
    }
    const chosen=s().downloadedScores.find(x=>x.id===selectedDownload)||s().downloadedScores[0];
    if(action==='adapt-score')return run(()=>sync.writeMapping(mappingForScore(chosen,s().fpgaNotes)),notes=>{adopt(notes);message='曲谱音高已分配至A0～A15，键位读回通过';fraction=1;});
    if(action==='upload-score')return run(()=>sync.uploadScore(chosen,s().fpgaNotes),encoded=>{confirmedUpload={key:scoreKey(chosen,s().fpgaNotes),session:link.session,count:encoded.events.length};});
    if(action==='start-practice')return run(async()=>{
      if(!confirmedUpload||confirmedUpload.session!==link.session||confirmedUpload.key!==scoreKey(chosen,s().fpgaNotes)||!link.performanceStatus?.uploadReady||!link.performanceStatus?.uploadMatrixOK)throw Error('请先完成当前曲谱的键位适配和上传校验，再开始跟练');
      await sync.operation('开始板端跟练',async()=>{await sync.reply(()=>sync.commands([[0x2d,3],[0x2e,1]]),p=>p.type==='performance'&&p.practiceRunning&&p.song===3);sync.update('板端已开始跟练，按亮起的压力垫演奏',1);});});
    if(action==='stop-practice')return run(()=>sync.operation('停止跟练',async()=>{await sync.command(0x2e,0);sync.update('已发送停止跟练',1);}));
    if(action==='capture-start')return run(()=>sync.startCapture());
    if(action==='capture-stop')return run(()=>sync.stopCapture());
    if(action==='capture-download')return run(()=>sync.downloadCapture(),pcm=>{if(previewURL)URL.revokeObjectURL(previewURL);previewURL=URL.createObjectURL(new Blob([pcmToWav(pcm)],{type:'audio/wav'}));});
    if(action==='capture-save')return run(()=>saveWav(link,pcmToWav(sync.pcm)),()=>{message=link.native?'WAV已保存到所选位置':'WAV已交给浏览器下载';});
  }
  function change(e){if(e.target.matches('[data-sync-note]')){if(busy())return;s().fpgaNotes[selected]=+e.target.value;s().notes=s().fpgaNotes.slice(0,16);save();message='本地方案已修改，尚未写入FPGA';render();}if(e.target.matches('[data-sync-score]')){selectedDownload=e.target.value;render();}}
  document.addEventListener('click',e=>{const b=e.target.closest('[data-sync]');if(b){e.preventDefault();void action(b.dataset.sync,b).catch(e=>toast(e.message));}});
  document.addEventListener('change',change);
  return {sync,update,readMapping,mappingView,onlineView,captureView,
    libraryPanel:()=>`<div class="sync-card"><h3>曲谱同步</h3><p>在线下载曲谱，分配压力垫音高，上传后脱机跟练。</p><button class="button secondary" data-route="online-scores">在线曲谱与FPGA同步</button></div>`,
    recordingPanel:()=>`<div class="sync-card"><h3>FPGA音频</h3><p>回传并保存板端真实声音，与下方手机演奏事件分开。</p><button class="button secondary" data-route="fpga-recording">FPGA真实录音 · WAV</button></div>`};
}
