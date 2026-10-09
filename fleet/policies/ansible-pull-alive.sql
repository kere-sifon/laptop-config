-- ansible-pull-alive.sql
-- Passes when the ansible-pull timer has checked Git in the last 2 hours with rc=0.
-- Failing means: timer stopped, no network, Git unreachable, or the playbook is erroring.
-- Pair with automation: Run script > bootstrap/install-ansible-pull.sh (reinstalls the timer).
SELECT 1
FROM file_lines AS l
JOIN file AS f ON f.path = l.path
WHERE l.path = '/etc/zt/ansible-last-check'
  AND l.line = 'rc=0'
  AND f.mtime > (strftime('%s','now') - 7200);
