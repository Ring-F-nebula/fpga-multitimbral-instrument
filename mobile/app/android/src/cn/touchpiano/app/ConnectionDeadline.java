package cn.touchpiano.app;

/** Resolves the race between connect returning and its scheduled close. */
final class ConnectionDeadline {
  private enum State { PENDING, COMPLETE, EXPIRED }
  private State state=State.PENDING;
  synchronized boolean complete(){
    if(state==State.EXPIRED)return false;
    state=State.COMPLETE;return true;
  }
  synchronized boolean expire(){
    if(state!=State.PENDING)return false;
    state=State.EXPIRED;return true;
  }
}
