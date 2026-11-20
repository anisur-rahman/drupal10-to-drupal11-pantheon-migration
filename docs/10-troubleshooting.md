# Troubleshooting

| Symptom | Diagnostic | Response |
|---|---|---|
| Composer dependency conflict | `composer prohibits drupal/core-recommended '^11'` | Resolve direct dependencies and contrib compatibility |
| Site fails after DB import | `terminus drush SITE.dev -- status` | Verify code/database version match and Pantheon settings |
| Missing images | Inspect file archive layout | Re-import correct public files; verify private path separately |
| Test has wrong content | Review clone source/destination | Restore correct Test snapshot, repeat QA |
| Rollback requested after new writes | Compare transactions | Freeze writes and reconcile before DNS rollback |
