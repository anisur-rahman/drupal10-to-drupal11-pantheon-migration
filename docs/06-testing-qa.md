# 06 · Testing and QA (Steps 23–25)

**Goal:** prove on Pantheon Test, which mirrors Live's configuration, that the release candidate is ready, and get business sign-off.

---

## Step 23 — Deploy code to Test

```bash
terminus env:deploy "$SITE.test" --note="Drupal 11 RC $(git rev-parse --short HEAD)" --updatedb --cc
terminus env:code-log "$SITE.test" | head -n 3
```

The first deploy initializes the Test environment and copies Dev's database and files into it. Later deploys move **code only**.

**Expected result:** Test runs the same commit as Dev.
**Evidence:** workflow entry and commit hash.

## Step 24 — Put the right content on Test

On later QA cycles, refresh Test's content from Dev. This **overwrites** Test's database and files, so make sure nobody has QA work there that would be lost.

```bash
terminus backup:create "$SITE.test" --element=all
terminus env:clone-content "$SITE.dev" test --cc --updatedb
```

For a more realistic rehearsal, import a **fresh** production snapshot that you upgraded locally (repeat Steps 5, 10 and 19–21 targeting `test`). This is also the timed dress rehearsal for cutover:

```bash
time ../drupal10-to-drupal11-pantheon-migration/scripts/pantheon-import.sh "$SITE.test" \
  --db-url "$DB_URL" --files-url "$FILES_URL"
```

**Expected result:** Test has known, documented content, and you know how long the final data import takes.
**Evidence:** source of the content (snapshot date), duration, counts.

## Step 25 — QA and sign-off

Lock Test so only testers can see it, then work through [checklists/qa-acceptance.md](../checklists/qa-acceptance.md).

```bash
terminus lock:enable "$SITE.test" qa "$(openssl rand -base64 18)"   # share the password via your password manager
../drupal10-to-drupal11-pantheon-migration/scripts/pantheon-health-check.sh "$SITE" test
SMOKE_AUTH="qa:PASSWORD" ../drupal10-to-drupal11-pantheon-migration/scripts/smoke-test.sh \
  "https://test-$SITE.pantheonsite.io" ../drupal10-to-drupal11-pantheon-migration/examples/smoke-paths.example
```

Coverage:

| Area | What to test |
|---|---|
| Content | Create, edit, revise, publish and delete each content type. CKEditor 5 embeds. Media library |
| Access | Each role logs in (and SSO if used). Permissions. Unpublished content is hidden |
| Forms | Webforms submit, email via the configured SMTP service, handlers fire |
| Search | Index rebuilt (`drush search-api:index`), results relevant |
| URLs | Path aliases, redirects from the old site, canonical/hreflang, sitemap, robots.txt |
| Integrations | Each inventory item, against sandbox endpoints |
| Accessibility | Automated scan (axe or Pa11y) plus keyboard and screen-reader spot checks to WCAG 2.2 AA |
| Performance | Cache headers (`curl -sI` shows the Pantheon Global CDN), key-page response times |
| Security | Admin pages need login, no debug output, `composer audit` clean, file permissions |

Log defects with severity. Launch requires zero open critical or high defects, or defects explicitly accepted by the business owner.

**Expected result:** completed checklist and a signed-off go decision for the cutover rehearsal.
**Evidence:** QA report, defect log, sign-off email or ticket approval.

---

## Exit gate

- [ ] Test runs the release-candidate commit
- [ ] Content source documented. Timed import rehearsal completed
- [ ] QA checklist complete. No unaccepted critical or high defects
- [ ] Accessibility results recorded
- [ ] Business owner sign-off recorded

Previous: [05 · Database and files migration](05-database-files-migration.md) · Next: [07 · Production cutover](07-production-cutover.md)
