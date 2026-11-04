import test from 'node:test';
import assert from 'node:assert/strict';
import {PianoLink,keysPacket} from '../public/piano-link.js';

const settings={attack:10,decay:200,sustain:55,release:400,volume:60};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
function nativeFixture({silent=false,garbage=false,connectError=false,immediateClose=false,writeError=false,build=0x53,ignoreConfig=false,deviceName='HC-05'}={}){
  const old=globalThis.PianoAndroid;let sid='',ticker,mask=0;let board={attack:2,decay:5,sustain:160,release:5,volume:8};const calls=[];
  const emit=()=>{if(silent)return;if(garbage){globalThis.PianoNativeEvent('data',{session:sid,bytes:[0x2b,0x43,0x4f]});return;}
    const f=new Uint8Array(40);f.set([0xa5,0x5a,4,8]);f[7]=f[11]=mask&255;f[8]=f[12]=mask>>8;f[15]=board.volume;f[30]=build;f[31]=board.attack;f[32]=board.decay;f[33]=board.sustain;f[34]=board.release;f[39]=f.slice(2,39).reduce((a,b)=>a^b,0);
    globalThis.PianoNativeEvent('data',{session:sid,bytes:[...f]});
  };
  globalThis.PianoAndroid={request(id,method,json){const arg=JSON.parse(json);calls.push({method,...arg});let result={ok:true};
    if(method==='connect'){
      if(connectError)result={error:'蓝牙串口建立失败',code:'SPP_CONNECT_FAILED',detail:'read failed, socket might closed or timeout, read ret: -1'};
      else{sid=arg.session;ticker=setInterval(emit,4);result.mode='SPP 标准认证';result.session=sid;result.deviceName=deviceName;result.deviceType=1;result.uuids=['00001101-0000-1000-8000-00805f9b34fb'];}
    }
    if(method==='write'&&arg.session===sid){for(let i=0;i<arg.bytes.length;i++){
      if(arg.bytes[i]===0xf5&&i+3<arg.bytes.length){const [,id,value]=arg.bytes.slice(i,i+4);const key=['','attack','decay','sustain','release','volume'][id];if(key&&!ignoreConfig)board[key]=value;i+=3;}
      else if(arg.bytes[i]===0xf6&&i+3<arg.bytes.length){mask=arg.bytes[i+1]|arg.bytes[i+2]<<8;i+=3;}
    }}
    if(method==='disconnect'&&arg.session===sid)clearInterval(ticker);
    if(method==='write'&&writeError)result={error:'模拟写入失败',code:'SPP_WRITE_FAILED',detail:'injected write IOException'};
    if(method==='diagnostics')result.native={sdk:35,events:[{code:'SOCKET_CONNECT_BEGIN',elapsedMs:100},{code:'SOCKET_CONNECT_ERROR',elapsedMs:220,stack:'injected IOException'}]};
    queueMicrotask(()=>{globalThis.PianoNativeResult(id,result);
      if(method==='connect'&&immediateClose){clearInterval(ticker);globalThis.PianoNativeEvent('disconnected',{session:sid,message:'模拟立即断开',code:'SPP_READ_CLOSED',detail:'injected read ret: -1'});}});
  }};
  return {calls,emit,stop:()=>clearInterval(ticker),restore(){clearInterval(ticker);globalThis.PianoAndroid=old;}};
}
function link(extra={}){return new PianoLink({timing:{settle:0,afterTraining:0,handshake:55,poll:2,heartbeat:10000,stale:10},...extra});}

test('SPP connect error keeps its stage and original read-ret-minus-one evidence',async()=>{
  const f=nativeFixture({connectError:true}),p=link();try{await assert.rejects(p.connect('test',settings),/蓝牙串口建立失败/);assert.equal(p.connected,false);assert.ok(p.diagnostics().logs.some(x=>x.code==='SPP_CONNECT_FAILED'&&x.message.includes('read ret: -1')));}finally{await p.disconnect();f.restore();}
});
test('no FPGA data preserves physical SPP connection and exposes explicit resync',async()=>{
  const f=nativeFixture({silent:true}),p=link();try{assert.equal(await p.connect('test',settings),false);assert.equal(p.connected,true);assert.equal(p.ready,false);assert.match(p.problem,/没收到 FPGA 数据/);assert.equal(f.calls.filter(x=>x.method==='disconnect').length,0);assert.equal(p.diagnostics().validFrames,0);}finally{await p.disconnect();f.restore();}
});
test('received garbage is diagnosed separately from receiving zero bytes',async()=>{
  const f=nativeFixture({garbage:true}),p=link();try{assert.equal(await p.connect('test',settings),false);assert.equal(p.connected,true);assert.ok(p.rxBytes>0);assert.equal(p.validFrames,0);assert.match(p.problem,/没有有效 FPGA 状态帧/);}finally{await p.disconnect();f.restore();}
});
test('expired FPGA feedback releases notes but does not close a healthy socket',async()=>{
  const f=nativeFixture(),p=link();try{assert.equal(await p.connect('test',settings),true);p.noteOn('held',60);await p.tail;f.stop();p.lastRx=Date.now()-100;p.checkHealth();await p.tail;
    assert.equal(p.ready,false);assert.equal(p.connected,true);assert.equal(p.voices.size,0);assert.equal(f.calls.filter(x=>x.method==='disconnect').length,0);assert.deepEqual(f.calls.filter(x=>x.method==='write').at(-1).bytes,[...keysPacket(0)]);
    assert.equal(await p.synchronize(settings).then(x=>x),false); // no further status after ticker stopped
  }finally{await p.disconnect();f.restore();}
});
test('late old-reader data and disconnect cannot affect reconnected session',async()=>{
  const f=nativeFixture(),p=link();try{await p.connect('test',settings);const previous=p.session;await p.disconnect();await p.connect('test',settings);const current=p.session,rx=p.rxBytes;
    globalThis.PianoNativeEvent('disconnected',{session:previous,message:'read failed',code:'SPP_READ_CLOSED'});
    globalThis.PianoNativeEvent('data',{session:previous,bytes:[1,2,3]});
    assert.equal(p.session,current);assert.equal(p.connected,true);assert.equal(p.ready,true);assert.equal(p.rxBytes,rx);
  }finally{await p.disconnect();f.restore();}
});
test('duplicate connect is rejected while first connect is in progress',async()=>{
  const f=nativeFixture(),p=link();try{const first=p.connect('test',settings);await assert.rejects(p.connect('test',settings),/尚未结束/);await first;assert.equal(f.calls.filter(x=>x.method==='connect').length,1);}finally{await p.disconnect();f.restore();}
});
test('current reader failure stops output and closes only its matching session',async()=>{
  const errors=[],f=nativeFixture(),p=link({onError:m=>errors.push(m)});try{await p.connect('test',settings);const sid=p.session;p.noteOn('x',60);await p.tail;
    globalThis.PianoNativeEvent('disconnected',{session:sid,message:'模块连接已中断',code:'SPP_READ_CLOSED',detail:'read ret: -1'});
    await p.closingPromise;assert.equal(p.connected,false);assert.equal(p.ready,false);assert.equal(p.voices.size,0);assert.equal(errors.at(-1),'模块连接已中断');assert.equal(f.calls.filter(x=>x.method==='disconnect').at(-1).session,sid);
  }finally{await p.disconnect();f.restore();}
});
test('cleanup without a transport can complete and a later connect can succeed',async()=>{
  const f=nativeFixture(),p=link();try{await p.disconnect();assert.equal(p.closingPromise,null);assert.equal(await p.connect('test',settings),true);}finally{await p.disconnect();f.restore();}
});
test('default uses standard-first automatic strategy; explicit modes remain selectable',async()=>{
  const f=nativeFixture(),p=link();try{await p.connect('test',settings);assert.equal(f.calls.filter(x=>x.method==='connect').at(-1).strategy,'auto');
    await p.disconnect();await p.connect('test',settings,{strategy:'standard'});assert.equal(f.calls.filter(x=>x.method==='connect').at(-1).strategy,'standard');
    await p.disconnect();await p.connect('test',settings,{compatibility:true});assert.equal(f.calls.filter(x=>x.method==='connect').at(-1).compatibility,true);
  }finally{await p.disconnect();f.restore();}
});

test('unknown connection strategies fail before allocating a session or native request',async()=>{
  const f=nativeFixture(),p=link();try{await assert.rejects(p.connect('test',settings,{strategy:'bad'}),/不支持/);assert.equal(f.calls.length,0);assert.equal(p.connecting,false);}finally{await p.disconnect();f.restore();}
});
test('classic connection can cancel discovery with no location permission',async()=>{
  const {readFile}=await import('node:fs/promises');const xml=await readFile(new URL('../android/AndroidManifest.xml',import.meta.url),'utf8');
  assert.match(xml,/permission\.BLUETOOTH_CONNECT/);assert.match(xml,/permission\.BLUETOOTH_SCAN/);assert.match(xml,/permission\.BLUETOOTH_ADMIN[\s\S]*?maxSdkVersion="30"/);assert.match(xml,/neverForLocation/);assert.doesNotMatch(xml,/ACCESS_(FINE|COARSE)_LOCATION/);
});

test('reader failure immediately following connect result never leaves a false connection',async()=>{
  const f=nativeFixture({immediateClose:true}),p=link();try{
    await assert.rejects(p.connect('test',settings));await p.closingPromise;
    assert.equal(p.connected,false);assert.equal(p.ready,false);
    assert.ok(p.logs.some(x=>x.code==='SPP_READ_CLOSED'&&x.message.includes('read ret: -1')));
  }finally{await p.disconnect();f.restore();}
});

test('write failure during training is diagnosed as write failure and closes its session',async()=>{
  const f=nativeFixture({writeError:true}),p=link();try{
    await assert.rejects(p.connect('test',settings));await p.closingPromise;
    assert.equal(p.connected,false);assert.ok(p.logs.some(x=>x.code==='SPP_WRITE_FAILED'));
    assert.equal(f.calls.filter(x=>x.method==='disconnect').length,1);
  }finally{await p.disconnect();f.restore();}
});

test('wrong FPGA firmware leaves SPP connected with an explicit firmware diagnosis',async()=>{
  const f=nativeFixture({build:0x52}),p=link();try{
    assert.equal(await p.connect('test',settings),false);assert.equal(p.connected,true);
    assert.ok(p.logs.some(x=>x.code==='FPGA_FIRMWARE'));assert.equal(f.calls.filter(x=>x.method==='disconnect').length,0);
  }finally{await p.disconnect();f.restore();}
});

test('merged touch Bluetooth build 0x61 completes handshake and sends note masks',async()=>{
  const f=nativeFixture({build:0x61}),p=link();try{
    assert.equal(await p.connect('test',settings),true);assert.equal(p.ready,true);
    p.noteOn('merge',60);await p.tail;
    assert.deepEqual(f.calls.filter(x=>x.method==='write').at(-1).bytes,[...keysPacket(1)]);
    assert.ok(p.logs.some(x=>x.code==='FPGA_READY'&&x.message.includes('0x61')));
  }finally{await p.disconnect();f.restore();}
});

test('teammate touch-only build 0x60 is not mistaken for the merged Bluetooth firmware',async()=>{
  const f=nativeFixture({build:0x60}),p=link();try{
    assert.equal(await p.connect('test',settings),false);assert.equal(p.ready,false);assert.equal(p.connected,true);
    assert.match(p.problem,/配套的融合固件/);
  }finally{await p.disconnect();f.restore();}
});

test('valid feedback without parameter acknowledgement is distinguished from a socket failure',async()=>{
  const f=nativeFixture({ignoreConfig:true}),p=link();try{
    assert.equal(await p.connect('test',settings),false);assert.equal(p.connected,true);
    assert.ok(p.validFrames>0);assert.match(p.problem,/未确认手动模式或参数/);
  }finally{await p.disconnect();f.restore();}
});

test('exported diagnostics contains the native stage, timing and stack without connecting',async()=>{
  const f=nativeFixture(),p=link();try{
    const d=await p.collectDiagnostics();assert.equal(d.native.events[1].elapsedMs,220);
    assert.match(d.native.events[1].stack,/IOException/);assert.equal(p.connected,false);
    assert.deepEqual(f.calls.map(x=>x.method),['diagnostics']);
  }finally{await p.disconnect();f.restore();}
});

test('cancel during settling then reconnect cannot let the old handshake write to the new session',async()=>{
  const f=nativeFixture(),p=link({timing:{settle:30,afterTraining:0,handshake:60,poll:2,heartbeat:10000}});try{
    const first=p.connect('test',settings);const rejected=assert.rejects(first);await sleep(5);
    const oldSession=p.session;await p.disconnect();assert.equal(await p.connect('test',settings),true);await rejected;
    assert.ok(f.calls.filter(x=>x.method==='write'&&x.session===oldSession).every(x=>x.bytes[0]!==0x55));
    assert.equal(p.ready,true);
  }finally{await p.disconnect();f.restore();}
});

test('merged rhythm-game Bluetooth build 0x63 completes handshake and sends note masks',async()=>{
  const f=nativeFixture({build:0x63}),p=link();try{
    assert.equal(await p.connect('test',settings),true);assert.equal(p.ready,true);
    p.noteOn('merge',60);await p.tail;
    assert.deepEqual(f.calls.filter(x=>x.method==='write').at(-1).bytes,[...keysPacket(1)]);
    assert.ok(p.logs.some(x=>x.code==='FPGA_READY'&&x.message.includes('0x63')));
  }finally{await p.disconnect();f.restore();}
});
test('teammate rhythm-game build 0x62 is not mistaken for the merged Bluetooth firmware',async()=>{
  const f=nativeFixture({build:0x62}),p=link();try{
    assert.equal(await p.connect('test',settings),false);assert.equal(p.ready,false);assert.equal(p.connected,true);
    assert.match(p.problem,/配套的融合固件/);
  }finally{await p.disconnect();f.restore();}
});


test('HC-05 SPP is identified by native device metadata rather than a JDY-31 label',async()=>{
  const f=nativeFixture({build:0x64,deviceName:'HC-05'}),p=link();try{
    assert.equal(await p.connect('test',settings),true);assert.equal(p.deviceName,'HC-05');
    assert.equal(p.diagnostics().deviceInfo.type,1);assert.equal(p.status.build,0x64);
    assert.ok(p.logs.some(x=>x.code==='CONNECT_START'&&x.message.includes('标准 SPP 优先')));
  }finally{await p.disconnect();f.restore();}
});
test('LE-only devices fail before a native RFCOMM request or session is allocated',async()=>{
  const f=nativeFixture(),p=link();try{
    await assert.rejects(p.connect('test',settings,{device:{name:'BLE module',type:2}}),/只有 BLE/);
    assert.equal(f.calls.length,0);assert.equal(p.session,'');assert.equal(p.connecting,false);
  }finally{await p.disconnect();f.restore();}
});
test('renamed serial device with unknown type and an empty SDP cache is still connectable',async()=>{
  const f=nativeFixture({deviceName:'我的电子琴'}),p=link();try{
    assert.equal(await p.connect('test',settings,{device:{name:'我的电子琴',type:0,uuids:[]}}),true);
    assert.equal(p.deviceName,'我的电子琴');assert.equal(f.calls.filter(x=>x.method==='connect').length,1);
  }finally{await p.disconnect();f.restore();}
});

test('audio FX build 0x65 connects and additional V5 snapshots do not replace legacy note status',async()=>{
  const f=nativeFixture({build:0x65}),p=link();try{
    assert.equal(await p.connect('test',settings),true);const before=p.status;
    const data=[0xa5,0x5a,5,0x65,8,7,18,90,64,8,30,51,45,4,64,3,50,18,16,100,0];
    data.push(data.slice(2).reduce((a,b)=>a^b,0));
    p.receive(data.slice(0,9));assert.equal(p.fxStatus,null);
    p.receive(data.slice(9));assert.equal(p.fxStatus.build,0x65);assert.equal(p.fxStatus.revision,8);
    assert.equal(p.fxStatus.values[0],7);assert.equal(p.status,before);assert.equal(p.ready,true);
  }finally{await p.disconnect();f.restore();}
});

test('STREAM3 native panel build 0x66 connects and additional V5 snapshots do not replace legacy note status',async()=>{
  const f=nativeFixture({build:0x66}),p=link();try{
    assert.equal(await p.connect('test',settings),true);const before=p.status;
    const data=[0xa5,0x5a,5,0x66,8,7,18,90,64,8,30,51,45,4,64,3,50,18,16,100,0];
    data.push(data.slice(2).reduce((a,b)=>a^b,0));
    p.receive(data.slice(0,9));assert.equal(p.fxStatus,null);
    p.receive(data.slice(9));assert.equal(p.fxStatus.build,0x66);assert.equal(p.fxStatus.revision,8);
    assert.equal(p.fxStatus.values[0],7);assert.equal(p.status,before);assert.equal(p.ready,true);
  }finally{await p.disconnect();f.restore();}
});
