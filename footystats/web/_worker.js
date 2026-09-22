const SHARE_OG =
  'https://dcpltazuzyyhxtkpbuiu.supabase.co/functions/v1/share';

const CRAWLER =
  /WhatsApp|facebookexternalhit|Facebot|Twitterbot|Slackbot|TelegramBot|Discordbot|LinkedInBot|Pinterest|Googlebot|bingbot|Applebot|Iframely|Embedly|SkypeUriPreview|vkShare|redditbot|Slack-ImgProxy/i;

function videoIdFrom(url) {
  const fromQuery = url.searchParams.get('v') || url.searchParams.get('video');
  if (fromQuery) return fromQuery;
  const match = url.pathname.match(
    /\/v\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i,
  );
  return match ? match[1] : '';
}

function isCrawler(request) {
  return CRAWLER.test(request.headers.get('User-Agent') || '');
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.searchParams.get('play') === '1') {
      return passThrough(request, env);
    }
    const videoId = videoIdFrom(url);
    if (videoId && isCrawler(request)) {
      return fetch(`${SHARE_OG}?v=${encodeURIComponent(videoId)}&og=1`);
    }
    return passThrough(request, env);
  },
};

function passThrough(request, env) {
  if (env && env.ASSETS) {
    return env.ASSETS.fetch(request);
  }
  return fetch(request);
}
