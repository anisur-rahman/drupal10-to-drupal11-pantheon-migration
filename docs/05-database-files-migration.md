# 05 Database Files Migration

## Step 19 — Export matching upgraded Drupal 11 database.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 20 — Import upgraded database to Pantheon Dev using protected temporary URL.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 21 — Import matching public/private files with permissions preserved.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 22 — Run Dev environment health, content and functional checks.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Command examples

```bash
# From DDEV source project
ddev export-db --file=../backups/drupal11-upgraded.sql.gz
# Set these to real, approved short-lived download URLs; never commit them.
export DB_URL='https://REPLACE_WITH_SECURE_URL/db.sql.gz'
export FILES_URL='https://REPLACE_WITH_SECURE_URL/files.tar.gz'
terminus import:database "$SITE.dev" "$DB_URL"
terminus import:files "$SITE.dev" "$FILES_URL"
terminus drush "$SITE.dev" -- status
terminus drush "$SITE.dev" -- updatedb:status
terminus drush "$SITE.dev" -- cr
```
> Imports overwrite target data. Archive layout and private-file migration must be verified before import.

## Exit gate

- [ ] Commands executed in the correct environment
- [ ] Results and logs reviewed
- [ ] Backups and recovery checkpoint confirmed
- [ ] Technical approval recorded
