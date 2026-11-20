# 05 · Database and files migration (Steps 19–22)

**Goal:** load the upgraded Drupal 11 database and matching files into Pantheon Dev and prove they work together with the deployed code.

**Key constraint:** the database you import must have been upgraded by the **same code** that is deployed. A Drupal 10 database imported under Drupal 11 code must have `drush updatedb` run immediately, so it is simpler to import the database already upgraded in Step 10.

---

## Step 19 — Export the upgraded database and files

```bash
cd source-drupal
ddev drush cr
ddev export-db --file=../backups/rehearsal/drupal11-upgraded.sql.gz
gzip -t ../backups/rehearsal/drupal11-upgraded.sql.gz

# Files: archive the contents of the files directory (not the directory itself)
tar -czf ../backups/rehearsal/files-for-pantheon.tar.gz -C web/sites/default/files \
  --exclude='./css' --exclude='./js' --exclude='./php' --exclude='./styles' .
tar -tzf ../backups/rehearsal/files-for-pantheon.tar.gz | head
```

If the site uses private files, add them to the archive under `private/`, because Pantheon's private path is `sites/default/files/private`:

```bash
mkdir -p /tmp/files-stage && tar -xzf ../backups/rehearsal/files-for-pantheon.tar.gz -C /tmp/files-stage
mkdir -p /tmp/files-stage/private && tar -xzf ../backups/rehearsal/private-files.tar.gz -C /tmp/files-stage/private
tar -czf ../backups/rehearsal/files-for-pantheon.tar.gz -C /tmp/files-stage . && rm -rf /tmp/files-stage
```

**Expected result:** a valid `.sql.gz` and a files archive whose top-level entries are `./inline-images`, `./private`, and so on, not `./files/...`.
**Evidence:** file sizes and checksums.

## Step 20 — Import the database into Dev

`terminus import:database` downloads from a URL, so host the dump at a **short-lived, access-controlled HTTPS URL**, such as a pre-signed object-storage link that expires in minutes. Never use a public bucket.

```bash
aws s3 cp ../backups/rehearsal/drupal11-upgraded.sql.gz s3://agency-migration-transfer/
DB_URL="$(aws s3 presign s3://agency-migration-transfer/drupal11-upgraded.sql.gz --expires-in 900)"

# Guarded wrapper: backs up the target, asks for confirmation, imports, runs updatedb + cr, verifies
../drupal10-to-drupal11-pantheon-migration/scripts/pantheon-import.sh "$SITE.dev" --db-url "$DB_URL"
```

The equivalent manual commands:

```bash
terminus backup:create "$SITE.dev" --element=all
terminus import:database "$SITE.dev" "$DB_URL"
terminus drush "$SITE.dev" -- updatedb -y
terminus drush "$SITE.dev" -- cr
```

Alternatives for large databases: the dashboard import (check the current size limit) or a direct MySQL connection (`terminus connection:info "$SITE.dev" --field=mysql_command`). Delete the transfer object once the import is done.

**Expected result:** the Dev site bootstraps on Drupal 11 and no updates are pending.
**Evidence:** workflow ID and `verify-upgrade.sh` output.

## Step 21 — Import files

For archives of moderate size:

```bash
FILES_URL="$(aws s3 presign s3://agency-migration-transfer/files-for-pantheon.tar.gz --expires-in 900)"
terminus import:files "$SITE.dev" "$FILES_URL"
```

For large file sets, rsync over SFTP (resumable, and can be re-run as a delta at cutover):

```bash
SITE_UUID="$(terminus site:info "$SITE" --field=id)"
ENV=dev
rsync -rLvz --size-only --ipv4 --progress -e 'ssh -p 2222' \
  /path/to/extracted/files/. \
  --temp-dir=~/tmp/ "$ENV.$SITE_UUID@appserver.$ENV.$SITE_UUID.drush.in:files/"
```

**Expected result:** images and documents load. Private downloads work for authorized users and are denied to anonymous users.
**Evidence:** `file:total` and `file:private` counts match (Step 22) and a few spot-checked downloads.

## Step 22 — Verify Dev

```bash
../drupal10-to-drupal11-pantheon-migration/scripts/pantheon-health-check.sh "$SITE" dev

DRUSH="terminus drush $SITE.dev --" \
  ../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh > ../backups/counts-pantheon-dev.tsv
../drupal10-to-drupal11-pantheon-migration/scripts/reconcile-counts.sh --compare \
  ../backups/counts-d11-local.tsv ../backups/counts-pantheon-dev.tsv
```

Also check the status report in the UI (`/admin/reports/status`), file system settings, cron (Pantheon runs Drupal cron hourly), and that outbound integrations on Dev point to sandbox endpoints, never production.

**Expected result:** health check reports HEALTHY, and counts match the local upgraded site exactly.
**Evidence:** health-check output and the compare result.

---

## Exit gate

- [ ] Imported database matches the deployed code. No pending updates
- [ ] Files and private files present, with access control working
- [ ] Counts identical to the local Drupal 11 rehearsal
- [ ] Transfer URLs expired and transfer objects deleted
- [ ] Dev integrations point to non-production endpoints

Previous: [04 · Pantheon setup](04-pantheon-setup.md) · Next: [06 · Testing and QA](06-testing-qa.md)
