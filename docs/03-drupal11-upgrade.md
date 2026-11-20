# 03 · Drupal 11 upgrade (Steps 7–12)

**Goal:** turn the local Drupal 10 copy into a working Drupal 11 site, with every change captured in Git so it can be replayed on the final production data.

**Rule:** the code upgrade is done once, in Git. The database upgrade is repeated (here, on Pantheon Dev and Test, and again at cutover) by running `drush updatedb` against the same code.

---

## Step 7 — Confirm a Drupal 10.3+ baseline and checkpoint

```bash
ddev drush status --field=drupal-version
ddev drush updatedb:status
```

If core is below 10.3, update within Drupal 10 first and commit that separately:

```bash
ddev composer update 'drupal/core-*' --with-all-dependencies
ddev drush updatedb -y && ddev drush cr
git commit -am 'Update Drupal core to latest 10.x'
ddev snapshot --name=d10-latest
```

**Expected result:** Drupal 10.3 or later, no pending updates, snapshot taken.
**Evidence:** version output and snapshot name.

## Step 8 — Resolve compatibility findings

Work through the blocker list from Step 4, still on Drupal 10, one commit per change:

```bash
# Replace removed core modules with contrib (same machine names, no data migration needed)
ddev composer require drupal/book drupal/forum drupal/statistics drupal/tour drupal/tracker drupal/action
# ...require only the ones that are enabled. Uninstall anything no longer used:
ddev drush pm:uninstall help_topics -y

# Update contrib to releases that support both 10.3 and 11
ddev composer update drupal/MODULE --with-all-dependencies

# Custom extensions
#   core_version_requirement: ^10.3 || ^11
# Automated deprecation fixes for custom code
ddev composer require --dev palantirnet/drupal-rector
ddev exec vendor/bin/rector process web/modules/custom --dry-run

# Re-run the readiness audit until it is clean
DRUSH="ddev drush" COMPOSER_CMD="ddev composer" \
  ../drupal10-to-drupal11-pantheon-migration/scripts/drupal11-readiness.sh --run-upgrade-status
```

If configuration is managed in Git, export after each change: `ddev drush config:export -y`.

**Expected result:** `drupal11-readiness.sh` shows no FAIL lines and Upgrade Status shows no errors for enabled projects.
**Evidence:** readiness output and a link to the pull request.

## Step 9 — Upgrade core, Drush and dependencies

Follow the drupal.org procedure: raise the constraints without installing, inspect a dry run, then update.

```bash
ddev snapshot --name=pre-d11-composer

# Adjust to the core packages your composer.json actually requires
ddev composer require 'drupal/core-recommended:^11' 'drupal/core-composer-scaffold:^11' \
  'drupal/core-project-message:^11' 'drush/drush:^13' --no-update
# If present: ddev composer require --dev 'drupal/core-dev:^11' --no-update

ddev composer update --with-all-dependencies --dry-run
# Drupal 11 core requires symfony/runtime, which is a Composer plugin. Composer refuses to
# install new plugins until you decide, so allow it explicitly:
ddev composer config --no-plugins allow-plugins.symfony/runtime true
# Resolve every conflict shown. Then:
ddev composer update --with-all-dependencies
ddev config --project-type=drupal11 && ddev restart
```

If Composer cannot resolve: run `ddev composer why-not drupal/core 11.0.0`, fix the named package, and repeat. Do not use `--ignore-platform-reqs` to force a result.

**Expected result:** `composer.lock` contains `drupal/core` 11.x and `drush/drush` 13.x, and `ddev composer validate` passes.
**Evidence:** `ddev composer show drupal/core drush/drush` output.

## Step 10 — Run database updates

```bash
ddev drush updatedb -y 2>&1 | tee ../backups/updatedb-rehearsal.log
ddev drush cr
ddev drush updatedb:status
ddev drush config:status        # if config is managed in Git
```

If an update hook fails: read the log, restore `ddev snapshot restore pre-d11-composer`, fix the cause (usually a contrib update or a data issue), and repeat. Never edit `key_value` schema entries by hand to "skip" an update without understanding it.

If configuration is managed in Git and updates changed config, export and commit it: `ddev drush config:export -y`.

**Expected result:** all updates applied, no pending updates, no unexpected config differences.
**Evidence:** `updatedb-rehearsal.log` and the time it took (this is your estimate for the cutover window).

## Step 11 — Test the upgraded site

```bash
DRUSH="ddev drush" ../drupal10-to-drupal11-pantheon-migration/scripts/verify-upgrade.sh
DRUSH="ddev drush" ../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh > ../backups/counts-d11-local.tsv
../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh --compare \
  ../backups/counts-d10-baseline.tsv ../backups/counts-d11-local.tsv
../drupal10-to-drupal11-pantheon-migration/scripts/smoke-test.sh "$(ddev describe -j | jq -r .raw.primary_url)"
```

Then manually check: admin theme and content editing (CKEditor 5), Views, menus, media, forms, user roles and permissions, custom theme templates, and anything the inventory flagged. Use [checklists/qa-acceptance.md](../checklists/qa-acceptance.md).

**Expected result:** `verify-upgrade.sh` has no FAIL lines, counts match exactly (an upgrade must not create or delete content), and manual checks pass.
**Evidence:** script outputs plus a short test log with screenshots.

## Step 12 — Review and commit

```bash
git status
git diff --stat main...
git add composer.json composer.lock web/modules/custom web/themes/custom config/ patches/
git commit -m 'Upgrade to Drupal 11'
git push -u origin upgrade/drupal11-pantheon
```

Open a pull request. Reviewers should check: no secrets or `settings.local.php`, no `vendor/` or `web/core/` committed (Pantheon builds them), patches documented, and any lenient or temporary exceptions listed.

**Expected result:** approved pull request. The commit hash is the **release candidate** used in every later step.
**Evidence:** pull request link and release-candidate commit hash.

---

## Exit gate

- [ ] Drupal 11 and Drush 13 in `composer.lock`
- [ ] `updatedb` completed. The log and duration are recorded
- [ ] `verify-upgrade.sh` clean, counts identical to the baseline
- [ ] Manual QA of critical journeys passed
- [ ] Release-candidate commit approved

Previous: [02 · Backups and local setup](02-backup-local-setup.md) · Next: [04 · Pantheon setup](04-pantheon-setup.md)
