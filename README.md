# NaNa Wallet — Project

This repository combines the NaNa Wallet Flutter client and Laravel API source for convenient school-project review.

## Repository layout

- `frontend/` — Flutter mobile application
- `backend/` — Laravel API, migrations, tests, Docker configuration, and deployment documentation

Each subproject retains its own README with setup instructions. The mobile app's API URL is injected at build time using `API_BASE_URL`; for the hosted school demo, use `https://nana-wallet-api.onrender.com/api` as described in `frontend/README.md`.
