import {SERIAL_PORT_UUID,describeSppDevice} from './spp-devices.js';
import {decodePerformance} from './fpga-sync.js';
export const SPP_UUID=SERIAL_PORT_UUID;
export const ENVELOPE_MS=[1,2,5,10,20,50,100,200,500,1000];
const wait=ms=>new Promise(r=>setTimeout(r,ms));
export function configPacket(id,value){return Uint8Array.of(0xf5,id,value,0xf5^id^value);}
export function keysPacket(mask){const lo=mask&255,hi=(mask>>8)&255;return Uint8Array.of(0xf6,lo,hi,0xf6^lo^hi);}
export function keys32Packet(mask){const b=[mask&255,(mask>>>8)&255,(mask>>>16)&255,(mask>>>24)&255];return Uint8Array.of(0xf7,...b,b.reduce((a,n)=>a^n,0xf7));}
export function quantizeParameters(s){
  const index=v=>ENVELOPE_MS.reduce((a,x,i)=>Math.abs(x-v)<Math.abs(ENVELOPE_MS[a]-v)?i:a,0);
  return {attack:index(s.attack),decay:index(s.decay),sustain:Math.round(s.sustain*255/100),release:index(s.release),volume:Math.round(s.volume*15/100)};
}
export class StatusParser {
  constructor(){this.buffer=[];}
  feed(bytes){this.buffer.push(...bytes);const out=[];
    while(this.buffer.length>=3){
      if(this.buffer[0]!==0xa5||this.buffer[1]!==0x5a||![4,5,6,7,8].includes(this.buffer[2])){this.buffer.shift();continue;}
      if(this.buffer[2]===7||this.buffer[2]===8){
        const version=this.buffer[2];if(this.buffer.length<8)break;
        const block=this.buffer[4]|this.buffer[5]<<8,count=this.buffer[6]|this.buffer[7]<<8;
        if(version===7&&(block>511||count<1||count>256)){this.buffer.shift();continue;}
        const length=version===7?9+count*2:103;if(this.buffer.length<length)break;
        const f=this.buffer.slice(0,length);if(f.slice(2,-1).reduce((a,b)=>a^b,0)!==f.at(-1)){this.buffer.shift();continue;}
        if(version===7){const samples=new Int16Array(count);for(let i=0;i<count;i++){const n=f[8+i*2]|f[9+i*2]<<8;samples[i]=n>32767?n-65536:n;}out.push({type:'pcm',build:f[3],block,samples});}
        else out.push({type:'pressure',build:f[3]});
        this.buffer.splice(0,length);continue;
      }
      if(this.buffer[2]===6){
        if(this.buffer.length<48)break;
        const f=this.buffer.slice(0,48);if(f.slice(2,47).reduce((a,b)=>a^b,0)!==f[47]){this.buffer.shift();continue;}
        const p=f.slice(4,46),instrument=((p[27]>>>7)|(p[28]<<1))&3;
        out.push({type:'performance',build:f[3],payload:p,...decodePerformance(p),instrument,guitar:!!(p[28]&32)});this.buffer.splice(0,48);continue;
      }
      if(this.buffer[2]===5){
        if(this.buffer.length<22)break;
        const f=this.buffer.slice(0,22);if(f.slice(2,21).reduce((a,b)=>a^b,0)!==f[21]){this.buffer.shift();continue;}
        out.push({type:'effects',build:f[3],revision:f[4],values:f.slice(5,21)});this.buffer.splice(0,22);continue;
      }
      if(this.buffer.length<40)break;
      const f=this.buffer.slice(0,40);if(f.slice(2,39).reduce((a,b)=>a^b,0)!==f[39]){this.buffer.shift();continue;}
      const u=i=>f[i]|f[i+1]<<8;
      out.push({build:f[30],auto:!!(f[3]&1),clear:!!(f[3]&2),trained:!!(f[3]&8),rxCount:u(4),keys:u(7),liveKeys:u(11),volume:f[15],bitClocks:u(16),peak:u(20),envelopes:u(23),attack:f[31],decay:f[32],sustain:f[33],release:f[34],paramCount:f[38]});
      this.buffer.splice(0,40);
    }return out;
  }
}
export class PianoLink {
  constructor({onChange=()=>{},onStatus=()=>{},onError=()=>{},timing={}}={}){
    Object.assign(this,{onChange,onStatus,onError});this.connected=false;this.ready=false;this.connecting=false;this.syncing=false;
    this.status=null;this.performanceStatus=null;this.wideMask=null;this.voices=new Map();this.tail=Promise.resolve();this.parser=new StatusParser();this.requests=new Map();this.requestId=0;this.generation=0;
    this.frameListeners=new Set();this.slotNotes=null;this.mappingRequired=false;this.transferBusy=false;
    this.timing={settle:650,afterTraining:180,handshake:6000,poll:40,heartbeat:200,stale:3500,...timing};
    this.session='';this.phase='未连接';this.problem='';this.logs=[];this.rxBytes=0;this.validFrames=0;this.txBytes=0;this.rxSample=[];this.deviceName='';this.deviceAddress='';this.deviceInfo=null;
    globalThis.PianoNativeResult=(id,result)=>{const p=this.requests.get(id);if(!p)return;this.requests.delete(id);clearTimeout(p.timer);
      if(result.error){const e=Error(result.error);e.code=result.code;e.detail=result.detail;p.reject(e);}else p.resolve(result);};
    globalThis.PianoNativeEvent=(type,data)=>this.nativeEvent(type,data);
  }
  get native(){return !!globalThis.PianoAndroid;}
  get supported(){return this.native||!!globalThis.navigator?.serial;}
  trace(code,message){this.logs.push({at:new Date().toISOString(),code,message});this.logs=this.logs.slice(-80);}
  notify(){this.onChange();}
  nativeEvent(type,data){
    if(!data||data.session!==this.session||!this.session)return; // Late reader events cannot close a newer session.
    if(type==='data')this.receive(data.bytes);
    else if(type==='progress'){this.phase=data.message;this.trace(data.code,data.message);this.notify();}
    else if(type==='disconnected'){const e=Error(data.message||'蓝牙串口已断开');e.code=data.code||'SPP_READ_CLOSED';e.detail=data.detail;this.fail(e);}
    else if(type==='paused')this.allOff();
  }
  request(method,args={}){const id=String(++this.requestId);return new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>{this.requests.delete(id);const e=Error(method==='connect'?'蓝牙串口建立超时，请确认模块空闲并重新配对':'操作超时，请重试');e.code='NATIVE_TIMEOUT';reject(e);},method==='connect'?45000:method==='fetchScore'?30000:method==='export'?180000:5000);
    this.requests.set(id,{resolve,reject,timer});try{globalThis.PianoAndroid.request(id,method,JSON.stringify(args));}catch(e){clearTimeout(timer);this.requests.delete(id);reject(e);}
  });}
  async devices(){if(!this.native)return [];return (await this.request('devices')).devices;}
  async collectDiagnostics(){
    if(this.native){try{const result=await this.request('diagnostics');this.nativeDiagnostics=result.native||null;this.diagnosticsError=null;}
      catch(e){this.diagnosticsError=e.message;}}
    return this.diagnostics();
  }
  async connect(address,settings,{compatibility=false,strategy=compatibility?'compatibility':'auto',device=null}={}){
    if(!['auto','standard','compatibility'].includes(strategy))throw Error('不支持的蓝牙连接方式');
    if(device&&!describeSppDevice(device).selectable)throw Error('这个设备只有 BLE，不能用经典蓝牙 SPP 连接');
    if(this.closingPromise)await this.closingPromise;
    if(this.connected||this.connecting)throw Error('连接操作尚未结束，请稍候');
    this.connecting=true;this.ready=false;this.problem='';this.phase='正在建立蓝牙串口…';
    const epoch=++this.generation;this.session=Date.now().toString(36)+':'+epoch;
    this.parser=new StatusParser();this.tail=Promise.resolve();this.status=null;this.fxStatus=null;this.performanceStatus=null;this.wideMask=null;this.expected=null;this.rxBytes=0;this.txBytes=0;this.validFrames=0;this.rxSample=[];this.slotNotes=null;this.mappingRequired=false;
    this.deviceName=device?.name||'';this.deviceAddress=address||'';this.deviceInfo=device;
    this.trace('CONNECT_START',{auto:'标准 SPP 优先，失败后尝试一次兼容连接',standard:'用户选择仅标准连接',compatibility:'用户选择仅兼容连接'}[strategy]);this.notify();
    try{
      if(this.native){const result=await this.request('connect',{address,session:this.session,compatibility:strategy==='compatibility',strategy});this.mode=result.mode||'SPP';
        this.deviceName=result.deviceName||this.deviceName;this.deviceAddress=result.address||this.deviceAddress;
        this.deviceInfo={name:this.deviceName,address:this.deviceAddress,type:result.deviceType,uuids:result.uuids};}
      else {if(!this.supported)throw Error('请安装安卓 APK，或使用支持蓝牙串口的 Chrome');
        this.port=await navigator.serial.requestPort({allowedBluetoothServiceClassIds:[SPP_UUID]});
        await this.port.open({baudRate:9600,dataBits:8,stopBits:1,parity:'none',flowControl:'none'});
        this.writer=this.port.writable.getWriter();this.reader=this.port.readable.getReader();this.mode='Web Serial';
      }
      if(epoch!==this.generation)throw Error('连接已取消');
      this.connected=true;this.voices.clear();this.phase='蓝牙串口已连接，等待模块稳定';this.trace('SPP_CONNECTED',this.mode);this.notify();
      if(!this.native)this.readTask=this.readLoop(epoch);
      this.timer=setInterval(()=>this.checkHealth(),this.timing.heartbeat);
      return await this.synchronize(settings);
    }catch(e){if(epoch===this.generation){this.trace(e.code||'CONNECT_FAILED',e.detail||e.message);this.problem=e.message;await this.disconnect();}throw e;}
    finally{if(epoch===this.generation){this.connecting=false;this.notify();}}
  }
  async synchronize(settings){
    if(!this.connected||this.syncing)return false;
    const epoch=this.generation;this.syncing=true;this.ready=false;this.problem='';this.phase='蓝牙已连接，正在确认 FPGA…';this.voices.clear();this.status=null;this.notify();
    try{
      await wait(this.timing.settle);this.checkSession(epoch);
      // Leave module connection notifications and UART startup bytes behind.
      await this.write(new Uint8Array(24).fill(0x55));await wait(this.timing.afterTraining);this.checkSession(epoch);
      await this.write(keysPacket(0));await this.write(configPacket(6,0));await this.configure(settings);
      const deadline=Date.now()+this.timing.handshake;let retryAt=Date.now()+Math.min(1500,this.timing.handshake/2);
      while(this.connected&&epoch===this.generation&&Date.now()<deadline){
        if(this.status&&![0x53,0x61,0x63,0x64,0x65,0x66].includes(this.status.build)){this.waiting('FPGA_FIRMWARE','蓝牙已连接；FPGA 固件不匹配，请使用与 App 配套的融合固件，STREAM3 触屏音效版标识为 0x66');return false;}
        if(this.status&&!this.status.auto&&!this.status.clear&&this.parametersConfirmed){
          this.ready=true;this.problem='';this.phase='FPGA 已确认连接';this.trace('FPGA_READY',`固件0x${this.status.build.toString(16)}、手动模式和参数已确认`);return true;
        }
        if(Date.now()>=retryAt){retryAt=Infinity;await this.write(keysPacket(0));await this.write(configPacket(6,0));await this.configure(settings);this.trace('FPGA_RETRY','重发一次手动模式和参数');}
        await wait(this.timing.poll);
      }
      this.checkSession(epoch);
      const message=this.rxBytes===0?'蓝牙串口已连接，但没收到 FPGA 数据。请检查 FPGA→模块 RXD（J8-6）、共地和固件。':
        !this.status?'蓝牙串口已连接，收到数据但没有有效 FPGA 状态帧。请核对模块 UART 波特率、接线和固件；正常通信先用 9600 8N1，并退出 AT 配置模式。':
        '蓝牙串口已连接，但 FPGA 未确认手动模式或参数。请检查模块 TXD→J8-5。';
      this.waiting('FPGA_NOT_CONFIRMED',message);return false;
    }finally{if(epoch===this.generation){this.syncing=false;this.connecting=false;this.notify();}}
  }
  checkSession(epoch){if(epoch!==this.generation||!this.connected){const e=Error(this.problem||'蓝牙连接已取消或断开');e.code='SESSION_CLOSED';throw e;}}
  waiting(code,message){this.ready=false;this.problem=message;this.phase='蓝牙已连接 · FPGA 待确认';this.voices.clear();this.trace(code,message);this.onError(message);}
  checkHealth(){
    if(!this.connected||this.syncing||this.closing)return;
    if(this.ready&&Date.now()-this.lastRx>this.timing.stale){
      this.allOff();this.waiting('FPGA_STATUS_STALE','蓝牙串口仍连接，FPGA 状态回传中断，已释放按键。可点击重新确认 FPGA。');this.notify();return;
    }
    if(this.ready&&!this.transferBusy)this.sendKeys();
  }
  write(bytes){
    if(!this.connected)return Promise.resolve();const epoch=this.generation,sid=this.session;
    const task=this.tail.then(async()=>{if(!this.connected||epoch!==this.generation)return;
      if(this.native)await this.request('write',{session:sid,bytes:[...bytes]});else await this.writer.write(bytes);this.txBytes+=bytes.length;
    });
    this.tail=task.catch(e=>{if(epoch===this.generation)this.fail(e);});return task;
  }
  async readLoop(epoch){const reader=this.reader;try{while(epoch===this.generation){const {value,done}=await reader.read();if(done)break;if(value&&epoch===this.generation)this.receive(value);}
    if(epoch===this.generation&&this.connected)this.fail(Error('蓝牙串口已断开'));
  }catch(e){if(epoch===this.generation&&this.connected)this.fail(e);}}
  receive(bytes){if(!bytes)return;this.rxBytes+=bytes.length;this.rxSample=[...this.rxSample,...bytes].slice(-48);
    for(const status of this.parser.feed(bytes)){
      this.lastRx=Date.now();for(const listener of [...this.frameListeners])listener(status);
      if(status.type==='pcm'||status.type==='pressure')continue;
      if(status.type==='effects'){this.fxStatus=status;this.fxReceivedAt=Date.now();this.notify();continue;}
      if(status.type==='performance'){this.performanceStatus=status;continue;}this.status=status;this.validFrames++;this.onStatus(status);}
  }
  waitFrame(predicate,{timeout=5500,signal}={}){return new Promise((resolve,reject)=>{
    if(signal?.aborted||!this.connected){reject(Error('同步已取消或连接已断开'));return;}
    const cleanup=()=>{clearTimeout(timer);this.frameListeners.delete(listener);signal?.removeEventListener('abort',aborted);};
    const listener=s=>{if(s.type==='disconnected'){cleanup();reject(Error('连接已断开，同步未完成'));}else if(predicate(s)){cleanup();resolve(s);}};
    const aborted=()=>{cleanup();reject(Error('已取消同步'));};
    const timer=setTimeout(()=>{cleanup();reject(Error('等待FPGA回传超时'));},timeout);
    this.frameListeners.add(listener);signal?.addEventListener('abort',aborted,{once:true});
  });}
  async configure(settings){if(!settings)return;const q=quantizeParameters(settings);this.expected=q;
    await this.write(Uint8Array.from([[1,q.attack],[2,q.decay],[3,q.sustain],[4,q.release],[5,q.volume]].flatMap(([i,v])=>[...configPacket(i,v)])));}
  get parametersConfirmed(){const s=this.status,q=this.expected;return !!s&&!!q&&['attack','decay','sustain','release','volume'].every(k=>s[k]===q[k]);}
  noteOn(id,midi,pad){if(!this.ready||this.wideMask!==null||this.transferBusy)return false;
    if(this.slotNotes){if(Number.isInteger(pad)&&this.slotNotes[pad]!==midi)throw Error('本地键位尚未写入FPGA，请先同步键位');const slot=Number.isInteger(pad)?pad:this.slotNotes.indexOf(midi);if(slot<0)throw Error('FPGA键位中没有这个音符，请先同步键位');this.voices.set(id,{slot,midi});}
    else{if(this.mappingRequired)throw Error('请先读取或写入并确认FPGA键位');if(!Number.isInteger(midi)||midi<60||midi>75)throw Error('FPGA 音域为 C4–D#5，请调整键位映射');this.voices.set(id,midi);}this.sendKeys();return true;}
  noteOff(id){if(this.voices.delete(id))this.sendKeys();}
  sendKeys(){if(this.wideMask!==null)return this.write(keys32Packet(this.wideMask));let mask=0;for(const n of this.voices.values())mask|=1<<(typeof n==='object'?n.slot:n-60);return this.write(this.slotNotes||this.mappingRequired?keys32Packet(mask):keysPacket(mask));}
  setWideKeys(mask){if(!this.ready)return Promise.resolve();this.voices.clear();this.wideMask=mask>>>0;return this.sendKeys();}
  releaseWideKeys(){const task=this.connected?this.write(keys32Packet(0)):Promise.resolve();this.wideMask=null;return task;}
  allOff(){this.voices.clear();if(this.wideMask!==null)this.wideMask=0;if(this.connected)this.sendKeys().catch(()=>{});}
  async manual(){this.allOff();await this.write(configPacket(6,0));}
  async autoPlay(){this.allOff();await this.write(configPacket(6,1));}
  fail(e){if(this.closing)return;this.ready=false;this.problem=e.message||String(e);this.phase='蓝牙串口已断开';this.trace(e.code||'SPP_IO_FAILED',e.detail||this.problem);this.onError(this.problem);void this.disconnect();}
  disconnect(){
    if(this.closingPromise)return this.closingPromise;
    // Invalidate the session before any asynchronous cleanup can yield.
    this.closing=true;const sid=this.session,reader=this.reader,writer=this.writer,port=this.port,readTask=this.readTask;
    ++this.generation;clearInterval(this.timer);this.timer=null;this.connected=false;this.ready=false;this.connecting=false;this.syncing=false;this.voices.clear();this.wideMask=null;this.performanceStatus=null;this.session='';this.slotNotes=null;
    for(const listener of [...this.frameListeners])listener({type:'disconnected'});
    const drain=this.tail;
    this.closingPromise=(async()=>{
      await Promise.resolve(); // Publish the shared cleanup promise before finally can clear it.
      try{if(this.native){
        await Promise.race([drain.catch(()=>{}),wait(300)]);
        if(sid){await Promise.race([this.request('write',{session:sid,bytes:[...keys32Packet(0),...keysPacket(0)]}).catch(()=>{}),wait(300)]);await this.request('disconnect',{session:sid});}
      }else{if(reader){await reader.cancel();await readTask;reader.releaseLock();}if(writer){await writer.write(Uint8Array.from([...keys32Packet(0),...keysPacket(0)])).catch(()=>{});writer.releaseLock();}if(port)await port.close();}}
      catch(e){this.trace('CLOSE_DETAIL',e.message);}
      finally{this.reader=null;this.writer=null;this.port=null;this.closing=false;this.closingPromise=null;this.phase=this.problem?'连接已结束 · 查看诊断':'未连接';this.trace('SESSION_CLOSED','会话已清理');this.notify();}
    })();return this.closingPromise;
  }
  diagnostics(){return {app:'0.4.3',capturedAt:new Date().toISOString(),phase:this.phase,connected:this.connected,ready:this.ready,mode:this.mode,deviceName:this.deviceName,deviceAddress:this.deviceAddress,deviceInfo:this.deviceInfo,problem:this.problem,rxBytes:this.rxBytes,txBytes:this.txBytes,validFrames:this.validFrames,status:this.status,rxHex:this.rxSample.map(b=>b.toString(16).padStart(2,'0')).join(' '),logs:this.logs,native:this.nativeDiagnostics||null,diagnosticsError:this.diagnosticsError||null};}
}
