-- patched-to-ring.sql
-- Passes when the laptop is fully upgraded to its ring's snapshot date (0 pending updates),
-- confirmed within the last 2 days. The patching role writes /etc/zt/patch-compliant only
-- when nothing is left to install, and removes it otherwise.
-- This is the PATCH COMPLIANCE measure: "did the laptop install what its ring allows?"
SELECT 1 FROM file
WHERE path = '/etc/zt/patch-compliant'
  AND mtime > (CAST(strftime('%s','now') AS INTEGER) - 172800);
