-- ansible-pull-alive.sql
-- Passes when ansible-pull has completed successfully (rc=0) in the last 2 hours.
-- The wrapper touches /etc/zt/ansible-last-ok only on success, so this one file covers
-- "timer running", "network/GitHub reachable" and "playbook not erroring".
-- No automation: a failure here needs a person (network, repo, or playbook problem).
SELECT 1 FROM file
WHERE path = '/etc/zt/ansible-last-ok'
  AND mtime > (CAST(strftime('%s','now') AS INTEGER) - 7200);
