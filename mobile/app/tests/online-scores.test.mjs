import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {DOMParser} from './vendor/xmldom/lib/index.js';
import {musicXmlScore,normalizeScore,checkedScoreUrl,fetchOnlineScore,ONLINE_SCORES,bundledScore,fetchCatalogScore,catalogUrls,scoreNetworkMessage} from '../public/online-scores.js';
import {mappingForScore,encodeScore} from '../public/fpga-sync.js';
test('both real downloadable catalog scores produce a valid pressure-matrix excerpt',async()=>{
 for(const item of ONLINE_SCORES){const xml=await readFile(new URL('./fixtures/'+item.file,import.meta.url),'utf8'),score=musicXmlScore(xml,{Parser:DOMParser,name:item.name});assert.equal(score.score.length,32);const mapping=mappingForScore(score);assert.equal(encodeScore(score,mapping).matrix,true);assert.match(item.url,/^https:\/\/raw\.githubusercontent\.com\//);}
});
test('JSON validates note range, rest, length, and HDL 6-bit duration instead of wrapping',()=>{
 const s=normalizeScore({name:'test',bpm:80,score:[{note:48,beats:.25},{note:null,beats:15.75}]});assert.equal(s.score[1].note,null);
 for(const event of [{note:128,beats:1},{note:60,beats:16},{note:60,beats:1/3}])assert.throws(()=>normalizeScore({score:[event]}));assert.throws(()=>normalizeScore({score:Array(129).fill({note:60,beats:1})}));
});
test('MusicXML reads pitch/voice, skips chords, joins ties, keeps rests and transposition',()=>{
 const xml=`<score-partwise><part><measure><attributes><divisions>4</divisions><transpose><chromatic>-2</chromatic></transpose></attributes><note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><tie type="start"/></note><note><chord/><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note><note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><tie type="stop"/></note><note><rest/><duration>2</duration><voice>1</voice></note><note><pitch><step>G</step><octave>3</octave></pitch><duration>8</duration><voice>2</voice></note></measure></part></score-partwise>`;
 assert.deepEqual(musicXmlScore(xml,{Parser:DOMParser}).score,[{note:58,beats:1.5},{note:null,beats:.5}]);assert.throws(()=>musicXmlScore('<!ENTITY x "bad"><score-partwise/>',{Parser:DOMParser}),/实体/);
});
test('download is a real fetch, validates HTTPS and propagates HTTP failure',async()=>{
 let called=false;const s=await fetchOnlineScore('https://example.org/score.json',{fetcher:async()=>{called=true;return new Response(JSON.stringify({name:'remote',score:[{note:60,beats:1}]}));}});assert.equal(called,true);assert.equal(s.name,'remote');assert.ok(s.sourceUrl);assert.ok(s.downloadedAt);
 for(const url of ['http://example.org/a','javascript:alert(1)','https://user:pass@example.org/a'])assert.throws(()=>checkedScoreUrl(url));
 await assert.rejects(fetchOnlineScore('https://example.org/a',{fetcher:async()=>new Response('missing',{status:404})}),/404/);
});
test('Android network bridge and cancellation do not mislabel cached data as a new download',async()=>{
 let requested;const link={native:true,request:async(method,args)=>{requested={method,args};return {content:JSON.stringify({score:[{note:61,beats:1}]})};}};
 const score=await fetchOnlineScore('https://example.org/a',{link});assert.equal(requested.method,'fetchScore');assert.equal(score.score[0].note,61);
 const c=new AbortController();c.abort();await assert.rejects(fetchOnlineScore('https://example.org/a',{link,signal:c.signal}),/取消/);
});

test('bundled excerpts are actual packaged scores, preserve provenance and fit FPGA matrix',async()=>{
 for(const item of ONLINE_SCORES){let local;
  const s=await bundledScore(item,{fetcher:async url=>{local=String(url);return new Response(await readFile(new URL(url),'utf8'));}});
  assert.match(local,/\/scores\//);assert.equal(s.id,item.id);assert.equal(s.sourceKind,'bundled');assert.equal(s.downloadedAt,undefined);assert.equal(s.score.length,32);assert.equal(encodeScore(s,mappingForScore(s)).matrix,true);assert.ok(s.sourceRights);assert.match(s.sourceSHA256,/^[a-f0-9]{64}$/);
 }
});
test('catalog network failure tries alternate host and does not silently use bundled data',async()=>{
 const item=ONLINE_SCORES[0],calls=[],xml=await readFile(new URL('./fixtures/'+item.file,import.meta.url),'utf8');
 const s=await fetchCatalogScore(item,{Parser:DOMParser,fetcher:async url=>{calls.push(url);if(calls.length===1)throw Error('Failed to fetch');return new Response(xml);}});
 assert.deepEqual(calls,catalogUrls(item).slice(0,2));assert.equal(s.sourceKind,'network');assert.equal(s.id,item.id);assert.equal(s.sourceUrl,catalogUrls(item)[1]);assert.match(s.sourceSHA256,/^[a-f0-9]{64}$/);
 await assert.rejects(fetchCatalogScore(item,{fetcher:async()=>{throw Error('network');}}),/网络/);
});
test('mirror content mismatch cannot enter score library',async()=>{
 await assert.rejects(fetchCatalogScore(ONLINE_SCORES[0],{fetcher:async()=>new Response('{"score":[{"note":60,"beats":1}]}')}),/校验不符/);
});
test('cancel before download never starts an Android native request',async()=>{
 const c=new AbortController();c.abort();let calls=0;await assert.rejects(fetchCatalogScore(ONLINE_SCORES[0],{signal:c.signal,link:{native:true,request:async()=>{calls++;}}}),/取消/);assert.equal(calls,0);
});
test('network diagnostics distinguish timeout, network and TLS failures',()=>{
 assert.match(scoreNetworkMessage(Error('timeout')),/超时/);assert.match(scoreNetworkMessage(Error('Unable to resolve host')),/网络/);assert.match(scoreNetworkMessage(Error('SSL certificate')),/证书/);
});
