// Called once a day by the Vercel cron in vercel.json. Free Supabase projects pause after about a
// week with no activity; this small read keeps the database awake. Same URL and key as config.js.
const SUPABASE_URL = 'https://egvtfnlovdhawjyefvll.supabase.co';
const SUPABASE_KEY = 'sb_publishable_xhvjY_YEIuQ7m0vH0ueUpg_FtUBDvYV';

module.exports = async (req, res) => {
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/santa_status`, {
      method: 'POST',
      headers: { apikey: SUPABASE_KEY, 'Content-Type': 'application/json' },
      body: '{}'
    });
    res.status(r.ok ? 200 : 502).json({ ok: r.ok, status: r.status, at: new Date().toISOString() });
  } catch (e) {
    res.status(502).json({ ok: false, error: String(e) });
  }
};
