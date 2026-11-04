package cn.touchpiano.app;
public final class ConnectionDeadlineTest {
  static void check(boolean condition){if(!condition)throw new AssertionError("deadline race");}
  public static void main(String[] args)throws Exception{
    ConnectionDeadline success=new ConnectionDeadline();check(success.complete());check(!success.expire());
    ConnectionDeadline timeout=new ConnectionDeadline();check(timeout.expire());check(!timeout.complete());check(!timeout.expire());
    for(int n=0;n<1000;n++){
      ConnectionDeadline race=new ConnectionDeadline();boolean[] won=new boolean[2];
      Thread a=new Thread(()->won[0]=race.complete());Thread b=new Thread(()->won[1]=race.expire());
      a.start();b.start();a.join();b.join();check(won[0]!=won[1]);check(!race.expire());
    }
    System.out.println("PASS deadline: completed connections cannot expire; expired attempts cannot succeed; 1000 concurrent races");
  }
}
