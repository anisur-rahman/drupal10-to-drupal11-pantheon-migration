# 07 Production Cutover

## Step 26 — Approve maintenance window, DNS plan, recovery deadline and go/no-go owner.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 27 — Freeze source content and external writes; disable duplicate jobs.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 28 — Take final consistent Drupal 10 database/files snapshot.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 29 — Rehearse-tested final Drupal 10 database upgrade to Drupal 11 and reconcile.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 30 — Deploy approved code to Pantheon Live and import upgraded final data.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 31 — Configure domain/DNS/HTTPS and verify production routing.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Command examples

```bash
# Freeze source writes and capture final Drupal 10 database/files.
# Restore final source snapshot in isolated approved Drupal 11 upgrade environment.
ddev import-db --file=../backups/final-drupal10.sql.gz
ddev drush updatedb -y
ddev drush cr
ddev drush updatedb:status
ddev export-db --file=../backups/final-drupal11.sql.gz
# After approval, deploy tested code to Live:
terminus env:deploy "$SITE.live" --note='Approved Drupal 11 launch'
# Import final upgraded DB and matching files using approved secure URLs:
terminus import:database "$SITE.live" "$FINAL_DB_URL"
terminus import:files "$SITE.live" "$FINAL_FILES_URL"
terminus domain:add "$SITE.live" www.example.gov
terminus domain:dns "$SITE.live"
dig www.example.gov +short
curl -I https://www.example.gov
```
> Final database upgrade must be rehearsed on the exact target code. Keep old host authoritative until go/no-go. DNS and HTTPS require authorized provider access.

## Exit gate

- [ ] Commands executed in the correct environment
- [ ] Results and logs reviewed
- [ ] Backups and recovery checkpoint confirmed
- [ ] Technical approval recorded
