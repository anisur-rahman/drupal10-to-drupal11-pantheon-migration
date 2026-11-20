# 10 · Troubleshooting

## Composer and the upgrade

| Symptom | Diagnose | Fix |
|---|---|---|
| `Your requirements could not be resolved` when requiring core `^11` | `composer why-not drupal/core 11.0.0` | Update, patch or remove each named package. Don't use `--ignore-platform-reqs` |
| A contrib module only declares `^10` | Search its issue queue for a D11 merge request | Apply the patch with `cweagans/composer-patches`, or use `mglaman/composer-drupal-lenient` as a documented, temporary exception |
| `symfony/runtime contains a Composer plugin which is blocked by your allow-plugins config` | Composer output during `update` | Drupal 11 core requires `symfony/runtime`. Run `composer config --no-plugins allow-plugins.symfony/runtime true` and rerun the update. Commit the `composer.json` change |
| `verify-upgrade.sh` still reports Drupal 10 after the update | `composer show drupal/core` | The Composer update failed partway. Scroll up for the error, fix it, rerun `composer update -W` |
| `drush/drush` conflicts | `composer show drush/drush` | Drupal 11 needs Drush 13: `composer require drush/drush:^13 --no-update` |
| `updatedb` fails in a contrib hook | The log from `drush updatedb -y` | Restore the snapshot, update that module to its latest release, retry. Search the module's issue queue for the hook number |
| "Module X is missing from the file system" | `drush pm:list` / status report | A removed core module (book, forum...) is still installed. Run `composer require drupal/X`, or uninstall it on Drupal 10 before upgrading |
| PHP version errors in DDEV | `ddev exec php -v` | `ddev config --php-version=8.3 && ddev restart` |

## Pantheon build and deployment

| Symptom | Diagnose | Fix |
|---|---|---|
| Integrated Composer build fails | Dashboard build log, `terminus workflow:list $SITE` | Private repos need an auth token configured on Pantheon. Re-check patch URLs and `php_version` in `pantheon.yml` |
| Changes pushed but not visible | `terminus env:code-log $SITE.dev` | Pushed to the wrong branch (Pantheon deploys `master`), or `vendor/` / `web/core` committed and overriding the build |
| Dev in SFTP mode, push rejected | `terminus env:info $SITE.dev --field=connection_mode` | Commit or discard SFTP changes, then `terminus connection:set $SITE.dev git` |
| Database version error after import | `terminus drush $SITE.dev -- sql:query 'SELECT VERSION()'` | Set `database: version: 10.6` in `pantheon.yml`, push, wait for the upgrade workflow |

## Data and files

| Symptom | Diagnose | Fix |
|---|---|---|
| Site errors right after a DB import | `terminus drush $SITE.dev -- status`, `updatedb:status` | Database and code don't match. Run `drush updatedb -y`, or import the database that was upgraded with this exact code |
| Missing images | `tar -tzf files.tar.gz \| head` | The archive has an extra top-level `files/` folder. Re-create it with `tar -C .../files .` and re-import |
| Image styles 404 | Browser network tab | Derivatives regenerate on demand. Check that `styles/` is not blocked and that the files directory is writable |
| Private files 403 for authorized users | `drush status --field=private` | Private path must be `sites/default/files/private` on Pantheon. Check field storage `uri_scheme` |
| Counts differ after import | `reconcile-counts.sh --compare` | Wrong snapshot or the freeze was not held. Find the first differing metric and re-import the correct snapshot |
| Test has the wrong content | Dashboard workflow history | `env:clone-content` source/target swapped. Restore Test from backup and repeat |

## Cutover and production

| Symptom | Diagnose | Fix |
|---|---|---|
| HTTPS certificate warning after DNS switch | `terminus https:info $SITE.live` | Certificate not provisioned yet. Pre-provision with domain verification before the next attempt. Wait for issuance |
| Some users still see the old site | `dig +short www.agency.example @8.8.8.8` | DNS caching: TTL was not lowered in time. Keep the old site frozen until TTL expires |
| Redirect loop | `curl -sIL https://www.agency.example` | Duplicate HTTPS/primary-domain redirects in `settings.php` and the dashboard. Keep one |
| Logged-in pages cached for anonymous users | Response headers (`Cache-Control`, `Age`) | Custom code setting cache headers or `Vary` incorrectly. Review page cache settings |
| Forms submit but no email | Recent log messages, SMTP provider logs | Pantheon's local mail is not suitable for production. Configure an SMTP or API mail service |
| Rollback requested after new writes | `reconcile-counts.sh --compare` against the freeze counts | Follow [Step 33](08-monitoring-rollback.md): freeze, preserve, reconcile, then revert DNS |

## Getting more detail

```bash
terminus drush "$SITE.dev" -- watchdog:show --count=50
terminus drush "$SITE.dev" -- core:requirements --severity=1
DRUSH="terminus drush $SITE.dev --" scripts/verify-upgrade.sh
scripts/pantheon-health-check.sh "$SITE" dev
```

Previous: [09 · Demo lab](09-demo-lab.md) · Back to [README](../README.md)
