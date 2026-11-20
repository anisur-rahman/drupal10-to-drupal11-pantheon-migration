# 02 Backup Local Setup

## Step 5 — Export consistent source database, public/private files and record Git commit.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 6 — Create a local Drupal 10 copy with DDEV, import database/files and verify baseline.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Command examples

```bash
# On authorized source host, from project root
./vendor/bin/drush sql:dump --gzip --result-file="$HOME/drupal10.sql.gz"
tar -czf "$HOME/public-files.tar.gz" -C web/sites/default/files .
# Locally, after securely copying snapshots
brew install ddev/ddev/ddev
ddev config --project-type=drupal10 --docroot=web --php-version=8.3
ddev start
ddev composer install
ddev import-db --file=../backups/drupal10.sql.gz
ddev import-files --source=../backups/public-files.tar.gz
ddev drush status
```
> Backup private files separately. Never place backups or credentials in Git.

## Exit gate

- [ ] Commands executed in the correct environment
- [ ] Results and logs reviewed
- [ ] Backups and recovery checkpoint confirmed
- [ ] Technical approval recorded
