export const MAX_SCORE_BYTES=1048576;
export const ONLINE_SCORES=[
  {id:'bach-air',name:'巴赫 · G弦上的咏叹调',file:'JohannSebastianBach_Air.xml',url:'https://raw.githubusercontent.com/opensheetmusicdisplay/opensheetmusicdisplay/1b9f21aa61da1b3fc6893554c4e2c60e6ac67124/test/data/JohannSebastianBach_Air.xml'},
  {id:'mozart-chloe',name:'莫扎特 · 致克洛伊',file:'Mozart_AnChloe.xml',url:'https://raw.githubusercontent.com/opensheetmusicdisplay/opensheetmusicdisplay/1b9f21aa61da1b3fc6893554c4e2c60e6ac67124/test/data/Mozart_AnChloe.xml'},
];
const COMMIT='1b9f21aa61da1b3fc6893554c4e2c60e6ac67124';
export function catalogUrls(item){return ['cdn.jsdmirror.cn','cdn.jsdmirror.com','cdn.jsdelivr.net'].map(host=>`https://${host}/gh/opensheetmusicdisplay/opensheetmusicdisplay@${COMMIT}/test/data/${item.file}`);}
const CATALOG_HASHES={'bach-air':'c9bdaebde9140fee632ea97c6c7f763978c6663f3e5e5b81d468b0193696da37','mozart-chloe':'937e753a4b194aec204d6b52f87f092b19b87c6d52375ef314af2fd3535f5168'};
export async function bundledScore(item,{fetcher=globalThis.fetch}={}){
  const response=await fetcher(new URL(`scores/${item.id}.json`,import.meta.url));
  if(!response.ok)throw Error('内置曲谱读取失败，请更新安装包');
  const value=await response.json();return {...normalizeScore(value),sourceKind:'bundled',bundledAt:'2026-11-02',sourceUrl:item.url,sourceRights:value.sourceRights,sourceSHA256:value.sourceSHA256};
}
export function scoreNetworkMessage(error){
  const text=String(error?.message||error||'');
  if(error?.name==='AbortError')return '下载已取消';
  if(/timed? ?out|timeout|超时/i.test(text))return '曲谱服务器连接超时，可直接使用内置练习片段';
  if(/resolve|unknownhost|name_not_resolved|failed to fetch|network|网络/i.test(text))return '当前网络无法访问曲谱源，可直接使用内置练习片段';
  if(/SSL|certificate|证书/i.test(text))return '曲谱连接的安全证书验证失败，请检查手机日期或更换网络';
  return text||'曲谱下载失败';
}
export async function fetchCatalogScore(item,options={}){
  const errors=[];
  for(const [index,url] of catalogUrls(item).entries()){
    if(options.signal?.aborted)throw new DOMException('已取消','AbortError');
    options.onSource?.(index+1);
    try{return {...await fetchOnlineScore(url,{...options,name:item.name,expectedHash:CATALOG_HASHES[item.id]}),id:item.id,sourceKind:'network'};}
    catch(e){if(options.signal?.aborted)throw new DOMException('已取消','AbortError');errors.push(scoreNetworkMessage(e));}
  }
  throw Error(errors.at(-1)||'曲谱下载失败，可直接使用内置练习片段');
}
export function checkedScoreUrl(input){const url=new URL(input);if(url.protocol!=='https:'||url.username||url.password)throw Error('请输入不带账号密码的HTTPS曲谱地址');return url.href;}
export function normalizeScore(value,defaults={}){
  const s=Array.isArray(value)?{score:value}:value;
  if(!s||!Array.isArray(s.score)||!s.score.length||s.score.length>128)throw Error('曲谱须包含1～128个score事件');
  const score=s.score.map(e=>{
    const note=e.note===null||e.note===255?null:e.note,beats=Number(e.beats);
    if(note!==null&&(!Number.isInteger(note)||note<0||note>127))throw Error('曲谱音符须为MIDI 0～127，休止使用null');
    if(!Number.isFinite(beats)||beats<.25||beats>15.75||Math.abs(beats*4-Math.round(beats*4))>.0001)throw Error('音长须为1/4拍整数倍，最大15.75拍');return {note,beats};
  });
  return {...defaults,id:String(s.id||defaults.id||'download-'+Date.now()).slice(0,100),name:String(s.name||defaults.name||'下载曲谱').slice(0,100),
    bpm:Math.max(40,Math.min(200,Math.round(Number(s.bpm)||80))),score};
}
const children=(el,name)=>Array.from(el.childNodes||[]).filter(n=>n.nodeType===1&&(!name||n.localName===name||n.nodeName===name));
const text=(el,name,fallback='')=>{const n=children(el,name)[0];return n?n.textContent.trim():fallback;};
export function musicXmlScore(xml,{Parser=globalThis.DOMParser,name='下载曲谱',limit=32}={}){
  if(!Parser)throw Error('当前环境不支持MusicXML');
  if(xml.length>MAX_SCORE_BYTES||/<!ENTITY/i.test(xml))throw Error('曲谱过大或包含不支持的实体');
  // Ignore external DTD declarations: score import never fetches entities or scripts.
  const doc=new Parser().parseFromString(xml.replace(/<!DOCTYPE[^>]*>/gi,''),'application/xml');
  if(doc.getElementsByTagName('parsererror').length||doc.documentElement?.localName!=='score-partwise')throw Error('请提供未压缩的MusicXML（score-partwise）或JSON');
  const part=children(doc.documentElement,'part')[0];if(!part)throw Error('曲谱没有可用声部');
  let divisions=1,voice=null,staff=null,transpose=0,quantized=false;const score=[];
  const pitchClass={C:0,D:2,E:4,F:5,G:7,A:9,B:11};
  outer:for(const measure of children(part,'measure')){
    for(const node of children(measure)){
      if(node.localName==='attributes'){
        divisions=Number(text(node,'divisions',String(divisions)));const tr=children(node,'transpose')[0];if(tr)transpose=Number(text(tr,'chromatic','0'))+12*Number(text(tr,'octave-change','0'));
        if(!Number.isFinite(divisions)||divisions<=0)throw Error('MusicXML divisions无效');continue;
      }
      if(node.localName!=='note'||children(node,'grace').length||children(node,'chord').length)continue;
      const v=text(node,'voice','1'),st=text(node,'staff','1');if(voice===null){voice=v;staff=st;}if(v!==voice||st!==staff)continue;
      const raw=Number(text(node,'duration','0'))/divisions;if(!raw)continue;
      const beats=Math.max(.25,Math.round(raw*4)/4);if(Math.abs(raw-beats)>.00001)quantized=true;
      const pitch=children(node,'pitch')[0];let note=null;
      if(pitch){const step=text(pitch,'step'),oct=Number(text(pitch,'octave')),alter=Number(text(pitch,'alter','0'));note=(oct+1)*12+pitchClass[step]+alter+transpose;}
      if(!pitch&&!children(node,'rest').length)throw Error('暂不支持无确定音高的谱表');
      const tieStop=children(node,'tie').some(t=>t.getAttribute('type')==='stop');
      if(tieStop&&score.length&&score.at(-1).note===note&&score.at(-1).beats+beats<=15.75)score.at(-1).beats+=beats;
      else score.push({note,beats});
      if(score.length>=limit)break outer;
    }
  }
  return normalizeScore({name,bpm:80,score},{format:'musicxml',quantized,excerpt:true,description:'第一谱表首个声部的前32事件，作为慢速单旋律练习片段'});
}
export async function fetchOnlineScore(url,{link,fetcher=globalThis.fetch,name='下载曲谱',signal,expectedHash,Parser=globalThis.DOMParser}={}){
  url=checkedScoreUrl(url);let content;
  if(signal?.aborted)throw new DOMException('已取消','AbortError');
  if(link?.native){const r=await link.request('fetchScore',{url});content=r.content;}
  else {
    const controller=new AbortController();let timedOut=false;const abort=()=>controller.abort();signal?.addEventListener('abort',abort,{once:true});if(signal?.aborted)abort();const timer=setTimeout(()=>{timedOut=true;abort();},12000);
    try{const response=await fetcher(url,{signal:controller.signal,credentials:'omit',cache:'no-store'});if(!response.ok)throw Error(`下载失败（HTTP ${response.status}）`);
      if(Number(response.headers.get('content-length'))>MAX_SCORE_BYTES)throw Error('曲谱不能超过1MB');
      const reader=response.body?.getReader();if(reader){const chunks=[];let size=0;while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;if(size>MAX_SCORE_BYTES){await reader.cancel();throw Error('曲谱不能超过1MB');}chunks.push(value);}const bytes=new Uint8Array(size);let i=0;for(const c of chunks){bytes.set(c,i);i+=c.length;}content=new TextDecoder().decode(bytes);}
      else content=await response.text();
    }catch(e){if(timedOut)throw Error('曲谱下载超时');throw e;}finally{clearTimeout(timer);signal?.removeEventListener('abort',abort);}
  }
  if(typeof content!=='string'||new TextEncoder().encode(content).length>MAX_SCORE_BYTES)throw Error('曲谱内容无效或超过1MB');
  if(signal?.aborted)throw new DOMException('已取消','AbortError');
  let sourceSHA256;
  if(expectedHash){
    if(!globalThis.crypto?.subtle)throw Error('请更新Android系统WebView后再进行在线曲谱校验');
    sourceSHA256=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(content))),b=>b.toString(16).padStart(2,'0')).join('');
    if(sourceSHA256!==expectedHash)throw Error('曲谱源内容校验不符，已拒绝使用');
  }
  const score=content.trim().startsWith('<')?musicXmlScore(content,{name,Parser}):normalizeScore(JSON.parse(content),{name});
  return {...score,sourceUrl:url,sourceSHA256,downloadedAt:Date.now()};
}
