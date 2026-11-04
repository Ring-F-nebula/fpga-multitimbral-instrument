package cn.touchpiano.app;
public final class ScoreDownloadTest {
  public static void main(String[] args) throws Exception {
    if(!ScoreDownload.checked("https://example.org/score.json").getHost().equals("example.org"))throw new AssertionError();
    for(String value:new String[]{"http://example.org/a","file:///secret","javascript:alert(1)","https://user:pass@example.org/a"}){
      try{ScoreDownload.checked(value);throw new AssertionError("Accepted "+value);}catch(java.io.IOException expected){}
    }
    try{ScoreDownload.remainingMillis(System.nanoTime()-1);throw new AssertionError("Expired deadline accepted");}catch(java.net.SocketTimeoutException expected){}
    int left=ScoreDownload.remainingMillis(System.nanoTime()+1000000000L);if(left<1||left>1000)throw new AssertionError("Bad deadline");
    System.out.println("PASS HTTPS-only score URLs; bounded total network deadline; no embedded credentials or local file schemes");
  }
}
