# 03 Drupal11 Upgrade

## Step 7 — Check Drupal 10.3+ baseline and capture pre-upgrade checkpoint.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 8 — Resolve module/theme compatibility and Upgrade Status findings.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 9 — Update compatible Drupal core/Drush Composer constraints and dependencies.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 10 — Run Drush database updates and cache rebuild.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 11 — Test upgraded Drupal 11 application and content.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 12 — Review and commit upgraded application source and lockfile.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Command examples

```bash
ddev drush updatedb:status
ddev composer prohibits drupal/core-recommended '^11'
# After compatibility remediation, for projects with these direct packages:
ddev composer require 'drupal/core-recommended:^11' 'drupal/core-composer-scaffold:^11' 'drupal/core-project-message:^11' --no-update
ddev composer update 'drupal/core-*' drush/drush --with-all-dependencies --dry-run
# Only after reviewing the dry-run and resolving conflicts:
ddev composer update 'drupal/core-*' drush/drush --with-all-dependencies
ddev drush updatedb -y
ddev drush cr
ddev drush status
```
> Requires Drupal 10.3+, compatible PHP (8.3+), Drush, extensions and database. Adapt direct dependencies to your composer.json. Do not skip blockers.

## Exit gate

- [ ] Commands executed in the correct environment
- [ ] Results and logs reviewed
- [ ] Backups and recovery checkpoint confirmed
- [ ] Technical approval recorded
