// Timing rules are shared by the live game and deterministic tests.
export const HIT_WINDOW = 220;
export const PERFECT_WINDOW = 90;
export const HOLD_GRACE = 140;

export function buildTimeline(score, bpm, mapping, range = null) {
  let beat = 0;
  const all = score.map((n, id) => {
    const event = { id, midi: n.note, beats: n.beats, beat, bar: Math.floor(beat / 4) + 1,
      on: beat * 60000 / bpm, end: (beat + n.beats) * 60000 / bpm,
      pad: mapping.indexOf(n.note), hold: n.beats > 1, status: 'pending' };
    if (event.pad < 0) throw new Error('音符没有对应触点');
    beat += n.beats;
    return event;
  });
  const selected = range ? all.filter(n => n.bar >= range.from && n.bar <= range.to) : all;
  const origin = selected[0]?.on || 0;
  return selected.map(n => ({ ...n, on: n.on - origin, end: n.end - origin }));
}

export class RhythmRun {
  constructor(notes) {
    this.notes = notes.map(n => ({ ...n }));
    this.wrong = [];
    this.combo = 0;
    this.maxCombo = 0;
    this.last = null;
    this.totalMs = this.notes.at(-1)?.end || 0;
  }
  feedback(kind, at, note = null, delta = null) {
    this.last = { kind, at, note, delta };
    return this.last;
  }
  increment() { this.combo++; this.maxCombo = Math.max(this.maxCombo, this.combo); }
  advance(time) {
    for (const n of this.notes) {
      if (n.status === 'pending' && time > n.on + HIT_WINDOW) {
        n.status = 'miss'; n.resolvedAt = n.on + HIT_WINDOW; this.combo = 0;
        this.feedback('miss', time, n);
      } else if (n.status === 'holding' && time >= n.end) {
        n.status = 'hit'; n.resolvedAt = n.end; this.increment();
        this.feedback('held', time, n);
      }
    }
  }
  press(midi, time) {
    this.advance(time);
    if (time < -HIT_WINDOW || time > this.totalMs + HIT_WINDOW) return null;
    const n = this.notes.filter(n => n.status === 'pending' && n.midi === midi && Math.abs(time - n.on) <= HIT_WINDOW)
      .sort((a, b) => Math.abs(time - a.on) - Math.abs(time - b.on))[0];
    if (!n) {
      this.wrong.push({ time, bar: this.notes.find(n => n.end >= time)?.bar || this.notes.at(-1)?.bar });
      this.combo = 0; return this.feedback('wrong', time);
    }
    n.delta = time - n.on;
    n.grade = Math.abs(n.delta) <= PERFECT_WINDOW ? 'perfect' : n.delta < 0 ? 'early' : 'late';
    n.status = n.hold ? 'holding' : 'hit'; n.resolvedAt = time;
    if (!n.hold) this.increment();
    return this.feedback(n.grade, time, n, n.delta);
  }
  release(midi, time) {
    this.advance(time);
    const n = this.notes.find(n => n.midi === midi && n.status === 'holding');
    if (!n) return null;
    if (time < n.end - HOLD_GRACE) {
      n.status = 'broken'; n.resolvedAt = time; this.combo = 0;
      return this.feedback('broken', time, n);
    }
    n.status = 'hit'; n.resolvedAt = time; this.increment();
    return this.feedback('held', time, n);
  }
  rewind(time) {
    for (const n of this.notes) {
      if (n.on >= time || (n.hold && n.end > time)) {
        n.status = 'pending'; delete n.delta; delete n.grade; delete n.resolvedAt;
      }
    }
    this.wrong = this.wrong.filter(w => w.time < time);
    this.combo = 0; this.maxCombo = 0; this.last = null;
    const ledger = [...this.notes.filter(n => n.status !== 'pending').map(n => ({time:n.resolvedAt, success:n.status==='hit'})),
      ...this.wrong.map(w=>({time:w.time,success:false}))].sort((a,b)=>a.time-b.time);
    for(const e of ledger) { if(e.success)this.increment();else this.combo=0; }
  }
  result() {
    const judged = this.notes.filter(n => n.status !== 'pending');
    const hits = judged.filter(n => n.grade);
    const perfect = hits.filter(n => n.grade === 'perfect').length;
    const miss = judged.filter(n => n.status === 'miss').length;
    const holds = judged.filter(n => n.hold && n.grade);
    const bars = [...new Set(judged.map(n => n.bar))].map(bar => ({
      bar, errors: judged.filter(n => n.bar === bar && (n.grade !== 'perfect' || n.status === 'broken')).length + this.wrong.filter(w=>w.bar===bar).length
    }));
    const weak = bars.sort((a,b)=>b.errors-a.errors||a.bar-b.bar)[0];
    return { total:this.notes.length, judged:judged.length, played:hits.length, perfect,
      early:hits.filter(n=>n.grade==='early').length, late:hits.filter(n=>n.grade==='late').length,
      miss, wrong:this.wrong.length, maxCombo:this.maxCombo,
      timing:judged.length?Math.round(perfect/judged.length*100):0,
      pitch:hits.length+miss+this.wrong.length?Math.round(hits.length/(hits.length+miss+this.wrong.length)*100):0,
      holds:holds.length, held:holds.filter(n=>n.status==='hit').length,
      weak:weak?.errors?{from:weak.bar,to:Math.min(weak.bar+1,this.notes.at(-1)?.bar)}:null };
  }
}

export function calibrationResult(samples) {
  if(samples.length < 6) return null;
  const sorted=[...samples].sort((a,b)=>a-b), median=sorted[Math.floor(sorted.length/2)];
  const spread=[...samples].map(v=>Math.abs(v-median)).sort((a,b)=>a-b)[Math.floor(samples.length/2)];
  return spread <= 90 ? Math.max(-250,Math.min(250,Math.round(median))) : null;
}
