# NaNa Wallet — Project Monorepo

This private repository combines the NaNa Wallet Flutter client and Laravel API source for convenient school-project review.

## Repository layout

- `frontend/` — Flutter mobile application
- `backend/` — Laravel API, migrations, tests, Docker configuration, and deployment documentation

Each subproject retains its own README with setup instructions. The mobile app's API URL is injected at build time using `API_BASE_URL`; for the hosted school demo, use `https://nana-wallet-api.onrender.com/api` as described in `frontend/README.md`.

## Important deployment note

This monorepo is a source-code copy for organization and handoff. The existing Render service continues to deploy from the original `mtknana/nana-wallet-api` repository; creating this monorepo does not change or redeploy the live API. Keep Render credentials, `.env` files, signing keys, and production secrets out of GitHub. The monorepo contains no database data or APK binaries.
