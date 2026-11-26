# STIKZO — New Storefront & Owner Dashboard

This is a fresh rebuild based on the two supplied STIKZO screenshots. It does **not** reuse the old site's application code. The embedded brand logo was reused as an image asset only.

## Included
- Responsive STIKZO storefront in orange / black / white
- Category filters, search, product detail routes (`/product/<slug>`), cart and COD checkout
- Owner login, dashboard statistics, order status updates, product management and customer list
- Copy/share product links
- Supabase schema with Row Level Security
- Cloudflare Pages Function for server-side COD order creation and price/stock checks
- Cloudflare Pages SPA fallback

## Important status
This ZIP is a migration-ready starter project, not a deployed or live-tested store. You must connect your own Supabase project and deploy it before real customers can place orders. Do not advertise it as live until you test the deployed site and order flow.

## Requirements
- Node.js 20+
- Free GitHub account
- Supabase project (Free plan, subject to Supabase quotas/pausing/limits)
- Cloudflare account and Cloudflare Pages (free plan limits apply)

## 1. Install locally
```bash
npm install
cp .env.example .env
npm run dev
```
Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in `.env`.

## 2. Configure Supabase
1. Create a Supabase project.
2. Open SQL Editor and run `supabase/schema.sql`.
3. In Authentication, create your owner user with email/password.
4. Copy that user's UUID from Authentication → Users.
5. Run the owner promotion SQL at the bottom of `schema.sql`, replacing the placeholder UUID.
6. In Project Settings → API, copy Project URL and anon/public key into `.env`.
7. Never put the `service_role` key in `.env` or frontend code.

## 3. Configure Cloudflare Pages secrets
Connect your GitHub repository to Cloudflare Pages:
- Framework preset: Vite
- Build command: `npm run build`
- Build output directory: `dist`

In Cloudflare Pages → Settings → Variables and Secrets, add:
- `SUPABASE_URL` = Supabase Project URL
- `SUPABASE_SERVICE_ROLE_KEY` = Supabase service_role key (secret; server-side Pages Function only)

In Pages environment variables for the build, add:
- `VITE_SUPABASE_URL` = Supabase Project URL
- `VITE_SUPABASE_ANON_KEY` = Supabase anon/public key

Redeploy after setting variables. Do not expose the service role key in any VITE_ variable.

## 4. Product images
Create/verify the `product-images` bucket. Upload product photos from Supabase Storage and paste each public image URL into the product's Image URL field. The schema contains public-read and owner-write policies.

## 5. Add products
Sign in at the Owner login link. Add product details and a public image URL. Product slug is generated from its name. For custom quantity pricing, edit the `quantity_prices` JSON in Supabase Table Editor, for example:
```json
[{"qty":1,"total":750},{"qty":2,"total":1400},{"qty":3,"total":2000},{"qty":4,"total":2500}]
```
The order API checks exact quantity slabs and falls back to unit price × quantity.

## 6. Test before launch
- Browse `/` in a private/incognito browser.
- Open a product URL `/product/test-backpack` directly and refresh.
- Add products to cart, change quantities, and verify totals.
- Place a COD test order with a test address.
- Verify the order, customer, order items and stock changes in Supabase.
- Sign in as owner and update the order status.
- Test the product share URL on another phone/browser.

## Security and limitations to understand
- Public product browsing uses the anon key and RLS. Customer/order records are not public.
- The COD order endpoint uses a server-side service role secret; never put it in frontend code.
- Owner login is Supabase Auth. The owner must be promoted to `role='owner'` in `profiles`.
- This starter uses browser-based admin polling/refresh; it does not yet provide reliable push notifications when the owner dashboard is closed.
- Product image URLs are currently entered in the product form; direct in-dashboard file upload UI is a follow-up enhancement.
- Reviews are represented in the database schema; customer verified-review workflow and moderation UI are not yet implemented.
- Quantity slab editing is currently via Supabase Table Editor, not an admin form.
- Customer records are created/updated when an order is placed; there is no mandatory customer account for browsing.
- Free tiers can change, impose quotas, pause inactive projects, or require paid upgrades. No provider can guarantee lifetime free hosting.
- The order endpoint is a starter implementation. Before production use, add database-side transactional stock reservation/idempotency and rate limiting to protect against simultaneous orders and repeated requests.

## Troubleshooting
- `Could not fetch products`: check Supabase URL/key and run schema.
- Owner login denied: verify Auth user exists and its UUID has `role='owner'` in `profiles`.
- API says server database is not configured: set Cloudflare Pages `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`, then redeploy.
- Direct product URL gives 404: verify `public/_redirects` is deployed.

## Environment variables
### Frontend build variables
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

### Cloudflare Pages Function secrets
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
