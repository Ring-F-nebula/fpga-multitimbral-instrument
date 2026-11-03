export function command(id,value){return Uint8Array.of(0xf5,id,value,0xf5^id^value);}
export class Parser{
 constructor(){this.b=[];this.errors=0;}
 feed(bytes){this.b.push(...bytes);this.b=this.b.slice(-8192);const out=[];
  while(this.b.length>=3){
   if(this.b[0]!==165||this.b[1]!==90||![4,5,6,7,8].includes(this.b[2])){this.b.shift();continue;}
   const type=this.b[2];let len={4:40,5:22,6:48,8:103}[type];
   if(type===7){if(this.b.length<8)break;const n=this.b[6]|this.b[7]<<8;if(n<1||n>256){this.b.shift();continue;}len=9+2*n;}
   if(this.b.length<len)break;
   const f=this.b.slice(0,len),crc=f.slice(2,-1).reduce((a,b)=>a^b,0);
   if(crc!==f[len-1]||(type!==4&&f[3]!==0x66)){this.errors++;this.b.shift();continue;}
   this.b.splice(0,len);const u16=i=>f[i]|f[i+1]<<8,u24=i=>f[i]|f[i+1]<<8|f[i+2]<<16;
   if(type===8)out.push({type:'wax',flags:f[4],ready:!!(f[4]&1),calibrating:!!(f[4]&2),noisy:!!(f[4]&4),enabled:!!(f[4]&8),continuous:!!(f[4]&16),configured:!!(f[4]&32),online:!!(f[4]&64),model:f[5],good:u16(6),bad:u16(8),keys:u16(10),on:u16(12),off:u16(14),full:u24(16),peak:u24(19),raw:Array.from({length:16},(_,i)=>u24(22+i*3)),gains:Array.from({length:16},(_,i)=>u16(70+i*2))});
   if(type===6)out.push({type:'performance',keys:(f[4]|f[5]<<8|f[6]<<16|f[7]<<24)>>>0});
  }return out;
 }
}
