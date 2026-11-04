<div class="space-y-6">
    <div class="grid grid-cols-1 gap-4 md:grid-cols-3">
        <x-filament::section>
            <div class="text-sm text-gray-500 dark:text-gray-400">
                Tracked Currencies
            </div>
            <div class="mt-2 text-3xl font-bold">
                {{ $rates->count() }}
            </div>
            <div class="mt-1 text-sm text-gray-500">
                {{ $activeCount }} active
            </div>
        </x-filament::section>

        <x-filament::section>
            <div class="text-sm text-gray-500 dark:text-gray-400">
                Default Currency
            </div>
            <div class="mt-2 text-3xl font-bold">
                {{ $defaultCurrency?->code ?? 'Not set' }}
            </div>
            <div class="mt-1 text-sm text-gray-500">
                {{ $defaultCurrency?->name ?? 'Choose an active default currency' }}
            </div>
        </x-filament::section>

        <x-filament::section>
            <div class="text-sm text-gray-500 dark:text-gray-400">
                Latest History Entry
            </div>
            <div class="mt-2 text-lg font-semibold">
                @if ($lastUpdated)
                    {{ \Illuminate\Support\Carbon::parse($lastUpdated)->format('d M Y, H:i') }}
                @else
                    No history yet
                @endif
            </div>
            <div class="mt-1 text-sm text-gray-500">
                Based on recorded exchange-rate changes
            </div>
        </x-filament::section>
    </div>

    <x-filament::section>
        <x-slot name="heading">
            Exchange Rate Board
        </x-slot>

        <x-slot name="description">
            Rates are currency units per 1 USD. Changes compare the current
            rate with the previous recorded rate, not necessarily yesterday's rate.
        </x-slot>

        <div class="mb-4 flex justify-end">
            <x-filament::button wire:click="refreshRates" wire:loading.attr="disabled" wire:target="refreshRates"
                icon="heroicon-o-arrow-path">
                <span wire:loading.remove wire:target="refreshRates">
                    Refresh Automatic Rates
                </span>
                <span wire:loading wire:target="refreshRates">
                    Refreshing...
                </span>
            </x-filament::button>
        </div>

        <div class="overflow-x-auto">
            <table class="w-full divide-y divide-gray-200 dark:divide-white/10">
                <thead>
                    <tr class="text-left text-sm text-gray-500 dark:text-gray-400">
                        <th class="px-3 py-3">Currency</th>
                        <th class="px-3 py-3">Current Rate</th>
                        <th class="px-3 py-3">Previous Rate</th>
                        <th class="px-3 py-3">Change</th>
                        <th class="px-3 py-3">Last Recorded</th>
                        <th class="px-3 py-3">Mode / Status</th>
                    </tr>
                </thead>

                <tbody class="divide-y divide-gray-200 dark:divide-white/10">
                    @forelse ($rates as $rate)
                    <tr>
                        <td class="px-3 py-4">
                            <div class="font-semibold">
                                {{ $rate['currency']->code }}
                                <span class="text-gray-500">
                                    ({{ $rate['currency']->symbol }})
                                </span>
                            </div>
                            <div class="text-sm text-gray-500">
                                {{ $rate['currency']->name }}
                            </div>

                            @if ($rate['currency']->is_default)
                                <span
                                    class="mt-1 inline-flex rounded-full bg-primary-50 px-2 py-1 text-xs font-medium text-primary-700 dark:bg-primary-400/10 dark:text-primary-300">
                                    Default
                                </span>
                            @endif
                        </td>

                        <td class="px-3 py-4 font-semibold tabular-nums">
                            {{ number_format($rate['current_rate'], 8, '.', ',') }}
                        </td>

                        <td class="px-3 py-4 tabular-nums">
                            @if ($rate['previous_rate'] !== null)
                                {{ number_format($rate['previous_rate'], 8, '.', ',') }}
                            @else
                                <span class="text-gray-400">—</span>
                            @endif
                        </td>

                        <td class="px-3 py-4">
                            @if ($rate['change_percent'] !== null)
                            @php($change = $rate['change_percent'])

                                <span
                                    class="{{ $change > 0 ? 'text-success-600 dark:text-success-400' : ($change < 0 ? 'text-danger-600 dark:text-danger-400' : 'text-gray-500') }}">
                                    {{ $change > 0 ? '+' : '' }}{{ number_format($change, 4) }}%
                                </span>
                            @else
                            <span class="text-gray-400">
                                No comparison yet
                            </span>
                            @endif
                        </td>

                        <td class="px-3 py-4 text-sm">
                            @if ($rate['last_recorded_at'])
                                {{ $rate['last_recorded_at']->format('d M Y, H:i') }}
                            @else
                                <span class="text-gray-400">
                                    No history yet
                                </span>
                            @endif
                        </td>

                        <td class="px-3 py-4">
                            <div class="mb-2 text-sm">
                                {{ ucfirst($rate['currency']->rate_update_mode ?? 'automatic') }}
                            </div>

                            @if ($rate['currency']->is_active)
                                <span
                                    class="inline-flex rounded-full bg-success-50 px-2 py-1 text-xs font-medium text-success-700 dark:bg-success-400/10 dark:text-success-300">
                                    Active
                                </span>
                            @else
                                <span
                                    class="inline-flex rounded-full bg-gray-100 px-2 py-1 text-xs font-medium text-gray-600 dark:bg-white/10 dark:text-gray-300">
                                    Inactive
                                </span>
                            @endif
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="6" class="px-3 py-8 text-center text-gray-500">
                            No currencies have been configured yet.
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </x-filament::section>
</div>