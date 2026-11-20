# Production cutover checklist

Phase doc: [07 · Production cutover](../docs/07-production-cutover.md). Record a timestamp next to each item.

## Before the window
- [ ] Change approved. Window, abort time and go/no-go owner recorded
- [ ] Timed rehearsal completed on Test. Durations plus 50% fit the window
- [ ] DNS TTL lowered to 300 s at least 48 h before. Original records exported
- [ ] Domains added to Live. HTTPS certificate pre-provisioned
- [ ] Live initialized with the release-candidate commit
- [ ] Editors and stakeholders notified of the content freeze
- [ ] Production integration credentials ready in a secrets store

## Freeze and final data
- [ ] Source in maintenance mode. Cron, queue workers and imports stopped
- [ ] Inbound API and webhook writers paused
- [ ] Freeze counts captured (`counts-freeze.tsv`)
- [ ] Final backup taken, transferred and checksums verified
- [ ] Final database upgraded with the release-candidate commit. `verify-upgrade.sh` clean
- [ ] Freeze counts = upgraded counts

## Live
- [ ] Final database and files imported to Live. Counts match the freeze
- [ ] `pantheon-health-check.sh SITE live` HEALTHY
- [ ] Production integrations re-pointed and tested
- [ ] Maintenance mode off on Live
- [ ] Production hostname tested with `curl --resolve` before DNS switch
- [ ] **Go / no-go decision recorded (time, owner)**

## DNS and verification
- [ ] DNS records switched to Pantheon values
- [ ] `dig` shows Pantheon for all hostnames. HTTPS valid. Primary-domain redirect works
- [ ] Smoke test passes on the production hostname
- [ ] Logins, forms and key journeys verified on production
- [ ] Old host kept frozen (not writable) for the rollback period
- [ ] Hypercare monitoring started
