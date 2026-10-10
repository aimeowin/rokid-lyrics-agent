<script def>
{
  "navigationBarTitleText": "Lyrics"
}
</script>

<script setup>
const API_BASE = 'https://rokid-lyrics.vercel.app';
const AGENT_TOKEN = 'cb71ac5a3f0de2ffcf93adae7b83e5caccae709707774945511081f6f5a0fecf';

export default {
  data: {
    title: 'Lyrics agent (minimal test)',
    status: 'Fetching…'
  },

  async onLoad() {
    try {
      const response = await fetch(API_BASE + '/api/now', {
        headers: { Authorization: 'Bearer ' + AGENT_TOKEN },
        timeout: 6000
      });
      const text = await response.text();
      this.setData({ status: 'HTTP ' + response.status + ': ' + text.slice(0, 80) });
    } catch (error) {
      this.setData({ status: 'Error: ' + (error && error.message ? error.message : String(error)) });
    }
  }
};
</script>

<page>
  <view class="container">
    <text class="title">{{ title }}</text>
    <text class="status">{{ status }}</text>
  </view>
</page>

<style>
.container { display: flex; flex-direction: column; padding: 12px; }
.title { color: #40FF5E; font-size: 22px; line-height: 26px; margin-bottom: 10px; }
.status { color: #40FF5E; font-size: 16px; line-height: 20px; opacity: 0.8; }
</style>
