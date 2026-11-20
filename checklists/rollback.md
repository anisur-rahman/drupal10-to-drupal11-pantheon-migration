# Rollback checklist

Phase doc: [08 · Monitoring and rollback](../docs/08-monitoring-rollback.md). Rollback is a data operation, not just a DNS change.

## Decide
- [ ] Trigger matches the criteria agreed before cutover
- [ ] Go/no-go owner has approved rollback (time recorded)
- [ ] Stakeholders notified that rollback has started

## Preserve
- [ ] Live in maintenance mode. Integrations writing to Live paused
- [ ] `terminus backup:create SITE.live --element=all` taken and downloaded
- [ ] Post-launch counts captured. Compared to `counts-freeze.tsv`
- [ ] Post-launch records (nodes, users, files, submissions, orders) exported

## Restore
- [ ] Old host verified to still be in its frozen Drupal 10 state
- [ ] Old host cron, queues and integrations re-enabled. Maintenance mode off
- [ ] Old site tested via its direct hostname before the DNS change
- [ ] DNS reverted to the exported original records
- [ ] `dig` and `curl` confirm traffic reaches the old host. HTTPS valid

## Reconcile and close
- [ ] Post-launch records re-entered or imported on the old site
- [ ] Affected users contacted, if any data could not be recovered
- [ ] Smoke test and key journeys pass on the old site
- [ ] Incident recorded: timeline, root cause, data impact, next-attempt plan
- [ ] Pantheon Live left in maintenance mode, with its backup retained
