# 06 Testing Qa

## Step 23 — Promote approved code from Dev to Test.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 24 — Clone or import correct upgraded content to Test, with overwrite approval.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 25 — Complete QA, accessibility, integrations, and business signoff.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Command examples

```bash
terminus env:deploy "$SITE.test" --note='Approved Drupal 11 QA release'
terminus env:clone-content --help
# Use only after verifying source, destination, and backups:
terminus env:clone-content "$SITE.dev" test
terminus drush "$SITE.test" -- status
terminus drush "$SITE.test" -- updatedb:status
```
> Confirm Terminus version-specific clone syntax and that Test content may be overwritten. Test authentication, webforms, search, redirects, media, integrations and accessibility.

## Exit gate

- [ ] Commands executed in the correct environment
- [ ] Results and logs reviewed
- [ ] Backups and recovery checkpoint confirmed
- [ ] Technical approval recorded
