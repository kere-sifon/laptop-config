# laptop-config

Desired state for Celestica Ubuntu laptops, applied by **ansible-pull**: each laptop pulls this
repo over HTTPS and runs `local.yml` against itself. No SSH, no inbound ports, no control server.

```
laptop (systemd timer, every 30 min) --HTTPS--> this repo
      └── ansible-pull runs local.yml locally
            ├── role base       packages, login banner, markers
            └── role patching   apt snapshot pin per ring (off until patching_enabled: true)
```

## Layout
| Path | What it is |
|---|---|
| `local.yml` | Playbook ansible-pull runs |
| `group_vars/all.yml` | Settings: `patching_enabled`, ring snapshot dates, base packages |
| `roles/base` | Always-on baseline; writes `/etc/zt/ansible-state.json` |
| `roles/patching` | Snapshot pin + upgrade; writes `/etc/zt/patch-state.json` |
| `bootstrap/install-ansible-pull.sh` | One-time install of ansible-core, wrapper, service, timer |
| `fleet/policies/ansible-pull-installed.sql` | Fleet policy: timer present; automation installs it if missing |
| `fleet/policies/ansible-pull-alive.sql` | Fleet policy: timer alive and last run succeeded |

## Lab setup (zt-lab)
1. Create a **public** repo on GitHub named `laptop-config` and push this folder to it.
   Public is fine for the lab: there are no secrets here. Production uses a private repo plus
   a read-only deploy token.
2. Edit `DEFAULT_REPO` at the top of `bootstrap/install-ansible-pull.sh` to your repo URL.
3. Install it, either way:
   - **Fleet (preferred):** Controls > Scripts > upload `install-ansible-pull.sh`, then run it on zt-lab.
     To make it automatic for every new or rebuilt laptop, add `fleet/policies/ansible-pull-installed.sql`
     as a policy with the Run script automation set to `install-ansible-pull.sh`.
   - **By hand:** `sudo bash install-ansible-pull.sh`
4. A few minutes later: `cat /etc/zt/ansible-state.json /etc/zt/ansible-last-check`

## Tests, simplest first
| Test | Do | Expect |
|---|---|---|
| 1. First pull | Bootstrap (step 2) | `ansible-state.json` shows the commit; `htop` installed; banner on next login |
| 2. Change flows from Git | Add `tree` to `base_packages`, commit, push | Within ~35 min `tree` is installed (or force: `sudo systemctl start zt-ansible-pull`) |
| 3. No-op when unchanged | Start the service twice with no new commit | Second run skips the playbook; `ansible-last-check` still updates |
| 4. Drift repair | `sudo apt remove -y htop`, then delete `/var/lib/zt/ansible-last-full` and start the service | htop comes back |
| 5. Fleet sees it | Add `fleet/policies/ansible-pull-alive.sql` as a policy | zt-lab passes; stop the timer and it fails after 2h |
| 6. Patching | Set `patching_enabled: true`, push | `/etc/apt/apt.conf.d/50zt-snapshot` appears, `patch-state.json` written |

## Notes
- `--only-if-changed` keeps frequent runs cheap; a full run once a day repairs local drift.
- The patching role never reboots. It records `reboot_required` for Fleet to report.
- Every commit to `main` reaches every laptop. Protect the branch, require review, and add
  `--verify-commit` to the wrapper once commits are signed.
