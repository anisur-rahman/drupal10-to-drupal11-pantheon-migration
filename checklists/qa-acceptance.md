# QA acceptance checklist

Run on Pantheon Test. Phase doc: [06 · Testing and QA](../docs/06-testing-qa.md)

## Platform
- [ ] `pantheon-health-check.sh SITE test` reports HEALTHY
- [ ] Drupal 11, PHP 8.3+, no pending database updates, no status-report errors
- [ ] Configuration matches the sync directory (if config is managed in Git)
- [ ] Cron has run. Queues are processing
- [ ] Counts match the source snapshot (`reconcile-counts.sh --compare`)

## Content and editing
- [ ] Each content type: create, edit, revise, publish, unpublish, delete
- [ ] CKEditor 5: formatting, links, embedded media, tables, source editing (per text format)
- [ ] Media library upload and reuse. Image styles render
- [ ] Menus, blocks, taxonomy and Views pages
- [ ] Content moderation / workflows (if used)

## Users and access
- [ ] Admin and each role can log in (SSO / SAML / LDAP if used)
- [ ] Permissions match production. Unpublished and restricted content is hidden
- [ ] Password reset email arrives

## Forms and integrations
- [ ] Webforms submit. Confirmations and handlers fire. Emails delivered
- [ ] Each integration in the inventory tested against its sandbox endpoint
- [ ] Private file downloads: allowed for authorized users, denied to anonymous users

## URLs and SEO
- [ ] Path aliases resolve. Redirects from old URLs work
- [ ] Canonical URLs, metatags, `sitemap.xml` and `robots.txt` correct
- [ ] 404 and 403 pages render with the site theme

## Quality
- [ ] Accessibility: automated scan plus keyboard and screen-reader spot checks (WCAG 2.2 AA)
- [ ] Performance: key pages cached by the CDN. Response times acceptable
- [ ] Security: `composer audit` clean, no debug output, admin routes require login
- [ ] Browser and device matrix checked

## Sign-off
- [ ] No open critical or high defects, or defects accepted in writing
- [ ] Business owner approval recorded
