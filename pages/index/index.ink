<script def>
{
  "navigationBarTitleText": "Lyrics",
  "description": "Synced lyrics for the song playing on the user's Spotify. Use when the user asks for lyrics or what's playing. Shows previous, current and next lyric line in real time.",
  "schema": { "data": { "type": "object", "properties": {} } }
}
</script>

<script setup>
// inlined helpers
// Pure helpers shared by the agent page (and mirrored in backend/lib/lrc.js).

/** Index of the line being sung at progressMs, or -1 before the first line. Lines sorted by t_ms. */
function currentIndex(lines, progressMs) {
  if (!lines || !lines.length || progressMs < lines[0].t_ms) return -1;
  let lo = 0, hi = lines.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (lines[mid].t_ms <= progressMs) lo = mid; else hi = mid - 1;
  }
  return lo;
}

/** Estimated playback position now, given a server snapshot received at receivedAt (local ms). */
function interpolate(snap, receivedAt, now) {
  if (!snap || snap.progress_ms == null) return 0;
  if (!snap.is_playing) return snap.progress_ms;
  const p = snap.progress_ms + Math.max(0, now - receivedAt);
  return snap.duration_ms ? Math.min(p, snap.duration_ms) : p;
}

/** The three lines to show: { prev, cur, next } (strings, '' when missing). */
function windowAt(lines, idx) {
  const at = (i) => (lines && i >= 0 && i < lines.length ? lines[i].text || '♪' : '');
  if (idx < 0) return { prev: '', cur: '♪', next: at(0) };
  return { prev: at(idx - 1), cur: at(idx), next: at(idx + 1) };
}

/** First few non-empty plain-lyric lines for the fallback view. */
function plainPreview(plain, n = 3) {
  return (plain || '').split('
').map((s) => s.trim()).filter(Boolean).slice(0, n);
}


// TODO: set to your Vercel deployment URL (domain must be on the AIUI allowlist before publishing).
const API_BASE = 'https://rokid-lyrics.vercel.app';
// TODO: same value as AGENT_TOKEN on Vercel. Anyone holding the .aix can read it, so keep the AIX private.
const AGENT_TOKEN = 'cb71ac5a3f0de2ffcf93adae7b83e5caccae709707774945511081f6f5a0fecf';
const POLL_MS = 4000;
const TICK_MS = 250;

export default {
  pollTimer: null,
  tickTimer: null,
  snap: null,
  receivedAt: 0,
  data: {
    title: '', artist: '', prev: '', cur: 'Loading…', next: '',
    mode: 'loading', // loading | synced | plain | none | idle | error
    plain: [], paused: false, demo: false, lastIdx: -2
  },

  onLoad() { this.poll(); },
  onShow() { this.start(); },
  onHide() { this.stop(); },
  onUnload() { this.stop(); },

  start() {
    this.stop();
    this.pollTimer = setInterval(() => this.poll(), POLL_MS);
    this.tickTimer = setInterval(() => this.tick(), TICK_MS);
  },
  stop() {
    if (this.pollTimer) { clearInterval(this.pollTimer); this.pollTimer = null; }
    if (this.tickTimer) { clearInterval(this.tickTimer); this.tickTimer = null; }
  },

  async poll() {
    const ctrl = new AbortController();
    const to = setTimeout(() => ctrl.abort(), 6000);
    try {
      const r = await fetch(`${API_BASE}/api/now`, {
        headers: { Authorization: `Bearer ${AGENT_TOKEN}` }, signal: ctrl.signal
      });
      if (r.status === 401) throw new Error('Bad token');
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      this.apply(await r.json(), Date.now());
    } catch (e) {
      // Keep showing interpolated lyrics on a transient failure; only show an error if we have nothing.
      if (!this.snap) this.setData({ mode: 'error', cur: e.message === 'Bad token' ? 'Check token' : 'Offline – retrying', prev: '', next: '' });
    } finally { clearTimeout(to); }
  },

  apply(d, now) {
    this.snap = d;
    this.receivedAt = now;
    if (d.error === 'not_logged_in') {
      this.setData({ mode: 'error', title: '', artist: '', prev: '', cur: 'Spotify not connected', next: 'Open /api/login once' });
      return;
    }
    if (!d.track) {
      this.setData({ mode: 'idle', title: '', artist: '', prev: '', cur: 'Nothing playing', next: '', paused: false, demo: !!d.mock });
      return;
    }
    const mode = d.lines && d.lines.length ? 'synced' : d.plain ? 'plain' : 'none';
    this.setData({ title: d.track, artist: d.artist || '', paused: !d.is_playing, demo: !!d.mock, mode,
      plain: mode === 'plain' ? plainPreview(d.plain) : [], lastIdx: -2 });
    if (mode === 'none') this.setData({ prev: '', cur: 'No synced lyrics', next: d.track });
    this.tick();
  },

  tick() {
    const d = this.snap;
    if (!d || this.data.mode !== 'synced') return;
    const idx = currentIndex(d.lines, interpolate(d, this.receivedAt, Date.now()));
    if (idx === this.data.lastIdx) return; // avoid redundant renders
    this.setData({ ...windowAt(d.lines, idx), lastIdx: idx });
  },

  onKeyUp(event) {
    if (event.code === 'Enter' || event.code === 'GlobalHook') this.poll();
  }
};
</script>

<page>
  <view class="card">
    <view class="head" ink:if="{{ title }}">
      <text class="title">{{ title }}</text>
      <text class="meta">{{ artist }}{{ paused ? ' · Paused' : '' }}{{ demo ? ' · demo' : '' }}</text>
    </view>

    <view class="lyrics" ink:if="{{ mode !== 'plain' }}">
      <text class="prev">{{ prev }}</text>
      <text class="cur {{ paused ? 'dim' : '' }}">{{ cur }}</text>
      <text class="next">{{ next }}</text>
    </view>

    <view class="lyrics" ink:if="{{ mode === 'plain' }}">
      <text class="note">No synced lyrics</text>
      <text class="plain" ink:for="{{ plain }}" ink:key="*this">{{ item }}</text>
    </view>
  </view>
</page>

<style>
.card { padding: 12px; color: #40FF5E; }
.head { margin-bottom: 10px; }
.title { font-size: 16px; opacity: 0.8; }
.meta { font-size: 13px; opacity: 0.55; }
.lyrics { display: flex; flex-direction: column; }
.prev { font-size: 18px; line-height: 24px; opacity: 0.4; min-height: 24px; }
.cur { font-size: 26px; line-height: 32px; font-weight: bold; margin: 6px 0; }
.cur.dim { opacity: 0.6; }
.next { font-size: 18px; line-height: 24px; opacity: 0.55; min-height: 24px; }
.note { font-size: 14px; opacity: 0.6; margin-bottom: 4px; }
.plain { font-size: 18px; line-height: 24px; }
</style>
