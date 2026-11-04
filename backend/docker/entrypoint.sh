#!/bin/sh
set -eu

port="${PORT:-10000}"
case "$port" in
    *[!0-9]*|'') echo "PORT must be numeric" >&2; exit 1 ;;
esac

# Run migrations only when explicitly opted in for an approved setup step.
if [ "${RUN_MIGRATIONS_ON_START:-false}" = "true" ]; then
    php artisan migrate --force
fi

# Seed reference data only when explicitly approved; never run DatabaseSeeder here.
if [ "${RUN_REFERENCE_SEEDERS_ON_START:-false}" = "true" ]; then
    php artisan db:seed --class=CurrencySeeder --force
    php artisan db:seed --class=SystemSettingSeeder --force
fi

# Create the demo funder only for an explicitly approved one-time setup.
if [ "${RUN_DEMO_FUNDER_SEEDER_ON_START:-false}" = "true" ]; then
    php artisan db:seed --class=DemoFunderSeeder --force
fi

# Render assigns PORT at runtime; bind Apache to that port.
sed -i "s/^Listen 80$/Listen ${port}/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:10000>/<VirtualHost *:${port}>/" /etc/apache2/sites-available/000-default.conf

# Do not run migrations automatically at container startup. Apply them as an
# explicitly reviewed deployment step after confirming the production database.
exec "$@"
