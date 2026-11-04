package cn.touchpiano.app;
import java.io.IOException;
import java.util.*;
public final class SppConnectorTest {
  static int passed=0;
  static void check(boolean condition,String description){if(!condition)throw new AssertionError(description);}
  static class FakeSocket implements SppConnector.Socket {
    boolean failed,connected,closed;Runnable onConnect=()->{};
    FakeSocket(boolean failed){this.failed=failed;}
    public void connect() throws IOException {onConnect.run();if(failed)throw new IOException("read failed, socket might closed or timeout, read ret: -1");connected=true;}
    public void close(){closed=true;}
  }
  static class Env implements SppConnector.Environment {
    List<Boolean> modes=new ArrayList<>();List<FakeSocket> sockets=new ArrayList<>();boolean cancel=false,fail=false;int pauses=0;
    public SppConnector.Socket create(boolean compatibility){modes.add(compatibility);FakeSocket s=new FakeSocket(fail);sockets.add(s);return s;}
    public void beforeAttempt(){}
    public void progress(String message){}
    public void pause(){pauses++;}
    public boolean cancelled(){return cancel;}
  }
  public static void main(String[] args)throws Exception{
    Env original=new Env();FakeSocket good=(FakeSocket)SppConnector.connect(original);
    check(good.connected&&!good.closed&&original.modes.equals(Arrays.asList(false)),"default uses original authenticated SPP only");passed++;
    Env manual=new Env();good=(FakeSocket)SppConnector.connect(manual,true);
    check(good.connected&&!good.closed&&manual.modes.equals(Arrays.asList(true)),"compatible mode requires explicit selection");passed++;
    Env failure=new Env();failure.fail=true;
    try{SppConnector.connect(failure);throw new AssertionError("expected failure");}catch(IOException e){check(e.getMessage().contains("SPP_CONNECT_FAILED")&&e.getMessage().contains("read ret: -1"),"native error retained");}
    check(failure.sockets.size()==1&&failure.sockets.get(0).closed&&failure.pauses==0,"no automatic mode switch after failure");passed++;
    Env compatFailure=new Env();compatFailure.fail=true;
    try{SppConnector.connect(compatFailure,true);throw new AssertionError("expected failure");}catch(IOException expected){}
    check(compatFailure.modes.equals(Arrays.asList(true))&&compatFailure.sockets.get(0).closed,"manual compatibility failure cleaned up without fallback");passed++;
    Env cancelled=new Env();cancelled.cancel=true;try{SppConnector.connect(cancelled);throw new AssertionError("expected cancel");}catch(IOException expected){}check(cancelled.sockets.isEmpty(),"cancel before allocation");passed++;
    Env during=new Env(){public SppConnector.Socket create(boolean c){FakeSocket s=(FakeSocket)super.create(c);s.onConnect=()->cancel=true;return s;}};
    try{SppConnector.connect(during);throw new AssertionError("expected cancel");}catch(IOException expected){}check(during.sockets.size()==1&&during.sockets.get(0).closed,"cancel during connect closes candidate");passed++;
    Env auto=new Env();good=(FakeSocket)SppConnector.connect(auto,"auto");
    check(auto.modes.equals(Arrays.asList(false))&&good.connected&&!good.closed&&auto.pauses==0,"standard success is not replaced");passed++;
    Env retry=new Env(){public SppConnector.Socket create(boolean c){fail=!c;return super.create(c);}};
    good=(FakeSocket)SppConnector.connect(retry,"auto");
    check(retry.modes.equals(Arrays.asList(false,true))&&retry.sockets.get(0).closed&&!good.closed&&retry.pauses==1,"failed candidate closed before compatibility fallback");passed++;
    Env both=new Env();both.fail=true;
    try{SppConnector.connect(both,"auto");throw new AssertionError("expected both failures");}catch(IOException e){
      check(e.getMessage().contains("compatibility=[")&&e.getMessage().contains("standard=[")&&e.getSuppressed().length==1,"both errors retained");}
    check(both.sockets.size()==2&&both.sockets.stream().allMatch(s->s.closed),"all failed candidates closed");passed++;
    Env cancelBetween=new Env(){public void pause(){super.pause();cancel=true;}};cancelBetween.fail=true;
    try{SppConnector.connect(cancelBetween,"auto");throw new AssertionError("expected cancel");}catch(IOException expected){}
    check(cancelBetween.sockets.size()==1&&cancelBetween.sockets.get(0).closed,"cancel during delay prevents fallback");passed++;
    Env cancelConnect=new Env(){public SppConnector.Socket create(boolean c){FakeSocket s=(FakeSocket)super.create(c);s.onConnect=()->cancel=true;return s;}};
    try{SppConnector.connect(cancelConnect,"auto");throw new AssertionError("expected cancel");}catch(IOException expected){}
    check(cancelConnect.sockets.size()==1&&cancelConnect.sockets.get(0).closed,"cancelled successful candidate cannot trigger fallback");passed++;
    Env permissions=new Env(){public void beforeAttempt(){throw new SecurityException("permission denied");}};
    try{SppConnector.connect(permissions,"auto");throw new AssertionError("expected permission failure");}catch(SecurityException expected){}
    check(permissions.sockets.isEmpty()&&permissions.pauses==0,"permission error does not retry");passed++;
    Env invalid=new Env();try{SppConnector.connect(invalid,"invalid");throw new AssertionError("expected invalid mode");}catch(IOException expected){}
    check(invalid.sockets.isEmpty(),"unknown mode does not create socket");passed++;
    System.out.println("PASS SPP connector tests="+passed);
  }
}
