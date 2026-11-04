<?php

namespace App\Console\Commands;

use App\Models\Currency;
use App\Models\ExchangeRateHistory;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class SnapshotExchangeRates extends Command
{
    protected $signature = 'currency:snapshot-rates';

    protected $description = 'Record daily snapshots of configured currency exchange rates';

    public function handle(): int
    {
        $today = now()->toDateString();

        DB::transaction(function () use ($today): void {
            $currencies = Currency::query()
                ->where('is_active', true)
                ->orderBy('id')
                ->get();

            foreach ($currencies as $currency) {
                $alreadyRecorded = ExchangeRateHistory::query()
                    ->where('currency_id', $currency->id)
                    ->where('source', 'daily_snapshot')
                    ->whereDate('recorded_at', $today)
                    ->exists();

                if ($alreadyRecorded) {
                    continue;
                }

                ExchangeRateHistory::create([
                    'currency_id' => $currency->id,
                    'exchange_rate' => $currency->exchange_rate,
                    'source' => 'daily_snapshot',
                    'recorded_at' => now(),
                    'changed_by' => null,
                    'metadata' => [
                        'snapshot_date' => $today,
                    ],
                ]);
            }
        });

        $this->info('Daily exchange-rate snapshots recorded.');

        return self::SUCCESS;
    }
}