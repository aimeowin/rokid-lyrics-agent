<script def>
{
  "navigationBarTitleText": "Lyrics",
  "description": "Synced lyrics for the song playing on the user's Spotify. Use when the user asks for lyrics or what's playing. Shows previous, current and next lyric line in real time."
}
</script>

<script setup>
const API_BASE = 'https://rokid-lyrics.vercel.app';
const AGENT_TOKEN = 'cb71ac5a3f0de2ffcf93adae7b83e5caccae709707774945511081f6f5a0fecf';
const POLL_MS = 4000;
const TICK_MS = 300;

// ---- helpers (kept inline: no extra module files to import) ----
function currentIndex(lines, progressMs) {
  if (!lines || !lines.length || progressMs < lines[0].t_ms) return -1;
  let lo = 0;
  let hi = lines.length - 1;
  while (lo < hi) {
    const mid = Math.floor((lo + hi + 1) / 2);
    if (lines[mid].t_ms <= progressMs) lo = mid; else hi = mid - 1;
  }
  return lo;
}

function interpolate(snap, receivedAt, now) {
  if (!snap || typeof snap.progress_ms !== 'number') return 0;
  if (!snap.is_playing) return snap.progress_ms;
  const p = snap.progress_ms + Math.max(0, now - receivedAt);
  return snap.duration_ms ? Math.min(p, snap.duration_ms) : p;
}

function lineAt(lines, i) {
  if (!lines || i < 0 || i >= lines.length) return '';
  return lines[i].text || '...';
}

function plainPreview(plain) {
  if (!plain) return [];
  const out = [];
  const parts = String(plain).split(String.fromCharCode(10));
  for (let i = 0; i < parts.length && out.length < 3; i++) {
    const s = parts[i].trim();
    if (s) out.push(s);
  }
  return out;
}

function errText(e) {
  return e && e.message ? e.message : String(e);
}

export default {
  pollTimer: null,
  tickTimer: null,
  snap: null,
  receivedAt: 0,
  lastIdx: -2,
  curMode: 'loading',

  data: {
    title: '',
    artist: '',
    prev: '',
    cur: 'Loading…',
    next: '',
    mode: 'loading',
    plain: [],
    paused: false,
    status: 'Connecting…'
  },

  onLoad() {
    this.poll();
    this.start();
  },
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
    try {
      const response = await fetch(API_BASE + '/api/now', {
        headers: { Authorization: 'Bearer ' + AGENT_TOKEN },
        timeout: 6000
      });
      if (response.status === 401) {
        this.setData({ status: 'Error: bad token (401)' });
        return;
      }
      if (!response.ok) {
        this.setData({ status: 'Error: HTTP ' + response.status });
        return;
      }
      const d = await response.json();
      this.apply(d, Date.now());
    } catch (e) {
      this.setData({ status: 'Offline: ' + errText(e) });
    }
  },

  apply(d, now) {
    try {
      this.snap = d;
      this.receivedAt = now;
      this.lastIdx = -2;
      this.curMode = 'msg';
      if (d.error === 'not_logged_in') {
        this.setData({ mode: 'msg', title: '', artist: '', prev: '', cur: 'Spotify not connected', next: 'Open /api/login once', status: '' });
        return;
      }
      if (d.error) {
        this.setData({ status: 'Server: ' + d.error });
        return;
      }
      if (!d.track) {
        this.setData({ mode: 'msg', title: '', artist: '', prev: '', cur: 'Nothing playing', next: '', paused: false, status: d.mock ? 'demo' : '' });
        return;
      }
      const hasLines = d.lines && d.lines.length > 0;
      const mode = hasLines ? 'synced' : (d.plain ? 'plain' : 'msg');
      this.curMode = mode;
      this.setData({
        title: d.track,
        artist: d.artist || '',
        paused: !d.is_playing,
        mode: mode,
        plain: mode === 'plain' ? plainPreview(d.plain) : [],
        status: d.mock ? 'demo' : ''
      });
      if (mode === 'msg') {
        this.setData({ prev: '', cur: 'No synced lyrics', next: d.track });
      }
      this.tick();
    } catch (e) {
      this.setData({ status: 'Render error: ' + errText(e) });
    }
  },

  tick() {
    try {
      const d = this.snap;
      if (!d) { this.setData({ status: 'dbg: no snap' }); return; }
      const pm = interpolate(d, this.receivedAt, Date.now());
      const idx = currentIndex(d.lines, pm);
      this.setData({ status: 'dbg ' + this.curMode + ' i=' + idx + ' t=' + Math.round(pm/1000) + 's n=' + (d.lines ? d.lines.length : -1) });
      if (this.curMode !== 'synced') return;
      if (idx === this.lastIdx) return;
      this.lastIdx = idx;
      if (idx < 0) {
        this.setData({ prev: '', cur: '...', next: lineAt(d.lines, 0) });
      } else {
        this.setData({ prev: lineAt(d.lines, idx - 1), cur: lineAt(d.lines, idx), next: lineAt(d.lines, idx + 1) });
      }
    } catch (e) {
      this.setData({ status: 'Tick error: ' + errText(e) });
    }
  },

  onKeyUp(event) {
    if (event.code === 'Enter' || event.code === 'GlobalHook') this.poll();
  }
};
</script>

<page>
  <view class="card">
    <text class="title" ink:if="{{ title }}">{{ title }}</text>
    <text class="meta" ink:if="{{ title }}">{{ artist }}{{ paused ? ' · Paused' : '' }}</text>

    <view class="lyrics" ink:if="{{ mode == 'plain' }}">
      <text class="note">No synced lyrics</text>
      <text class="plain" ink:for="{{ plain }}" ink:key="*this">{{ item }}</text>
    </view>
    <view class="lyrics" ink:else>
      <text class="prev">{{ prev }}</text>
      <text class="{{ paused ? 'cur dim' : 'cur' }}">{{ cur }}</text>
      <text class="next">{{ next }}</text>
    </view>

    <text class="status" ink:if="{{ status }}">{{ status }}</text>
  </view>
</page>

<style>
.card { display: flex; flex-direction: column; padding: 12px; }
.title { color: #40FF5E; font-size: 16px; line-height: 20px; opacity: 0.8; }
.meta { color: #40FF5E; font-size: 13px; line-height: 16px; opacity: 0.55; margin-bottom: 10px; }
.lyrics { display: flex; flex-direction: column; }
.prev { color: #40FF5E; font-size: 18px; line-height: 24px; opacity: 0.4; }
.cur { color: #40FF5E; font-size: 26px; line-height: 32px; margin-top: 6px; margin-bottom: 6px; }
.dim { opacity: 0.6; }
.next { color: #40FF5E; font-size: 18px; line-height: 24px; opacity: 0.55; }
.note { color: #40FF5E; font-size: 14px; line-height: 18px; opacity: 0.6; }
.plain { color: #40FF5E; font-size: 18px; line-height: 24px; }
.status { color: #40FF5E; font-size: 12px; line-height: 16px; opacity: 0.5; margin-top: 8px; }
</style>
