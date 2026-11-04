import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {DOMParser} from './app/tests/vendor/xmldom/lib/index.js';
import {ONLINE_SCORES,musicXmlScore} from './app/public/online-scores.js';
const dir=new URL('./app/public/scores/',import.meta.url);await mkdir(dir,{recursive:true});
for(const item of ONLINE_SCORES){
 const xml=await readFile(new URL('./app/tests/fixtures/'+item.file,import.meta.url),'utf8');
 const doc=new DOMParser().parseFromString(xml,'application/xml');
 const rights=Array.from(doc.getElementsByTagName('rights'),x=>x.textContent.trim());
 const score={...musicXmlScore(xml,{Parser:DOMParser,name:item.name}),id:item.id,
   sourceUrl:item.url,sourceSHA256:createHash('sha256').update(xml).digest('hex'),sourceRights:rights,
   attribution:'Practice excerpt from OpenSheetMusicDisplay public MusicXML example, pinned commit 1b9f21aa61da1b3fc6893554c4e2c60e6ac67124. Source rights retained.'};
 await writeFile(new URL(item.id+'.json',dir),JSON.stringify(score,null,2)+'\n');
 console.log(item.id,score.score.length,'events',rights);
}
