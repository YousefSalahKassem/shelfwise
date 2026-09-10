# W6 — *Could* features

Roadmap items from business plan §6 (*Could*). Build them only when pilot feedback or a paying brand asks for them. Each section is a self-contained agent brief.

## Wave rules

- F1–F5 need **W5 (sync)** merged. F6 needs D5 (suppliers). F7 needs D4 (multi-branch).
- Items marked 💳 need paid services (Firebase Blaze / Cloud Functions, WhatsApp Business Platform, a payment gateway). Get the owner's budget approval before starting them.
- Same ownership, migration and flag rules as W4.

---

## F1 — API & webhooks 💳 (Chain)

| **Flag** `api` | **Owns** `firebase/functions/api/**`, `tools/api_docs/**`, `lib/features/api_keys/**` |
|---|---|

- [ ] REST API over Cloud Functions: products, categories, stock levels, movements (read), stock adjustments and price updates (write) — scoped by an API key per brand/store
- [ ] Webhooks: `stock.low`, `stock.out`, `price.changed`, `movement.created` with signed payloads (HMAC) and retries
- [ ] API key management screen (owner or brand admin); OpenAPI spec + docs site

**Acceptance:** a Postman collection runs green; a revoked key is rejected; a webhook retries with backoff.

---

## F2 — POS & e-commerce sync 💳 (Chain)

| **Flag** `posSync` | **Owns** `firebase/functions/connectors/**`, `lib/features/integrations/**` |
|---|---|

- [ ] Connector framework: map external product ↔ ShelfWise product (by barcode/SKU), then pull sales → `sale` movements
- [ ] First connector chosen from pilot demand (candidates: a regional e-commerce platform or a POS with a public API). One connector per agent task.
- [ ] Mapping review screen for unmatched items; sync status and error log

**Acceptance:** a test order in the external system deducts stock within 5 min; the same order is never deducted twice.

---

## F3 — Single sign-on (Chain)

| **Flag** `sso` | **Owns** `lib/features/sso/**` |
|---|---|

- [ ] Google and Microsoft sign-in through Firebase Auth providers (free); map the email domain to a chain
- [ ] SAML/OIDC for enterprise identity providers needs Google Identity Platform 💳 — separate follow-up task

**Acceptance:** a chain employee signs in with their company Google account and lands in the correct store with the correct role.

---

## F4 — WhatsApp alerts 💳 (Aisle+)

| **Flag** `whatsappAlerts` | **Owns** `firebase/functions/whatsapp/**`, alert preference UI in `lib/features/alerts/remote/**` (coordinate with the E2 owner) |
|---|---|

- [ ] Daily low-stock summary and critical out-of-stock alert through WhatsApp Business Platform approved templates (AR/EN)
- [ ] Opt-in per owner number; per-brand sender number setup doc

**Acceptance:** the template is approved and the message is received on a test number; opt-out is respected.

---

## F5 — In-app billing for brands 💳

| **Flag** `billing` | **Owns** `firebase/functions/billing/**`, `tools/reseller_console/billing/**` |
|---|---|

- [ ] Brands set a store price and collect subscriptions through a regional payment gateway (choose based on brand country)
- [ ] Payment status → store active or suspended (reuses the E3 suspension); invoices list; ShelfWise wholesale fee report per brand (business plan §5)

**Acceptance:** a test card payment activates a store; a failed renewal suspends it after a grace period.

---

## F6 — Smart reorder suggestions (Chain; local-capable)

| **Flag** `smartReorder` | **Owns** `lib/features/smart_reorder/**` · **needs** D5 |
|---|---|

- [ ] Sales velocity per product from `sale` movements (exponentially weighted, 28-day window, weekday pattern)
- [ ] Suggested reorder point = velocity × supplier lead time + safety stock; suggested order qty = cover N days
- [ ] "Apply suggestions" per category with a preview (reuses the reorder-point use cases)

**Acceptance:** backtest on seed data reduces simulated stock-outs versus fixed reorder points; suggestions are explainable ("sells ~4/day, supplier takes 3 days").

---

## F7 — Multi-currency (Chain)

| **Flag** `multiCurrency` | **Owns** `lib/features/currency/**`; table `exchange_rates` · **needs** D4 |
|---|---|

- [ ] Currency per branch; manual exchange rates with an effective date
- [ ] Reports and dashboard in a chosen reporting currency; `Money` never mixes currencies (typed guard + tests)

**Acceptance:** a two-country chain sees consolidated stock value in its reporting currency; per-branch views stay in local currency.
