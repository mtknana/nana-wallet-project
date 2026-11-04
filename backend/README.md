# NaNa Wallet API

Laravel API for NaNa Wallet, including Quick Loan applications and repayments. This repository contains backend source only; the Flutter/Android client is in the full-project archive.

## Local setup

Use PHP 8.3+ and Composer:

```sh
composer install
cp .env.example .env
php artisan key:generate
```

Configure a local database, then run `php artisan migrate`. The test suite uses isolated SQLite:

```sh
php artisan test
```

Current regression coverage includes repayment idempotency, changed-amount key reuse, and USD/KHR precision. Never run `migrate:fresh` against a hosted database.

## Render demo status

The demo API is at [`https://nana-wallet-api.onrender.com/api`](https://nana-wallet-api.onrender.com/api). On 2026-11-01, all 42 migrations were applied to its Render PostgreSQL database. The initial reference-data setup added 135 currencies and 7 default system settings only; it did not create users, wallets, balances, loans, or transactions. On 2026-11-02, the separate one-time hook created `demo-funder@nanawallet.test` as an admin with an active $10,000 USD wallet and matching opening deposit audit record; these are simulated funds only, and the startup flag was returned to `false`. Registration can create a user's zero-balance USD and KHR wallets. New accounts, balances, transactions, and loans are stored in Render PostgreSQL, not in the Android APK.

The Render `APP_KEY` is configured privately. Keep all keys and database URLs in Render environment settings, never in Git. This is a short-lived school demo database: use fake data only, and remember that Render Free Postgres expires and does not include managed backups.

## Controlled setup hooks

The Docker entrypoint does not run migrations or seeders by default. For an explicitly approved setup only:

- `RUN_MIGRATIONS_ON_START=true` runs `php artisan migrate --force` once at startup.
- `RUN_REFERENCE_SEEDERS_ON_START=true` runs only `CurrencySeeder` and `SystemSettingSeeder`.
- `RUN_DEMO_FUNDER_SEEDER_ON_START=true` runs only `DemoFunderSeeder`, which creates the `demo-funder@nanawallet.test` admin and a $10,000 USD simulated opening balance if missing. It never tops up or resets an existing wallet.

Set the relevant variable back to `false` immediately after the setup deployment. Do **not** run the general `DatabaseSeeder` against the public demo; it creates a hard-coded `test@example.com` account. The reference seeders and demo-funder seeder are idempotent.

## Loan scheduler

The due-loan command is registered in `routes/console.php`, but this Render workspace currently has no Cron Job configured. Therefore, automatic due-date repayments will not run on the hosted demo until a scheduler service runs `php artisan schedule:run` every minute. Manual repayments are available independently. Confirm provider plan/cost before adding a recurring service.

## Verification

- Laravel test suite: 8 tests, 27 assertions, using isolated SQLite.
- All 42 migrations completed on Render PostgreSQL; `loans`, `loan_repayments`, and `transactions` tables were verified.
- A safe unauthenticated API request with `Accept: application/json` returned the expected 401 response.
- Full signup, wallet funding, transfers, and loan lifecycle testing with a physical phone has not yet been completed.

The API repository includes the PHP 8.3/Apache Docker runtime and is separate from the Android APK. The Android package ID is still a placeholder and the provided APK is debug-signed; do not use it as a Play Store release build.
