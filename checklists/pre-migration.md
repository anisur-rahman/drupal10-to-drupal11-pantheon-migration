# Pre-migration checklist

Complete before the first Pantheon import. Phase docs: [01](../docs/01-discovery.md) · [02](../docs/02-backup-local-setup.md) · [03](../docs/03-drupal11-upgrade.md)

## Access and ownership
- [ ] Source Git, SSH/Drush, database and Drupal admin access confirmed
- [ ] Pantheon organization role confirmed. Terminus machine token and SSH key working
- [ ] DNS provider access confirmed. Current records exported
- [ ] Integration consoles (SMTP, SSO, CRM, payment, search, CDN/WAF) accessible
- [ ] Owners named: technical lead, go/no-go owner, rollback owner, business sign-off

## Inventory
- [ ] Drupal, PHP, database server, Drush and Composer versions recorded
- [ ] Contrib modules and themes listed with versions
- [ ] Custom modules, themes, profiles and patches listed
- [ ] `settings.php` overrides documented (private path, trusted hosts, reverse proxy, config sync, caches)
- [ ] Integrations, IP allow-lists and outbound endpoints listed
- [ ] Server cron, queue workers and scripts listed, with a Pantheon equivalent for each
- [ ] Database and files sizes measured

## Drupal 11 readiness
- [ ] Source on Drupal 10.3 or later
- [ ] `drupal11-readiness.sh` passes (PHP 8.3, MariaDB 10.6 / MySQL 8.0, removed modules handled)
- [ ] Upgrade Status clean for all enabled projects
- [ ] Every blocker has a decision (update, patch, replace, remove) and an owner

## Backups
- [ ] Database, public files, private files and Git commit backed up with checksums
- [ ] Backups stored encrypted, outside Git, with restricted access
- [ ] A restore has been tested (DDEV copy works)
- [ ] Baseline counts recorded (`reconcile-counts.sh`)
