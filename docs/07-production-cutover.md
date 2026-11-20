# 07 · Production cutover (Steps 26–31)

**Goal:** move production to Pantheon Live with a short, controlled content freeze, no lost writes, and a rollback option until the go/no-go decision.

> Domain `www.agency.example` is fictional. Custom domains on Live require a paid Pantheon plan.

---

## Timeline (example)

| When | Activity | Owner |
|---|---|---|
| T-7 days | Change approved, rehearsal (Step 24) completed and timed | Change manager |
| T-48 h | Lower DNS TTL to 300 s. Pre-provision HTTPS on Pantheon | Network |
| T-24 h | Announce content freeze to editors. Confirm the on-call roster | Product owner |
| T-0 | Freeze, final snapshot, upgrade, import, verify (Steps 27–30) | Tech lead |
| T+duration | Go/no-go, DNS switch (Step 31) | Go/no-go owner |
| T+1 h to +72 h | Hypercare (Step 32) | Support |

## Step 26 — Approve the window, DNS plan, abort point and go/no-go owner

Write down, before the window:

- the **abort time**: if Live is not verified by this time, stop and keep the old host
- the **go/no-go owner**: one person who decides
- the current DNS records (export them, for rollback) and the new records from Pantheon
- the measured durations from the rehearsal, plus a 50% buffer

Pre-provision HTTPS so the certificate exists before DNS moves:

```bash
terminus env:deploy "$SITE.live" --note="Initialize Live with Drupal 11 RC" --updatedb --cc   # first deploy initializes Live
terminus domain:add "$SITE.live" www.agency.example
terminus domain:add "$SITE.live" agency.example
terminus domain:dns "$SITE.live"    # shows the required DNS records and verification options
```

Follow the dashboard's domain verification (an ACME challenge) to issue the certificate before cutover.

**Expected result:** an approved change with every item above filled in.
**Evidence:** change record.

## Step 27 — Freeze writes on the source

Copy this repository's `scripts/` directory to the source host first (for example to `~/runbook/scripts`).

```bash
# On the source host, from the project root
./vendor/bin/drush state:set system.maintenance_mode 1 --input-format=integer
./vendor/bin/drush cr
crontab -l > ~/crontab-backup.txt      # then comment out Drupal cron, queue workers and imports
```

Maintenance mode blocks most anonymous writes (forms, comments), but confirm that integrations writing via APIs or webhooks are paused at their source, and that editors know not to work.

Record the freeze high-water marks:

```bash
DRUSH=./vendor/bin/drush ~/runbook/scripts/reconcile-counts.sh > ~/counts-freeze.tsv
```

**Expected result:** no new nodes, users, submissions or files after this point.
**Evidence:** freeze time and `counts-freeze.tsv`.

## Step 28 — Final source snapshot

```bash
~/runbook/scripts/backup-drupal.sh --output "$HOME/backups/final-$(date -u +%Y%m%dT%H%MZ)"
```

Copy and verify the checksums on your workstation, as in Step 5.

**Expected result:** a checksummed final backup whose counts equal `counts-freeze.tsv`.
**Evidence:** `manifest.txt` and checksum output.

## Step 29 — Upgrade the final database (rehearsed procedure)

Use exactly the release-candidate commit and the procedure timed in the rehearsal:

```bash
cd source-drupal && git switch --detach "$RC_COMMIT" && ddev composer install
ddev import-db --file=../backups/final/database.sql.gz
ddev drush updatedb -y 2>&1 | tee ../backups/final/updatedb.log
ddev drush cr
DRUSH="ddev drush" ../drupal10-to-drupal11-pantheon-migration/scripts/verify-upgrade.sh
DRUSH="ddev drush" ../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh > ../backups/final/counts-d11.tsv
../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh --compare ~/counts-freeze.tsv ../backups/final/counts-d11.tsv
ddev export-db --file=../backups/final/drupal11-final.sql.gz
```

**Expected result:** clean verification, and counts identical to the freeze.
**Evidence:** `updatedb.log`, verification output, compare result.

## Step 30 — Deploy and import to Live

```bash
terminus env:deploy "$SITE.live" --note="Drupal 11 launch $RC_COMMIT" --cc     # skip if Live already runs RC
ALLOW_LIVE=yes ../drupal10-to-drupal11-pantheon-migration/scripts/pantheon-import.sh "$SITE.live" \
  --db-url "$FINAL_DB_URL" --files-url "$FINAL_FILES_URL"

DRUSH="terminus drush $SITE.live --" \
  ../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh > ../backups/final/counts-live.tsv
../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh --compare ~/counts-freeze.tsv ../backups/final/counts-live.tsv
../drupal10-to-drupal11-pantheon-migration/scripts/pantheon-health-check.sh "$SITE" live
```

Switch Live integrations to production endpoints (credentials from a secrets store such as Pantheon Secrets, not Git), and confirm maintenance mode is **off** on Live.

**Expected result:** Live is healthy on its `live-SITE.pantheonsite.io` URL, and counts match the freeze.
**Evidence:** health-check output and compare result. **Go/no-go decision is made here.**

## Step 31 — Switch DNS and verify routing

Before switching, test the production hostname against Pantheon without changing DNS:

```bash
PANTHEON_IP=203.0.113.10    # value from 'terminus domain:dns' (example IP)
curl -sSI --resolve "www.agency.example:443:$PANTHEON_IP" https://www.agency.example/ | head -n 5
```

After **go**, update the DNS records to the values from `terminus domain:dns`, then:

```bash
terminus domain:primary:add "$SITE.live" www.agency.example   # redirect other domains to the primary
dig +short www.agency.example
dig +short agency.example
curl -sSI https://www.agency.example/ | grep -iE '^(HTTP|x-pantheon|location)'
../drupal10-to-drupal11-pantheon-migration/scripts/smoke-test.sh https://www.agency.example \
  ../drupal10-to-drupal11-pantheon-migration/examples/smoke-paths.example
```

Keep the old host **frozen and in maintenance mode**. Do not re-enable writes there. It is now the rollback target, not a production system.

**Expected result:** both hostnames resolve to Pantheon, HTTPS is valid, the bare domain redirects to `www`, and the smoke test passes.
**Evidence:** `dig`/`curl` output and smoke-test result.

---

## Exit gate

- [ ] Freeze held. Counts at freeze = final upgrade = Live
- [ ] Live verified before DNS change. Go decision recorded with time and owner
- [ ] DNS switched. HTTPS valid on all hostnames. Primary domain redirect works
- [ ] Production integrations re-pointed and tested
- [ ] Old host frozen and preserved for the rollback period

Previous: [06 · Testing and QA](06-testing-qa.md) · Next: [08 · Monitoring and rollback](08-monitoring-rollback.md)
