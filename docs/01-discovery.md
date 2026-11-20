# 01 Discovery

## Step 1 — Request source SSH, Git, Drupal admin, database, Pantheon, DNS and change-management access.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 2 — Clone source Git repository and create an upgrade branch.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 3 — Inspect Composer, PHP, Drush, Drupal version, enabled extensions, settings and integrations.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 4 — Audit Drupal 11 blockers, deprecated APIs and removed core extensions.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Command examples

```bash
git clone git@github.com:ORG/REPO.git source-drupal
cd source-drupal
git switch -c upgrade/drupal11-pantheon
composer validate
composer show drupal/core-recommended
composer prohibits drupal/core-recommended '^11'
./vendor/bin/drush status
./vendor/bin/drush pm:list --status=enabled
```
> Commands assume a Composer-managed source and installed dependencies. Capture environment-specific requirements and do not expose secrets.

## Exit gate

- [ ] Commands executed in the correct environment
- [ ] Results and logs reviewed
- [ ] Backups and recovery checkpoint confirmed
- [ ] Technical approval recorded
