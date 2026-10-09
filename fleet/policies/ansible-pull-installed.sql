-- ansible-pull-installed.sql
-- Passes when the ansible-pull timer unit exists and is active.
-- Pair with automation: Run script > install-ansible-pull.sh
-- Effect: any host without it (new laptop, freshly rebuilt laptop) fails once and gets it installed.
SELECT 1 FROM systemd_units
WHERE id = 'zt-ansible-pull.timer' AND active_state = 'active';
