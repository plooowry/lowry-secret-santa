-- Run in the Supabase SQL editor.

-- Start completely over: clears every PIN, wish list and the draw.
update public.people set pin_hash = null, wishlist = '', gives_to = null;
update public.settings set drawn = false where id = 1;

-- Forgotten PIN for one person (keeps their wish list), e.g. Jane = id 6:
-- update public.people set pin_hash = null where id = 6;

-- Re-do just the draw (keeps PINs and wish lists):
-- update public.people set gives_to = null; update public.settings set drawn = false where id = 1;

-- ids: 1 Patrick, 2 Rebecca, 3 Chris, 4 Lauren, 5 Matthew, 6 Jane, 7 Frances, 8 Billy, 9 Charlotte, 10 Simon
