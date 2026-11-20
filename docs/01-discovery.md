# 01 · Discovery (Steps 1–4)

**Goal:** know exactly what you are upgrading and migrating before touching anything: access, code, platform versions, extensions, integrations and Drupal 11 blockers.

**Inputs:** a change ticket, the source repository, read access to the source host.
**Outputs:** an upgrade branch, an inventory, and a blocker list with an owner for each item.

> The example agency (`www.agency.example`, site `drupal11-migration-demo`) is fictional. Replace placeholders with your own values.

---

## Step 1 — Request access

**Why:** missing access is the most common cause of a stalled cutover. Request everything now, even what you will only use on launch day.

| Access | Used for | Typical owner |
|---|---|---|
| Source Git repository (read/write) | Upgrade branch, pull requests | Development lead |
| Source host SSH + Drush | Inventory, backups, final snapshot | Hosting / ops |
| Source database (read) | Consistent dumps, reconciliation | DBA / hosting |
| Drupal admin account | Functional review, status report | Site owner |
| Pantheon organization role (Developer or higher) | Site creation, Terminus, deploys | Pantheon org admin |
| DNS provider | TTL reduction, cutover, rollback | Network / IT |
| CDN / WAF / SSO / SMTP / API consoles | Integration re-pointing | Service owners |
| Change-management system | Approvals, maintenance window | Change manager |

**Expected result:** every row has a named person and a confirmed credential stored in a password manager, not in the repo or ticket.
**Evidence:** access checklist attached to the change ticket.

## Step 2 — Clone the source and create an upgrade branch

```bash
git clone git@github.com:ORG/REPO.git source-drupal
cd source-drupal
git log -1 --format='%H %ad %s'            # record the baseline commit
git switch -c upgrade/drupal11-pantheon
../drupal10-to-drupal11-pantheon-migration/scripts/check-requirements.sh
```

**Expected result:** a clean working tree on `upgrade/drupal11-pantheon`, and `check-requirements.sh` reports no FAIL lines.
**Evidence:** baseline commit hash and the requirements output.

## Step 3 — Inventory platform, extensions and integrations

Run these on the source host (or later in DDEV once Step 6 is done):

```bash
composer validate
composer show drupal/core drush/drush
php -v
./vendor/bin/drush status
./vendor/bin/drush sql:query 'SELECT VERSION()'
./vendor/bin/drush pm:list --status=enabled --type=module --no-core --format=csv > inventory-contrib.csv
./vendor/bin/drush pm:list --status=enabled --type=theme --format=csv > inventory-themes.csv
./vendor/bin/drush config:get system.file
./vendor/bin/drush status --fields=files,private,temp
grep -nE "^\s*\\\$(settings|config|databases)\[" web/sites/default/settings*.php
crontab -l 2>/dev/null; ls /etc/cron.d 2>/dev/null
```

Record in an inventory sheet:

- Drupal, PHP, database server and Drush versions
- contrib modules and themes, with versions
- custom modules, themes and profiles (`web/modules/custom`, `web/themes/custom`)
- patches (`extra.patches` in `composer.json`)
- `settings.php` overrides: private file path, reverse proxy, trusted hosts, config sync directory, Redis/Memcache, Solr
- integrations: SMTP, SSO/SAML/LDAP, payment, CRM, search, analytics, webhooks, outbound APIs, IP allow-lists
- server-side jobs: system cron, queue workers, `drush` jobs, import scripts
- content volume: database size, files size (`du -sh web/sites/default/files`), private files

**Expected result:** a complete inventory. Anything that depends on the old server (IP allow-lists, local binaries, shell scripts, file system paths) is flagged, because Pantheon does not let you install system packages or run your own daemons.
**Evidence:** inventory sheet and CSV exports attached to the ticket.

## Step 4 — Audit Drupal 11 blockers

Drupal 11 requires **Drupal 10.3+ as the starting point, PHP 8.3+, MySQL 8.0+ or MariaDB 10.6+, Drush 13, and Composer 2.7+**. The core modules Actions UI, Book, Forum, Statistics, Tour and Activity Tracker were removed from core and must be replaced with their contrib versions or uninstalled. Help Topics was merged into Help and must be uninstalled.

```bash
# Read-only readiness audit from this repository
DRUSH="ddev drush" COMPOSER_CMD="ddev composer" \
  ../drupal10-to-drupal11-pantheon-migration/scripts/drupal11-readiness.sh

# Deep scan of deprecated API use in contrib and custom code
ddev composer require --dev drupal/upgrade_status
ddev drush en upgrade_status -y
ddev drush upgrade_status:analyze --all > upgrade-status-report.txt

# What prevents Drupal 11 from installing?
ddev composer why-not drupal/core 11.0.0
```

Classify every finding:

| Category | Action |
|---|---|
| Contrib module has a Drupal 11 release | Update to it in Step 9 |
| Contrib module has a D11 patch or MR | Apply via `cweagans/composer-patches`; note the issue URL |
| Contrib module has no D11 path | Replace, remove, or use `mglaman/composer-drupal-lenient` as a documented, temporary exception |
| Custom code uses deprecated APIs | Fix in the upgrade branch (Drupal Rector helps: `palantirnet/drupal-rector`) |
| Custom `*.info.yml` lacks `^11` | Change to `core_version_requirement: ^10.3 \|\| ^11` |
| Removed core module enabled | `composer require drupal/<module>` (same machine name) while still on Drupal 10 |

**Expected result:** a blocker list where every item has a decision and an owner. Nothing is "unknown".
**Evidence:** `drupal11-readiness.sh` output, `upgrade-status-report.txt`, blocker list.

---

## Exit gate

- [ ] All access in Step 1 confirmed and tested
- [ ] Upgrade branch created from a recorded baseline commit
- [ ] Inventory complete, including integrations and server-side jobs
- [ ] Every Drupal 11 blocker has a decision and an owner
- [ ] Database server version meets Drupal 11 requirements, or a plan exists to fix it on Pantheon (`database.version` in `pantheon.yml`)
- [ ] Technical lead approval recorded

Next: [02 · Backups and local setup](02-backup-local-setup.md)
