-- no-open-security-notices.sql
-- Passes when Ubuntu's OVAL data shows 0 unpatched security notices, checked within 2 days.
-- This is the EXPOSURE measure: it uses today's notices, so a laptop in a later ring can fail
-- here for a few days after a fix is published, until its ring's snapshot date moves past it.
-- Details per host: /etc/zt/usn-state.json (count and OVAL definition IDs).
SELECT 1 FROM file
WHERE path = '/etc/zt/usn-clean'
  AND mtime > (CAST(strftime('%s','now') AS INTEGER) - 172800);
