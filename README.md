# Lowry Family Secret Santa

A pixel-art Christmas Secret Santa site for the Lowry family.

Live at **https://lowry-secret-santa.vercel.app**

## How it works

- Each person picks their pixel avatar and creates a PIN on their first visit.
- The draw runs automatically the first time anyone logs in. It's one random loop through all 10 people, so everyone gives to one person and receives from one. Nobody gets themselves or their partner.
- After logging in you see who you're buying for, their wish list and the rules (£50 limit).
- Everyone keeps their own wish list, which their Secret Santa can see.
- On Christmas Day (from midnight UK time) the Big Reveal unlocks: an animation of the whole gift loop showing who had who. The database won't release it any earlier.

## Files

| File | What it is |
| --- | --- |
| `index.html` | The whole site: page, pixel art, animations and logic |
| `config.js` | Supabase URL and publishable key (safe to publish) |
| `schema.sql` | Database tables and functions. Run once on a fresh Supabase project |
| `reset.sql` | Wipes PINs, wish lists and the draw, or resets one person's PIN |

## Hosting

- **Site:** Vercel (static files, no build step). Deploy with `npx vercel deploy --prod`.
- **Database:** Supabase (free tier). Free projects pause after about a week without use. A Vercel cron (`vercel.json`) calls `api/keepalive.js` every day at 09:00 UTC to keep it awake. If the site ever says "Could not reach the workshop", restore the project from the Supabase dashboard.
