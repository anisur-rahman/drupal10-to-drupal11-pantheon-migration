# Production cutover checklist
- [ ] Approved change window and abort time
- [ ] DNS records/TTL and certificate plan documented
- [ ] Source writes and jobs frozen
- [ ] Final source DB/files snapshot verified
- [ ] Final Drupal 10 → 11 upgrade and reconciliation passed
- [ ] Pantheon Live code and matching DB/files deployed
- [ ] HTTPS, DNS, forms and logins verified
- [ ] Writes/jobs enabled only on authoritative host
- [ ] Go/no-go approval recorded
