package cn.touchpiano.app;

import java.io.Closeable;
import java.io.IOException;

/** Retry only failed connection attempts; never replace an established socket. */
final class SppConnector {
  interface Socket extends Closeable { void connect() throws IOException; }
  interface Environment {
    Socket create(boolean compatibility) throws IOException;
    void beforeAttempt() throws IOException;
    void progress(String message);
    void pause() throws IOException;
    boolean cancelled();
  }
  static Socket connect(Environment env) throws IOException {return connect(env,false);}
  static Socket connect(Environment env,String strategy) throws IOException {
    if("standard".equals(strategy))return connect(env,false);
    if("compatibility".equals(strategy))return connect(env,true);
    if(!"auto".equals(strategy))throw new IOException("Unknown connection strategy");
    IOException first;
    // Android's documented authenticated RFCOMM API first; insecure is an explicit fallback.
    try{return connect(env,false);}catch(IOException e){first=e;}
    if(env.cancelled())throw first;
    env.progress("标准串口未建立，正在准备兼容连接（第 2/2 次）…");
    env.pause();
    if(env.cancelled())throw new IOException("Connection cancelled",first);
    try{return connect(env,true);}catch(IOException second){
      IOException combined=new IOException("SPP_CONNECT_FAILED: standard=["+first.getMessage()+
          "]; compatibility=["+second.getMessage()+"]",second);
      combined.addSuppressed(first);throw combined;
    }
  }
  static Socket connect(Environment env,boolean compatibility) throws IOException {
    if(env.cancelled())throw new IOException("Connection cancelled");
    env.beforeAttempt();
    env.progress(compatibility?"正在建立兼容蓝牙串口…":"正在建立标准蓝牙串口…");
    Socket candidate=null;
    try{
      candidate=env.create(compatibility);candidate.connect();
      if(env.cancelled())throw new IOException("Connection cancelled");
      return candidate;
    }catch(IOException e){
      if(candidate!=null)try{candidate.close();}catch(IOException ignored){}
      throw new IOException("SPP_CONNECT_FAILED: "+e.getMessage(),e);
    }
  }
}
