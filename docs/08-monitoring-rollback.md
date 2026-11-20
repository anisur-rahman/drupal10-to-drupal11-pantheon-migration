# 08 · Monitoring and rollback (Steps 32–33)

**Goal:** catch problems early during hypercare, and if needed, roll back without losing data written after launch.

---

## Step 32 — Monitor production

Run at launch +15 min, +1 h, +4 h, then daily during hypercare (72 hours is typical):

```bash
../drupal10-to-drupal11-pantheon-migration/scripts/pantheon-health-check.sh "$SITE" live
terminus drush "$SITE.live" -- watchdog:show --severity=Error --count=50
terminus env:metrics "$SITE.live" --period=day      # traffic and cache hit ratio
```

Platform logs (nginx and PHP errors) are available over SFTP:

```bash
SITE_UUID="$(terminus site:info "$SITE" --field=id)"
rsync -rlvz --size-only --ipv4 -e 'ssh -p 2222' \
  "live.$SITE_UUID@appserver.live.$SITE_UUID.drush.in:logs" ./live-logs/
grep -c ' 50[0-9] ' live-logs/nginx-access.log
tail -n 50 live-logs/php-error.log
```

What to watch:

| Signal | Healthy | Investigate when |
|---|---|---|
| HTTP 5xx rate | ~0 | Any sustained 5xx |
| PHP errors | No new error types | New fatal or recurring warnings |
| Webform submissions / transactions | Normal daily volume | Volume drops to zero |
| Outbound email | Delivered | Bounces or queue growth |
| Cron | Hourly | No run in 2 hours |
| Search index | Up to date | New content missing from results |
| Cache hit ratio | Stable after warm-up | Persistently low (cookies or headers bypassing the CDN) |
| 404s | Expected long tail | Spikes on old URLs (add redirects) |

Also set up external uptime monitoring and New Relic (`terminus new-relic:enable "$SITE"`) if the plan includes it.

**Expected result:** hypercare ends with no open launch defects. Then the go/no-go owner closes the rollback period.
**Evidence:** monitoring log with timestamps.

## Step 33 — Roll back if necessary

Rollback is not `git revert`. A Drupal 11 database cannot be loaded by Drupal 10 code, and every minute Live is serving users it may be collecting data the old site does not have.

**Decision:** only the go/no-go owner triggers rollback, against criteria agreed in Step 26 (for example, data corruption, a security issue, or a critical journey broken with no fix within N hours).

Follow [checklists/rollback.md](../checklists/rollback.md):

1. **Freeze writes on Live** so the data set stops changing:
   ```bash
   terminus drush "$SITE.live" -- state:set system.maintenance_mode 1 --input-format=integer
   terminus drush "$SITE.live" -- cr
   ```
2. **Preserve Live's data:**
   ```bash
   terminus backup:create "$SITE.live" --element=all --keep-for=365
   terminus backup:get "$SITE.live" --element=db --to=../backups/live-at-rollback.sql.gz
   ```
3. **Find post-launch writes** by comparing high-water marks:
   ```bash
   DRUSH="terminus drush $SITE.live --" \
     ../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh > ../backups/counts-live-at-rollback.tsv
   ../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh --compare ~/counts-freeze.tsv ../backups/counts-live-at-rollback.tsv
   ```
   Any `max_nid`, `max_uid`, `max_fid` or `webform:*` increases are records created after launch. Export them (Views CSV, `drush webform:export`, or SQL) for manual re-entry or a targeted import on the old site.
4. **Reactivate the old host:** it still has the frozen Drupal 10 state from Step 27. Re-enable cron, bring it out of maintenance mode, and confirm it works using its direct hostname.
5. **Revert DNS** to the records saved in Step 26, then verify with `dig` and `curl`.
6. **Reconcile:** re-enter or import the post-launch records from step 3. Notify users who submitted data during the affected window if needed.
7. **Record the incident:** timeline, root cause, data impact and the plan for the next attempt.

**Expected result:** the old site serves production with no data lost from the Pantheon period.
**Evidence:** incident record, reconciliation log.

---

## Exit gate

- [ ] Hypercare monitoring log complete
- [ ] No open critical or high launch defects
- [ ] Rollback period formally closed by the go/no-go owner
- [ ] Old host decommissioning scheduled (keep the final backup per your retention policy)
- [ ] DNS TTL restored to its normal value

Previous: [07 · Production cutover](07-production-cutover.md) · Next: [09 · Demo lab](09-demo-lab.md)
