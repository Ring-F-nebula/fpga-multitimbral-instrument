package cn.touchpiano.app;

import java.net.URL;
import java.net.URI;
import javax.net.ssl.HttpsURLConnection;
import java.io.*;
import java.net.SocketTimeoutException;
import java.util.concurrent.TimeUnit;

/** Text scores only. Never load downloaded pages/scripts into the privileged WebView. */
public final class ScoreDownload {
  public static final int MAX_BYTES=1048576;
  public static URL checked(String value) throws Exception {
    URI uri=new URI(value);
    if(!"https".equalsIgnoreCase(uri.getScheme())||uri.getHost()==null||uri.getUserInfo()!=null||uri.getFragment()!=null)
      throw new IOException("请使用不带账号密码的HTTPS曲谱地址");
    return uri.toURL();
  }
  public static String fetch(String address) throws Exception {
    URL url=checked(address);
    long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(10);
    for(int redirect=0;redirect<4;redirect++){
      HttpsURLConnection c=(HttpsURLConnection)url.openConnection();c.setInstanceFollowRedirects(false);
      c.setConnectTimeout(Math.min(5000,remainingMillis(deadline)));c.setReadTimeout(Math.min(5000,remainingMillis(deadline)));c.setRequestProperty("Accept","application/json,application/xml,text/xml,text/plain");
      try {
        int status=c.getResponseCode();
        if(status>=300&&status<400){String location=c.getHeaderField("Location");if(location==null)throw new IOException("下载重定向缺少地址");url=checked(new URL(url,location).toString());continue;}
        if(status!=200)throw new IOException("曲谱下载失败，HTTP "+status);
        if(c.getContentLengthLong()>MAX_BYTES)throw new IOException("曲谱不能超过1MB");
        ByteArrayOutputStream out=new ByteArrayOutputStream();
        try(InputStream in=c.getInputStream()){byte[] data=new byte[4096];int count;while(true){c.setReadTimeout(Math.min(5000,remainingMillis(deadline)));count=in.read(data);if(count==-1)break;if(out.size()+count>MAX_BYTES)throw new IOException("曲谱不能超过1MB");out.write(data,0,count);}}
        return new String(out.toByteArray(),"UTF-8");
      } finally {c.disconnect();}
    }
    throw new IOException("曲谱下载重定向过多");
  }
  static int remainingMillis(long deadline) throws SocketTimeoutException {
    long left=deadline-System.nanoTime();if(left<=0)throw new SocketTimeoutException("曲谱下载超时");
    return (int)Math.max(1,Math.min(Integer.MAX_VALUE,TimeUnit.NANOSECONDS.toMillis(left)));
  }
}
