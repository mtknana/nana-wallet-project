<?php

namespace App\Console\Commands;

use App\Services\ExchangeRateProviderService;
use Illuminate\Console\Command;

class RefreshExchangeRates extends Command
{
    protected $signature = 'currency:refresh-rates';

    protected $description =
        'Refresh automatically managed currency exchange rates';

    public function handle(
        ExchangeRateProviderService $provider
    ): int {
        $this->info('Refreshing automatic exchange rates...');

        $result = $provider->refreshAutomaticRates();

        if (!$result['success']) {
            $this->error($result['message']);

            return self::FAILURE;
        }

        $this->info($result['message']);

        if (!empty($result['updated'])) {
            $this->line(
                'Updated: ' . implode(', ', $result['updated'])
            );
        }

        if (!empty($result['unchanged'])) {
            $this->line(
                'Unchanged: ' . implode(', ', $result['unchanged'])
            );
        }

        if (!empty($result['skipped'])) {
            $this->warn(
                'Skipped: ' . implode('; ', $result['skipped'])
            );
        }

        return self::SUCCESS;
    }
}