import test from 'node:test';
import assert from 'node:assert/strict';
import {buildTimeline,RhythmRun,calibrationResult} from '../public/rhythm.js';
import {DEFAULT_NOTES,SONGS} from '../public/core.js';
const create=(score=[{note:60,beats:1},{note:64,beats:2}],bpm=60)=>new RhythmRun(buildTimeline(score,bpm,DEFAULT_NOTES));
test('tempo changes both onset and sustain durations, not just visuals',()=>{
  const a=buildTimeline(SONGS[0].score,80,DEFAULT_NOTES),b=buildTimeline(SONGS[0].score,40,DEFAULT_NOTES);
  assert.equal(b[7].on,a[7].on*2);assert.equal(b[6].end,b[6].on+3000);assert.equal(a[0].pad,12);
});
test('four lanes map to physical columns, with stable source bar indices',()=>{
  const n=buildTimeline(SONGS[0].score,80,DEFAULT_NOTES,{from:3,to:4});
  assert.equal(n[0].on,0);assert.equal(n[0].bar,3);assert.ok(n.every(e=>e.bar>=3&&e.bar<=4));
  assert.equal(buildTimeline([{note:67,beats:1}],80,DEFAULT_NOTES)[0].pad%4,3);
});
test('on-time, early and late presses are distinct',()=>{
  for(const [time,kind] of [[0,'perfect'],[-90,'perfect'],[90,'perfect'],[-91,'early'],[220,'late']]){
    const r=create();assert.equal(r.press(60,time).kind,kind);
  }
});
test('wrong pitch does not consume a correct note and repeated presses cannot farm combo',()=>{
  const r=create();assert.equal(r.press(61,0).kind,'wrong');assert.equal(r.notes[0].status,'pending');
  r.press(60,10);r.press(60,20);assert.equal(r.result().played,1);assert.equal(r.result().wrong,2);assert.equal(r.maxCombo,1);
});
test('no input leads to misses and a zero score',()=>{
  const r=create();r.advance(4000);const s=r.result();assert.equal(s.miss,2);assert.equal(s.timing,0);assert.equal(s.pitch,0);
});
test('expired note cannot be retroactively hit',()=>{
  const r=create();assert.equal(r.press(60,221).kind,'wrong');assert.equal(r.notes[0].status,'miss');
});
test('a long note requires holding to its tail',()=>{
  const r=create();r.press(60,0);r.press(64,1000);assert.equal(r.notes[1].status,'holding');
  r.release(64,1800);assert.equal(r.notes[1].status,'broken');assert.equal(r.result().held,0);assert.equal(r.combo,0);
});
test('hold release tolerance and automatic tail completion',()=>{
  const a=create();a.press(64,1000);a.release(64,2860);assert.equal(a.result().held,1);
  const b=create();b.press(64,1000);b.advance(3000);assert.equal(b.result().held,1);b.release(64,3200);assert.equal(b.combo,1);
});
test('rewinding a measure rolls back its scores but preserves earlier results',()=>{
  const r=create([{note:60,beats:1},{note:64,beats:1},{note:67,beats:1}]);
  r.press(60,0);r.press(61,1100);r.advance(1500);r.press(67,2000);r.rewind(1000);
  assert.equal(r.notes[0].status,'hit');assert.equal(r.notes[1].status,'pending');assert.equal(r.notes[2].status,'pending');
  assert.equal(r.wrong.length,0);assert.equal(r.maxCombo,1);assert.equal(r.result().judged,1);
});
test('aborting before first note does not fabricate grades for unplayed future notes',()=>{
  const r=create();r.advance(-500);assert.equal(r.result().judged,0);assert.equal(r.result().timing,0);
});
test('timing accuracy includes misses and pitch accuracy includes wrong inputs',()=>{
  const r=create([{note:60,beats:1},{note:64,beats:1},{note:67,beats:1}]);
  r.press(60,0);r.press(64,1150);r.press(61,1600);r.advance(3000);
  assert.equal(r.result().timing,33);assert.equal(r.result().pitch,50);assert.equal(r.result().weak.from,1);
});
test('compensated late input is valid until the compensated deadline',()=>{
  const r=create(),offset=150;r.advance(300-offset);assert.equal(r.notes[0].status,'pending');
  assert.equal(r.press(60,300-offset).kind,'late');
});
test('latency calibration requires enough stable samples and resists outliers',()=>{
  assert.equal(calibrationResult([10,15]),null);
  assert.equal(calibrationResult([80,85,90,92,94,100,102,270]),94);
  assert.equal(calibrationResult([-250,-230,-200,-180,180,200,230,250]),null);
});
test('Ode to Joy phrase durations align to 4/4 bars',()=>{
  assert.equal(SONGS[1].score.slice(0,15).reduce((a,n)=>a+n.beats,0),16);
  assert.equal(SONGS[1].score.reduce((a,n)=>a+n.beats,0),32);
});
