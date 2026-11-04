package cn.touchpiano.app;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.webkit.*;
import android.view.WindowInsets;
import android.view.View;
import android.util.Log;
import org.json.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;

/** Offline UI only. The JS bridge is exposed solely to packaged app assets. */
public class MainActivity extends Activity {
  private WebView web;
  private final Handler main=new Handler(Looper.getMainLooper());
  private final ExecutorService worker=Executors.newSingleThreadExecutor();
  private final ExecutorService networkWorker=Executors.newSingleThreadExecutor();
  private volatile BluetoothSocket socket;
  private volatile String session="";
  private volatile boolean destroyed=false;
  private final Set<String> cancelledSessions=ConcurrentHashMap.newKeySet();
  private volatile boolean paused=false;
  private final Object writeLock=new Object();
  private final ArrayDeque<JSONObject> nativeLogs=new ArrayDeque<>();
  private final String runId=Long.toHexString(System.currentTimeMillis());
  private JSONArray previousRun=new JSONArray();
  private volatile long nativeRx=0,nativeTx=0;
  private volatile String selectedMode="",selectedDevice="";
  private volatile boolean permissionPromptPending=false,scanPermissionPrompted=false;
  private ValueCallback<Uri[]> fileCallback;
  private PermissionRequest cameraRequest;
  private byte[] exportBytes;
  private String exportRequestId;
  private static final String ORIGIN="https://appassets.androidplatform.net/";
  private static final UUID SPP=UUID.fromString("00001101-0000-1000-8000-00805f9b34fb");

  @Override public void onCreate(Bundle state){super.onCreate(state);
    try{previousRun=new JSONArray(getPreferences(MODE_PRIVATE).getString("btLog","[]"));}catch(JSONException ignored){}
    trace("APP_START","sdk="+Build.VERSION.SDK_INT+", model="+Build.MANUFACTURER+" "+Build.MODEL,null);
    web=new WebView(this);setContentView(web);
    web.setOnApplyWindowInsetsListener((v,insets)->{if(Build.VERSION.SDK_INT>=30){android.graphics.Insets i=insets.getInsets(WindowInsets.Type.systemBars());v.setPadding(i.left,i.top,i.right,i.bottom);}return insets;});
    WebSettings s=web.getSettings();s.setJavaScriptEnabled(true);s.setDomStorageEnabled(true);
    s.setAllowFileAccess(false);s.setAllowContentAccess(false);s.setMediaPlaybackRequiresUserGesture(false);
    web.addJavascriptInterface(new Bridge(),"PianoAndroid");
    web.setWebViewClient(new WebViewClient(){
      @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){return !r.getUrl().toString().startsWith(ORIGIN);}
      @Override public WebResourceResponse shouldInterceptRequest(WebView v,WebResourceRequest req){
        String url=req.getUrl().toString();
        if(!url.startsWith(ORIGIN))return new WebResourceResponse("text/plain","UTF-8",403,"Blocked",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));
        try{String path=req.getUrl().getPath();if(path.equals("/"))path="/index.html";
          if(path.contains(".."))throw new IOException("path");
          String mime=path.endsWith(".js")?"text/javascript":path.endsWith(".css")?"text/css":path.endsWith(".html")?"text/html":path.endsWith(".wasm")?"application/wasm":path.endsWith(".png")?"image/png":path.endsWith(".json")?"application/json":"application/octet-stream";
          return new WebResourceResponse(mime,mime.startsWith("text/")||mime.equals("application/json")?"UTF-8":null,getAssets().open("public"+path));
        }catch(IOException e){return new WebResourceResponse("text/plain","UTF-8",404,"Not found",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));}
      }
    });
    web.setWebChromeClient(new WebChromeClient(){
      @Override public void onPermissionRequest(PermissionRequest req){main.post(()->{
        if(!"https://appassets.androidplatform.net".equals(req.getOrigin().toString().replaceAll("/$","")) || !Arrays.asList(req.getResources()).contains(PermissionRequest.RESOURCE_VIDEO_CAPTURE)){req.deny();return;}
        if(checkSelfPermission(Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED){req.grant(new String[]{PermissionRequest.RESOURCE_VIDEO_CAPTURE});return;}
        if(cameraRequest!=null)cameraRequest.deny();cameraRequest=req;
        requestPermissions(new String[]{Manifest.permission.CAMERA},31);
      });}
      @Override public void onPermissionRequestCanceled(PermissionRequest req){main.post(()->{if(cameraRequest==req)cameraRequest=null;});}

      @Override public boolean onShowFileChooser(WebView v,ValueCallback<Uri[]> cb,FileChooserParams params){
        if(fileCallback!=null)fileCallback.onReceiveValue(null);fileCallback=cb;
        Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("*/*").addCategory(Intent.CATEGORY_OPENABLE);startActivityForResult(i,40);return true;
      }
    });
    web.loadUrl(ORIGIN);
  }
  private void js(String code){main.post(()->{if(web!=null)web.evaluateJavascript(code,null);});}
  private void event(String type,Object data){js("window.PianoNativeEvent&&window.PianoNativeEvent("+JSONObject.quote(type)+","+data.toString()+")");}
  private void result(String id,JSONObject data){js("window.PianoNativeResult&&window.PianoNativeResult("+JSONObject.quote(id)+","+data+")");}
  private synchronized void trace(String code,String detail,Throwable error){
    try{
      JSONObject item=new JSONObject().put("wallTimeMs",System.currentTimeMillis()).put("elapsedMs",SystemClock.elapsedRealtime())
          .put("run",runId).put("session",session).put("thread",Thread.currentThread().getName())
          .put("code",code).put("detail",detail).put("rxBytes",nativeRx).put("txBytes",nativeTx);
      if(error!=null)item.put("stack",Log.getStackTraceString(error));
      nativeLogs.addLast(item);while(nativeLogs.size()>160)nativeLogs.removeFirst();
      Log.i("PianoBluetooth",item.toString());
      getPreferences(MODE_PRIVATE).edit().putString("btLog",new JSONArray(nativeLogs).toString()).apply();
    }catch(JSONException ignored){}
  }
  private synchronized JSONObject diagnosticSnapshot(){
    JSONObject out=new JSONObject();
    try{
      out.put("app","0.4.3").put("run",runId).put("sdk",Build.VERSION.SDK_INT).put("android",Build.VERSION.RELEASE)
          .put("manufacturer",Build.MANUFACTURER).put("model",Build.MODEL).put("session",session)
          .put("mode",selectedMode).put("device",selectedDevice).put("paused",paused)
          .put("socketConnected",socket!=null&&socket.isConnected()).put("rxBytes",nativeRx).put("txBytes",nativeTx)
          .put("events",new JSONArray(nativeLogs)).put("previousRun",previousRun)
          .put("connectPermission",Build.VERSION.SDK_INT<31||checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)==PackageManager.PERMISSION_GRANTED)
          .put("scanPermission",Build.VERSION.SDK_INT<31||checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)==PackageManager.PERMISSION_GRANTED);
    }catch(JSONException ignored){}
    return out;
  }
  private BluetoothAdapter adapter() throws Exception {return adapter(false);}
  private BluetoothAdapter adapter(boolean preparingConnection) throws Exception {
    if(Build.VERSION.SDK_INT>=31){
      boolean connectGranted=checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)==PackageManager.PERMISSION_GRANTED;
      boolean scanGranted=checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)==PackageManager.PERMISSION_GRANTED;
      if(!connectGranted || (preparingConnection&&!scanGranted&&!scanPermissionPrompted)){
        synchronized(MainActivity.this){if(!permissionPromptPending){
          permissionPromptPending=true;scanPermissionPrompted=true;
          main.post(()->requestPermissions(new String[]{Manifest.permission.BLUETOOTH_CONNECT,Manifest.permission.BLUETOOTH_SCAN},10));
        }}
        throw new IOException("请允许附近设备权限，然后重新读取设备或连接。搜索权限用于在连接前停止系统搜索");
      }
    }
    BluetoothAdapter a=((BluetoothManager)getSystemService(BLUETOOTH_SERVICE)).getAdapter();
    if(a==null)throw new IOException("手机不支持蓝牙");if(!a.isEnabled())throw new IOException("请先在系统设置开启蓝牙");return a;
  }
  private synchronized void closeSocket(){BluetoothSocket old=socket;socket=null;if(old!=null)try{trace("SOCKET_LOCAL_CLOSE","connected="+old.isConnected(),null);old.close();}catch(IOException e){trace("SOCKET_CLOSE_ERROR","close",e);}}
  private void stopNotes(){BluetoothSocket s=socket;if(s!=null)try{synchronized(writeLock){s.getOutputStream().write(new byte[]{(byte)0xf7,0,0,0,0,(byte)0xf7,(byte)0xf6,0,0,(byte)0xf6});s.getOutputStream().flush();}}catch(IOException ignored){}}
  private synchronized boolean closeExpected(BluetoothSocket expected,String expectedSession){
    if(socket!=expected||!session.equals(expectedSession))return false;
    closeSocket();return true;
  }
  private JSONObject payload(String sid,String message,String code,String detail){
    JSONObject p=new JSONObject();try{p.put("session",sid).put("message",message).put("code",code).put("detail",detail);}catch(JSONException ignored){}return p;
  }
  private void cancelDiscoveryIfPermitted(BluetoothAdapter a) {
    // Official API needs SCAN on Android 12+, ADMIN on Android 8-11.
    // A denied optional SCAN grant must not prevent CONNECT-only bonded use.
    if(Build.VERSION.SDK_INT>=31&&checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)!=PackageManager.PERMISSION_GRANTED){
      trace("DISCOVERY_CANCEL_SKIPPED","SCAN denied; stop searching in system Bluetooth settings before retrying",null);
      event("progress",payload(session,"未允许停止搜索；若连接失败，请先关闭系统蓝牙搜索后重试","DISCOVERY_CANCEL_SKIPPED",""));return;
    }
    try{trace("DISCOVERY_CANCEL","wasDiscovering="+a.isDiscovering()+", cancelled="+a.cancelDiscovery(),null);}
    catch(SecurityException e){trace("DISCOVERY_CANCEL_SKIPPED","Permission unavailable; continuing",e);}
  }
  private JSONArray advertisedServices(BluetoothDevice d){JSONArray out=new JSONArray();ParcelUuid[] cached=d.getUuids();if(cached!=null)for(ParcelUuid u:cached)out.put(u.toString());return out;}
  private final class NativeSocket implements SppConnector.Socket {
    final BluetoothSocket value;final String sid;final String mode;volatile boolean timedOut=false;
    NativeSocket(BluetoothSocket value,String sid,String mode){this.value=value;this.sid=sid;this.mode=mode;}
    public void connect() throws IOException {
      ConnectionDeadline deadline=new ConnectionDeadline();
      long started=SystemClock.elapsedRealtime();trace("SOCKET_CONNECT_BEGIN",mode,null);
      Runnable timeout=()->{
        if(value.isConnected()){deadline.complete();return;}
        if(!deadline.expire())return;
        timedOut=true;trace("CONNECT_DEADLINE_CLOSE","18000ms; candidate session="+sid,null);
        try{value.close();}catch(IOException ignored){}
      };
      main.postDelayed(timeout,18000);
      try{value.connect();if(!deadline.complete())throw new IOException("SPP connect timeout");trace("SOCKET_CONNECT_OK","durationMs="+(SystemClock.elapsedRealtime()-started),null);}
      catch(IOException e){trace("SOCKET_CONNECT_ERROR","durationMs="+(SystemClock.elapsedRealtime()-started)+", timedOut="+timedOut,e);throw e;}
      finally{deadline.complete();main.removeCallbacks(timeout);}
    }
    public void close(){closeExpected(value,sid);try{value.close();}catch(IOException ignored){}}
  }
  private void startReader(BluetoothSocket next,String sid){
    new Thread(()->{try{InputStream in=next.getInputStream();byte[] buf=new byte[256];int n;
      trace("READER_START","session="+sid,null);
      while((n=in.read(buf))!=-1){
        if(socket!=next||!session.equals(sid))return;
        boolean first=nativeRx==0;nativeRx+=n;if(first)trace("FIRST_RX","bytes="+n,null);
        JSONArray values=new JSONArray();for(int j=0;j<n;j++)values.put(buf[j]&255);
        JSONObject p=new JSONObject().put("session",sid).put("bytes",values);event("data",p);
      }
      throw new IOException("read returned -1");
    }catch(Exception e){trace("READER_ERROR","readerSession="+sid+", current="+(socket==next&&session.equals(sid)),e);if(closeExpected(next,sid))event("disconnected",payload(sid,
        "蓝牙串口连接已中断，请检查模块供电、是否被其他设备占用，或取消配对后重试",
        "SPP_READ_CLOSED",String.valueOf(e.getMessage())));}},"piano-bt-reader").start();
  }
  private class Bridge {
    @JavascriptInterface public void request(String id,String method,String json){
      // Diagnostics must remain readable even while connect() blocks the I/O worker.
      if(method.equals("diagnostics")){JSONObject out=new JSONObject();try{out.put("ok",true).put("native",diagnosticSnapshot());}catch(JSONException ignored){}result(id,out);return;}
      final long queuedAt=SystemClock.elapsedRealtime();
      if(!method.equals("write"))trace("REQUEST_QUEUED",method+", id="+id,null);
      // Cancellation must unblock a pending connect, rather than queue behind it.
      if(method.equals("disconnect"))try{String sid=new JSONObject(json).optString("session");
        trace("DISCONNECT_REQUEST","requestedSession="+sid+", matches="+session.equals(sid),null);
        cancelledSessions.add(sid);
        synchronized(MainActivity.this){if(session.equals(sid)){session="";closeSocket();}}
      }catch(JSONException ignored){}
      (method.equals("fetchScore")?networkWorker:worker).execute(()->{
      if(!method.equals("write"))trace("REQUEST_BEGIN",method+", queueMs="+(SystemClock.elapsedRealtime()-queuedAt),null);
      JSONObject out=new JSONObject();Runnable afterResult=null;try{JSONObject args=new JSONObject(json);
        switch(method){
          case "fetchScore":out.put("content",ScoreDownload.fetch(args.getString("url")));break;
          case "orientation":{
            final boolean landscape=args.optBoolean("landscape",false);
            main.post(()->setRequestedOrientation(landscape?android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE:android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED));break;
          }
          case "settings":main.post(()->startActivity(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS)));break;
          case "devices":{
            JSONArray devices=new JSONArray();List<BluetoothDevice> sorted=new ArrayList<>(adapter().getBondedDevices());sorted.sort(Comparator.comparing(d->d.getAddress()));
            for(BluetoothDevice d:sorted)devices.put(new JSONObject().put("name",d.getName()).put("address",d.getAddress())
              .put("type",d.getType()).put("uuids",advertisedServices(d)));
            out.put("devices",devices);break;
          }
          case "connect":{
            BluetoothAdapter a=adapter(true);String addr=args.getString("address"),sid=args.getString("session");
            if(!BluetoothAdapter.checkBluetoothAddress(addr))throw new IOException("蓝牙地址不正确");
            BluetoothDevice d=a.getRemoteDevice(addr);if(d.getBondState()!=BluetoothDevice.BOND_BONDED)throw new IOException("请先在系统蓝牙设置中配对你的串口模块（HC-05 / HC-06 / JDY-31 等）");
            if(d.getType()==BluetoothDevice.DEVICE_TYPE_LE)throw new IOException("BLE_ONLY: 这个设备只有低功耗蓝牙，不能用经典蓝牙 SPP 连接；请选择实际的串口模块");
            closeSocket();session=sid;
            nativeRx=0;nativeTx=0;selectedMode=args.optString("strategy",args.optBoolean("compatibility",false)?"compatibility":"standard");selectedDevice=d.getName();
            trace("DEVICE_SELECTED","name="+selectedDevice+", type="+d.getType()+", bondState="+d.getBondState()+", cachedUuids="+advertisedServices(d)+", mode="+selectedMode,null);
            NativeSocket established;
            try{established=(NativeSocket)SppConnector.connect(new SppConnector.Environment(){
              public boolean cancelled(){return destroyed||cancelledSessions.contains(sid)||!session.equals(sid);}
              public void beforeAttempt() {cancelDiscoveryIfPermitted(a);}
              public void progress(String message){event("progress",payload(sid,message,"SPP_CONNECTING",""));}
              public void pause() throws IOException {try{Thread.sleep(600);}catch(InterruptedException e){Thread.currentThread().interrupt();throw new IOException("Connection interrupted",e);}}
              public SppConnector.Socket create(boolean compatibility) throws IOException {
                trace("SOCKET_CREATE",compatibility?"insecure RFCOMM":"authenticated RFCOMM",null);
                BluetoothSocket next=compatibility?d.createInsecureRfcommSocketToServiceRecord(SPP):d.createRfcommSocketToServiceRecord(SPP);
                synchronized(MainActivity.this){if(cancelled()){next.close();throw new IOException("Connection cancelled");}socket=next;}
                return new NativeSocket(next,sid,compatibility?"SPP 串口兼容":"SPP 标准认证");
              }
            },selectedMode);}catch(Exception e){if(session.equals(sid))closeSocket();throw e;}
            out.put("session",sid).put("mode",established.mode).put("deviceName",d.getName()).put("address",addr)
              .put("deviceType",d.getType()).put("uuids",advertisedServices(d));
            // Post connect result before starting a reader that can immediately fail.
            afterResult=()->startReader(established.value,sid);break;
          }
          case "write":{
            String sid=args.getString("session");BluetoothSocket current=socket;
            if(!session.equals(sid))throw new IOException("STALE_SESSION: 已忽略旧连接写入");
            if(current==null||!current.isConnected())throw new IOException("SPP_WRITE_CLOSED: 蓝牙串口已断开");
            JSONArray values=args.getJSONArray("bytes");if(values.length()>1024)throw new IOException("串口数据过长");
            byte[] bytes=new byte[values.length()];for(int j=0;j<bytes.length;j++)bytes[j]=(byte)values.getInt(j);
            synchronized(writeLock){if(!session.equals(sid))throw new IOException("STALE_SESSION");
              if(paused){trace("WRITE_SUPPRESSED","Activity paused",null);stopNotes();break;}current.getOutputStream().write(bytes);current.getOutputStream().flush();
              boolean first=nativeTx==0;nativeTx+=bytes.length;if(first)trace("FIRST_TX","bytes="+bytes.length+", queueMs="+(SystemClock.elapsedRealtime()-queuedAt),null);}break;
          }
          case "disconnect":break; // Closed synchronously above, only for the matching session.
          case "export":{
            if(exportRequestId!=null)throw new IOException("请先完成上一次文件保存");
            String mime=args.optString("mime","application/json");if(!mime.equals("audio/wav")&&!mime.equals("application/json"))throw new IOException("不支持的文件格式");
            byte[] bytes=args.has("base64")?android.util.Base64.decode(args.getString("base64"),android.util.Base64.DEFAULT):args.getString("content").getBytes("UTF-8");
            if(mime.equals("audio/wav")&&bytes.length>1048576)throw new IOException("录音文件过大");
            exportBytes=bytes;exportRequestId=id;
            Intent intent=new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType(mime).putExtra(Intent.EXTRA_TITLE,args.optString("name",mime.equals("audio/wav")?"FPGA-performance.wav":"touch-performance.json"));
            main.post(()->startActivityForResult(intent,41));return; // Complete the request after the document is actually saved.
          }
          default:throw new IOException("不支持的操作");
        }
        out.put("ok",true);
      }catch(Exception e){trace("REQUEST_ERROR",method+", elapsedMs="+(SystemClock.elapsedRealtime()-queuedAt),e);try{String detail=String.valueOf(e.getMessage());String code=method.equals("connect")?"SPP_CONNECT_FAILED":"SPP_IO_FAILED";
        String message=method.equals("connect")?"App 蓝牙串口未建立，尚未向 FPGA 发送数据。系统显示已连接不代表串口已接通，请查看连接诊断。":detail;
        if(method.equals("write")){code="SPP_WRITE_FAILED";message="蓝牙串口写入失败，连接可能已断开。请查看连接诊断并重新连接。";}
        if(e instanceof SecurityException||detail.contains("权限")||detail.contains("PERMISSION")){code="BLUETOOTH_PERMISSION";message="请允许附近设备权限，再次点击连接";}
        if(detail.contains("配对")&&!detail.contains("SPP_CONNECT_FAILED"))message=detail;
        if(detail.startsWith("BLE_ONLY:")){code="BLE_ONLY";message=detail.substring(9).trim();}
        if(detail.equals("请先在系统设置开启蓝牙")){code="BLUETOOTH_DISABLED";message=detail;}
        if(detail.equals("手机不支持蓝牙")){code="BLUETOOTH_UNSUPPORTED";message=detail;}
        out.put("error",message).put("code",code).put("detail",detail);
      }catch(JSONException ignored){}}
      result(id,out);if(afterResult!=null)afterResult.run();
    });}
  }
  @Override public void onRequestPermissionsResult(int code,String[] permissions,int[] grants){
    super.onRequestPermissionsResult(code,permissions,grants);
    if(code==31&&cameraRequest!=null){PermissionRequest req=cameraRequest;cameraRequest=null;
      if(grants.length>0&&grants[0]==PackageManager.PERMISSION_GRANTED)req.grant(new String[]{PermissionRequest.RESOURCE_VIDEO_CAPTURE});else req.deny();
    }
    if(code==10){permissionPromptPending=false;trace("PERMISSION_RESULT","permissions="+Arrays.toString(permissions)+", grants="+Arrays.toString(grants),null);}
  }
  @Override protected void onActivityResult(int code,int status,Intent data){super.onActivityResult(code,status,data);
    if(code==40&&fileCallback!=null){fileCallback.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(status,data));fileCallback=null;}
    if(code==41&&exportRequestId!=null){final String id=exportRequestId;final byte[] bytes=exportBytes;exportRequestId=null;exportBytes=null;
      worker.execute(()->{JSONObject reply=new JSONObject();try{
        if(status!=RESULT_OK||data==null)throw new IOException("已取消文件保存");
        try(OutputStream out=getContentResolver().openOutputStream(data.getData())){if(out==null)throw new IOException("无法创建文件");out.write(bytes);}
        reply.put("ok",true).put("saved",true);
      }catch(Exception e){try{reply.put("error",e.getMessage()).put("code","EXPORT_FAILED");}catch(JSONException ignored){}}result(id,reply);});
    }
  }
  @Override protected void onPause(){trace("ACTIVITY_PAUSE","Releasing notes",null);paused=true;stopNotes();event("paused",payload(session,"已切到后台，释放按键","PAUSED",""));super.onPause();}
  @Override protected void onResume(){super.onResume();paused=false;trace("ACTIVITY_RESUME","",null);}
  @Override protected void onDestroy(){trace("ACTIVITY_DESTROY","Closing transport",null);destroyed=true;if(cameraRequest!=null){cameraRequest.deny();cameraRequest=null;}session="";stopNotes();closeSocket();worker.shutdownNow();networkWorker.shutdownNow();if(web!=null){web.removeJavascriptInterface("PianoAndroid");web.destroy();web=null;}super.onDestroy();}
  @Override public void onBackPressed(){js("document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape'}))");}
}
