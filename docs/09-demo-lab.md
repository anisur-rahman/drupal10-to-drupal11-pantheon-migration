# 09 · Demo lab: practice the whole runbook

Build a disposable Drupal 10 site that deliberately includes a Drupal 11 blocker (the core **Book** module), then upgrade it and, optionally, migrate it to a Pantheon sandbox. No real data is involved.

Requirements: Docker, DDEV, Git, about 30 minutes. Pantheon is optional. Check current sandbox eligibility, quotas and pricing first.

---

## Lab 1 — Create the Drupal 10 "source" site

```bash
mkdir -p ~/projects/d10-lab && cd ~/projects/d10-lab
ddev config --project-type=drupal10 --docroot=web --php-version=8.3
ddev start
ddev composer create-project 'drupal/recommended-project:^10.3' .
ddev composer require 'drush/drush:^13'
ddev drush site:install standard -y --site-name="Agency Lab (fictional)" \
  --account-name=admin --account-pass="$(openssl rand -base64 18)"
git init -q && git add -A && git commit -qm 'Drupal 10 baseline'
```

Add realistic content and the blocker:

```bash
ddev composer require --dev drupal/devel
ddev drush en devel_generate book -y          # 'book' is deprecated core in 10.x and removed in 11
ddev drush devel-generate:users 10
ddev drush devel-generate:terms 30 --bundles=tags
ddev drush devel-generate:content 60 --bundles=article,page
git add -A && git commit -qm 'Lab content tooling'
ddev snapshot --name=lab-d10
```

## Lab 2 — Discovery and backup (Steps 3–6)

```bash
REPO=~/path/to/drupal10-to-drupal11-pantheon-migration
DRUSH="ddev drush" COMPOSER_CMD="ddev composer" $REPO/scripts/drupal11-readiness.sh
```

Expect a **FAIL** for `book is enabled from core`. That is the blocker to fix.

```bash
DRUSH="ddev drush" $REPO/scripts/backup-drupal.sh --output ~/projects/lab-backups/d10
DRUSH="ddev drush" $REPO/scripts/reconcile-counts.sh > ~/projects/lab-backups/counts-d10.tsv
```

## Lab 3 — Fix the blocker and upgrade (Steps 8–11)

```bash
ddev composer require drupal/book            # contrib Book, same machine name
ddev drush cr
DRUSH="ddev drush" COMPOSER_CMD="ddev composer" $REPO/scripts/drupal11-readiness.sh   # book now PASS
git add -A && git commit -qm 'Move Book to contrib'

ddev composer require 'drupal/core-recommended:^11' 'drupal/core-composer-scaffold:^11' \
  'drupal/core-project-message:^11' --no-update
ddev composer update --with-all-dependencies --dry-run
ddev composer config --no-plugins allow-plugins.symfony/runtime true   # new plugin required by Drupal 11 core
ddev composer update --with-all-dependencies
ddev config --project-type=drupal11 && ddev restart
ddev drush updatedb -y && ddev drush cr

DRUSH="ddev drush" $REPO/scripts/verify-upgrade.sh
DRUSH="ddev drush" $REPO/scripts/reconcile-counts.sh > ~/projects/lab-backups/counts-d11.tsv
$REPO/scripts/reconcile-counts.sh --compare ~/projects/lab-backups/counts-d10.tsv ~/projects/lab-backups/counts-d11.tsv
$REPO/scripts/smoke-test.sh "$(ddev describe -j | jq -r .raw.primary_url)"
git add -A && git commit -qm 'Upgrade to Drupal 11'
```

Expected: `verify-upgrade.sh` reports Drupal 11 with no FAIL lines (config-sync and status-report warnings are normal on a fresh lab site), and the compare prints `MATCH`. Last validated with Drupal 10.6.22 → 11.4.13, PHP 8.3, MariaDB 11.8 and DDEV 1.25 in November 2026.

If a dependency blocks the update (devel versions, for example), run `ddev composer why-not drupal/core 11.0.0` and update or remove the named package. This is the real-world loop in miniature.

## Lab 4 — Break it and roll back

```bash
ddev snapshot restore lab-d10       # back to Drupal 10 database
git switch --detach HEAD~2 && ddev composer install
ddev drush status --field=drupal-version
```

Then return with `git switch -` plus `ddev composer install`, and rerun Lab 3. Repeat until the upgrade is boring and quick, which is the point of a rehearsal.

## Lab 5 — Pantheon (optional)

Follow [04 · Pantheon setup](04-pantheon-setup.md) and [05 · Database and files migration](05-database-files-migration.md) with a sandbox site, using the lab's upgraded database. Then run:

```bash
$REPO/scripts/pantheon-health-check.sh drupal11-migration-demo dev
```

Delete the sandbox when you are done: `terminus site:delete drupal11-migration-demo`.

## Clean up

```bash
ddev delete -O -y && rm -rf ~/projects/d10-lab ~/projects/lab-backups
```

Previous: [08 · Monitoring and rollback](08-monitoring-rollback.md) · Next: [10 · Troubleshooting](10-troubleshooting.md)
