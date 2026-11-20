# Free/sandbox practice lab

Use a disposable Drupal 10 site in DDEV as the source and a Pantheon development site as the target. Check Pantheon's current sandbox eligibility, quotas, and pricing before creating the destination.

```bash
mkdir -p ~/projects/drupal10-lab && cd ~/projects/drupal10-lab
ddev config --project-type=drupal10 --docroot=web --php-version=8.3
ddev start
ddev composer create-project 'drupal/recommended-project:^10' .
ddev composer require drush/drush
ddev drush site:install standard -y
ddev drush status
```

Add test pages and images, take a database snapshot, then follow [Drupal upgrade](03-drupal11-upgrade.md). Avoid using `admin123` or other weak passwords on a publicly accessible site.
