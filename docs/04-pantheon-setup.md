# 04 · Pantheon setup (Steps 13–18)

**Goal:** create a Composer-managed Drupal site on Pantheon, merge the release-candidate application into Pantheon's scaffold without breaking it, and get a green Integrated Composer build on Dev.

> Pantheon's dashboard, plans and Terminus options change over time. Check the linked Pantheon docs for the current behavior before running commands.

---

## Step 13 — Create the destination site

Create the site from the **Drupal (Composer-managed)** upstream in the dashboard, or with Terminus:

```bash
export SITE=drupal11-migration-demo
export ORG="Agency Web Team"                 # optional
terminus site:create "$SITE" "Agency Drupal 11" drupal-composer-managed --org="$ORG"
terminus site:info "$SITE"
```

Do **not** run the Drupal installer on Dev. The database will come from your upgraded site in Step 20.

**Expected result:** the site exists with a Dev environment and the Composer-managed upstream.
**Evidence:** `site:info` output (site ID, upstream, organization).

## Step 14 — Authenticate Terminus and SSH

```bash
terminus auth:login --machine-token="$PANTHEON_MACHINE_TOKEN"   # token from the dashboard, kept in a password manager
terminus auth:whoami
terminus ssh-key:add ~/.ssh/id_ed25519.pub
../drupal10-to-drupal11-pantheon-migration/scripts/check-requirements.sh
```

**Expected result:** `auth:whoami` shows your account, and the requirements check passes the Pantheon section.
**Evidence:** requirements output. Never paste the machine token into the ticket.

## Step 15 — Clone the Pantheon repository

```bash
terminus connection:set "$SITE.dev" git
GIT_URL="$(terminus connection:info "$SITE.dev" --field=git_url)"
git clone "$GIT_URL" pantheon-drupal11
cd pantheon-drupal11
git branch -a                  # Pantheon deploys the master branch to Dev
cat pantheon.upstream.yml      # build_step: true -> Integrated Composer
cat composer.json
ls web/sites/default           # settings.php includes settings.pantheon.php
```

**Expected result:** you can identify the deployment branch (`master`), the upstream config files, and Pantheon's `settings.php`.
**Evidence:** note the initial commit hash of the Pantheon repo.

## Step 16 — Configure the platform: `pantheon.yml`

Pantheon reads `pantheon.yml` (site-specific) on top of `pantheon.upstream.yml` (from the upstream). Set what Drupal 11 needs:

```yaml
api_version: 1
php_version: 8.3
database:
  version: 10.6        # Drupal 11 requires MariaDB 10.6+
```

See [examples/pantheon.yml](../examples/pantheon.yml). Keep `build_step` and `web_docroot` in the upstream file, not here.

Also review:

- **`settings.php`**: keep Pantheon's version, which includes `settings.pantheon.php` (database credentials, hash salt, file paths). Port only your custom settings into it. Never hard-code database credentials.
- **Private files**: on Pantheon they live at `sites/default/files/private`, which `settings.pantheon.php` already configures.
- **Config sync directory**: confirm `$settings['config_sync_directory']` points to where your exported config will live (commonly `../config`).
- **Services**: Redis (`terminus redis:enable`, plus the `drupal/redis` module), Solr (`drupal/search_api_pantheon`), and New Relic as needed, depending on the plan.

**Expected result:** a reviewed `pantheon.yml` and `settings.php` diff.
**Evidence:** the diff in the pull request.

## Step 17 — Merge the release candidate into Pantheon's scaffold

Bring over **requirements and custom code**, not the whole old repository. Pantheon's upstream already provides the scaffold, `drupal-integrations` and the build configuration.

```bash
SRC=../source-drupal

# 1. Contrib requirements: require each package your source project needs, with its constraint
jq -r '.require | to_entries[] | select(.key | test("^(drupal/core|composer/installers|cweagans|oomphinc)") | not) | "\(.key):\(.value)"' \
  "$SRC/composer.json"                      # review this list first
jq -r '.require | to_entries[] | select(.key | test("^(drupal/core|composer/installers|cweagans|oomphinc)") | not) | "\(.key):\(.value)"' \
  "$SRC/composer.json" | xargs composer require --no-update

# 2. Patches and repositories: copy the "extra.patches" and "repositories" entries by hand, then
composer require cweagans/composer-patches --no-update   # only if patches are used

# 3. Custom code and configuration
rsync -a "$SRC/web/modules/custom/" web/modules/custom/
rsync -a "$SRC/web/themes/custom/"  web/themes/custom/
rsync -a "$SRC/config/" config/                          # if config is managed in Git

# 4. Resolve and lock
composer update --with-all-dependencies
composer show drupal/core pantheon-systems/drupal-integrations
git status
```

Check before you commit: `composer.lock` resolves to the same Drupal 11 core as the release candidate, `pantheon-systems/drupal-integrations` is still required, Pantheon's `.gitignore` still excludes `vendor/` and `web/core/`, and no `settings.local.php`, dumps or files are staged.

```bash
git add composer.json composer.lock pantheon.yml web/modules/custom web/themes/custom config
git commit -m "Migrate Drupal 11 release candidate (source commit $(git -C "$SRC" rev-parse --short HEAD))"
```

**Expected result:** a single reviewable commit on top of Pantheon's scaffold.
**Evidence:** commit hash, and the source commit it corresponds to.

## Step 18 — Push to Dev and verify the build

```bash
git push origin master
terminus workflow:list "$SITE" | head
terminus env:code-log "$SITE.dev" | head -n 5
```

Integrated Composer runs `composer install` on Pantheon after each push. If the build fails, open the dashboard's build log. Common causes are a private repository without credentials, a patch that no longer applies, and a platform requirement mismatch (the PHP version in `pantheon.yml`).

**Expected result:** the build succeeds. Dev serves an installer or database error at this point because there is no database yet. That is expected.
**Evidence:** successful workflow entry and the deployed commit hash.

---

## Exit gate

- [ ] Site created from the Composer-managed upstream. The installer was not run
- [ ] Terminus and SSH key working
- [ ] `pantheon.yml` sets PHP 8.3 and MariaDB 10.6+
- [ ] Custom settings ported into Pantheon's `settings.php`. No credentials committed
- [ ] Release candidate merged as a reviewed commit
- [ ] Integrated Composer build green on Dev

Previous: [03 · Drupal 11 upgrade](03-drupal11-upgrade.md) · Next: [05 · Database and files migration](05-database-files-migration.md)
