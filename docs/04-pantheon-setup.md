# 04 Pantheon Setup

## Step 13 — Create Composer-managed Drupal 11 destination on Pantheon.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 14 — Install/authenticate Terminus and confirm access.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 15 — Clone Pantheon Git repository and inspect deployment branch.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 16 — Verify Pantheon integrations, settings and pantheon.yml.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 17 — Merge approved upgraded code and Composer dependencies into Pantheon scaffold.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 18 — Push approved code to Dev and verify Integrated Composer build.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Command examples

```bash
export SITE=drupal11-migration-demo
terminus auth:login
terminus site:info "$SITE"
terminus connection:set "$SITE.dev" git
GIT_URL="$(terminus connection:info "$SITE.dev" --field=git_url)"
git clone "$GIT_URL" pantheon-drupal11
cd pantheon-drupal11
git branch -a
composer show pantheon-systems/drupal-integrations
# Merge reviewed application changes and Composer requirements, preserving Pantheon scaffold.
git status
git add composer.json composer.lock web/modules/custom web/themes/custom
git commit -m 'Migrate approved Drupal 11 application'
git push origin master
```
> Create the site using the dashboard and confirm its actual Git deployment branch. Do not overwrite the Pantheon scaffold.

## Exit gate

- [ ] Commands executed in the correct environment
- [ ] Results and logs reviewed
- [ ] Backups and recovery checkpoint confirmed
- [ ] Technical approval recorded
