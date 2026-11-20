# 08 Monitoring Rollback

## Step 32 — Monitor production, integrations, forms, logs and transaction counts.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Step 33 — If necessary, freeze writes, reconcile post-cutover transactions, revert DNS and restore compatible source state.

**Action:** Follow the commands and verify the expected result before advancing. Record evidence in your change ticket.

## Command examples

```bash
terminus drush "$SITE.live" -- status
terminus backup:list "$SITE.live"
# Read-only availability check:
curl --location --fail --silent --show-error --output /dev/null https://www.example.gov/
```
> Rollback is not simply `git revert`: first freeze new writes, preserve Pantheon post-cutover data, reconcile transactions, restore compatible code/database/files/configuration, and only then revert DNS. Keep source host available for agreed rollback period.

## Exit gate

- [ ] Commands executed in the correct environment
- [ ] Results and logs reviewed
- [ ] Backups and recovery checkpoint confirmed
- [ ] Technical approval recorded
