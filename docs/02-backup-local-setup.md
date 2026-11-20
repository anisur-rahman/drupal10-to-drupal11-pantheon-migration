# 02 · Backups and local setup (Steps 5–6)

**Goal:** capture a consistent, verified snapshot of the source and restore it into an isolated DDEV environment where the upgrade can be broken and repeated safely.

**Outputs:** a checksummed backup set outside Git, a working local Drupal 10 copy, a baseline of content counts.

---

## Step 5 — Back up the source

A backup is only useful if database, files and code all describe the same moment. For the rehearsal a live snapshot is fine; for the final cutover (Step 28) writes must be frozen first.

```bash
# On the source host, from the project root
../drupal10-to-drupal11-pantheon-migration/scripts/backup-drupal.sh \
  --output "$HOME/backups/rehearsal-$(date -u +%Y%m%d)" \
  --private-dir /var/private-files     # only if the site uses private files
```

The script writes:

| File | Contents |
|---|---|
| `database.sql.gz` | Full `drush sql:dump`, integrity-tested with `gzip -t` |
| `public-files.tar.gz` | Public files, excluding regenerated `css/`, `js/`, `php/`, `styles/` |
| `private-files.tar.gz` | Private files, when configured |
| `manifest.txt` | UTC time, Git commit, dirty flag, Drupal/PHP/DB versions, `composer.lock` hash |
| `enabled-extensions.txt`, `drush-status.txt` | State at backup time |
| `SHA256SUMS` | Checksums for transfer verification |

It refuses to write into a Git work tree, so a dump can never be committed by accident.

Copy the backup to your workstation and verify it arrived intact:

```bash
rsync -avz --progress user@source-host:backups/rehearsal-20261120/ ../backups/rehearsal/
(cd ../backups/rehearsal && shasum -a 256 -c SHA256SUMS)
```

**Expected result:** every checksum prints `OK`.
**Evidence:** `manifest.txt` and the checksum output in the ticket. Store backups in an encrypted, access-controlled location. They contain personal data.

## Step 6 — Restore into DDEV and record a baseline

```bash
cd source-drupal                       # the upgrade branch from Step 2
ddev config --project-type=drupal10 --docroot=web --php-version=8.3 --database=mariadb:10.11
ddev start
ddev composer install
ddev import-db --file=../backups/rehearsal/database.sql.gz
ddev import-files --source=../backups/rehearsal/public-files.tar.gz
ddev drush cr
ddev drush uli                          # one-time admin login link
```

Notes:

- Match the production database engine family (MySQL or MariaDB). MariaDB 10.11 and MySQL 8.0 both satisfy Drupal 11. Pantheon uses MariaDB.
- Private files: extract them to a directory outside the docroot (for example `private/`) and set `$settings['file_private_path']` in `web/sites/default/settings.ddev.php` or a `settings.local.php`.
- Disable outbound side effects locally: mail is caught by DDEV's Mailpit, but also disable payment gateways, webhooks and CRM sync (via config overrides in `settings.local.php`).

Take a DDEV snapshot. It is your instant "undo" for the upgrade:

```bash
ddev snapshot --name=d10-baseline
```

Record a content baseline to compare against after the upgrade and on Pantheon:

```bash
DRUSH="ddev drush" ../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh > ../backups/counts-d10-baseline.tsv
DRUSH="ddev drush" ../drupal10-to-drupal11-pantheon-migration/scripts/verify-upgrade.sh --expect-major 10
```

**Expected result:** the local site loads, admin login works, images display, `verify-upgrade.sh --expect-major 10` has no FAIL lines that also exist in production (pre-existing issues should be noted, not fixed silently).
**Evidence:** snapshot name, `counts-d10-baseline.tsv`, screenshots of the home page and a few key pages.

---

## Exit gate

- [ ] Backup set checksummed, transferred and stored securely outside Git
- [ ] A restore has actually been tested (this step proves it)
- [ ] Local Drupal 10 copy works with database and files
- [ ] `d10-baseline` DDEV snapshot taken
- [ ] Baseline counts recorded
- [ ] Outbound integrations disabled locally

Previous: [01 · Discovery](01-discovery.md) · Next: [03 · Drupal 11 upgrade](03-drupal11-upgrade.md)
