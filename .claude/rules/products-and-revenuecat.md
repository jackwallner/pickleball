---
paths:
  - "DuprIQ/DuprIQ.storekit"
  - "Shared/Services/SubscriptionService.swift"
  - "DuprIQ/Views/PaywallView.swift"
  - "scripts/rc-*.py"
---

# DUPR IQ: products and RevenueCat

Moved verbatim from AGENTS.md. Loads when a matching file is read; update it here.

## Products
Local StoreKit configuration (`DuprIQ/DuprIQ.storekit`):

- `com.jackwallner.pickleball.pro.monthly`, $9.99 / month, one-week trial
- `com.jackwallner.pickleball.pro.yearly`, $59.99 / year, one-week trial
- `com.jackwallner.pickleball.pro.lifetime`, $99.99 one time

This is above the Vitals default on purpose. Pickleball coaching is an
already-paying audience (lessons, not exam prep), and the DUPR-adjacent
positioning has to look like a coaching product. Change it only with an
explicit pricing pass.

The public `appl_` key ships in `SubscriptionService` behind the DEBUG
placeholder and the simulator early-return. The `sk_` secret lives in
`~/.pickleball_credentials` as `RC_SECRET_KEY`, the fleet convention that every
`scripts/rc-*.py` reads. `.env.local` still carries a gitignored copy for local
tooling; keep the two in sync or delete the copy.

**Re-run `scripts/rc-setup.py` after touching products or offerings**, then probe
with the iOS platform header. The fleet's recurring empty-offering bug (an
offering holding only Test Store products, which iOS filters out, leaving a dead
paywall on device) cannot be caught on a simulator, because a simulator never
configures RevenueCat:

```sh
curl -s -H "Authorization: Bearer appl_FgwCPdxYFGQtaPKOJeuxwZBsrNZ" \
     -H "X-Platform: ios" \
     https://api.revenuecat.com/v1/subscribers/probe-1/offerings
```
