<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Currency;
use App\Models\ExchangeRateHistory;
use App\Services\CurrencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class CurrencyController extends Controller
{
    private function authorizeAdmin(Request $request): void
    {
        abort_unless(
            $request->user()?->role === 'admin',
            403,
            'Administrator access required.'
        );
    }

    /**
     * GET /api/currencies
     * List active currencies.
     */
    public function index(): JsonResponse
    {
        $currencies = Currency::query()
            ->where('is_active', true)
            ->orderByDesc('is_default')
            ->orderBy('code')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $currencies,
        ]);
    }

    /**
     * GET /api/admin/currencies
     * List all currencies for administrators.
     */
    public function adminIndex(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);

        return response()->json([
            'status' => 'success',
            'data' => Currency::query()
                ->orderByDesc('is_default')
                ->orderBy('code')
                ->get(),
        ]);
    }

    /**
     * POST /api/admin/currencies
     * Create a currency and record its initial exchange rate.
     */
    public function store(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'code' => [
                'required',
                'string',
                'size:3',
                'alpha',
                'uppercase',
                'unique:currencies,code',
            ],
            'name' => ['required', 'string', 'max:100'],
            'symbol' => ['required', 'string', 'max:10'],
            'exchange_rate' => [
                'required',
                'numeric',
                'gt:0',
                'max:9999999999',
            ],
            'decimal_places' => [
                'required',
                'integer',
                'between:0,6',
            ],
            'rate_update_mode' => [
                'sometimes',
                Rule::in(['automatic', 'manual']),
            ],
            'is_active' => ['sometimes', 'boolean'],
            'is_default' => ['sometimes', 'boolean'],
        ]);

        $currency = DB::transaction(function () use ($validated) {
            $isDefault = (bool) ($validated['is_default'] ?? false);

            if ($isDefault) {
                Currency::query()->update(['is_default' => false]);
            }

            $currency = Currency::create([
                ...$validated,
                'rate_update_mode' => $validated['rate_update_mode'] ?? 'automatic',
                'is_active' => $validated['is_active'] ?? true,
                'is_default' => $isDefault,
            ]);

            ExchangeRateHistory::create([
                'currency_id' => $currency->id,
                'exchange_rate' => $currency->exchange_rate,
                'source' => 'manual',
                'recorded_at' => now(),
                'changed_by' => Auth::id(),
                'metadata' => [
                    'reason' => 'Currency created through admin API',
                ],
            ]);

            return $currency;
        });

        return response()->json([
            'status' => 'success',
            'message' => 'Currency created successfully.',
            'data' => $currency,
        ], 201);
    }

    /**
     * PUT/PATCH /api/admin/currencies/{currency}
     * Update currency details and record exchange-rate changes.
     */
    public function update(
        Request $request,
        Currency $currency
    ): JsonResponse {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'code' => [
                'sometimes',
                'required',
                'string',
                'size:3',
                'alpha',
                'uppercase',
                Rule::unique('currencies', 'code')->ignore($currency->id),
            ],
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'symbol' => ['sometimes', 'required', 'string', 'max:10'],
            'exchange_rate' => [
                'sometimes',
                'required',
                'numeric',
                'gt:0',
                'max:9999999999',
            ],
            'decimal_places' => [
                'sometimes',
                'required',
                'integer',
                'between:0,6',
            ],
            'rate_update_mode' => [
                'sometimes',
                'required',
                Rule::in(['automatic', 'manual']),
            ],
            'is_active' => ['sometimes', 'boolean'],
            'is_default' => ['sometimes', 'boolean'],
        ]);

        $currency = DB::transaction(function () use ($currency, $validated) {
            $lockedCurrency = Currency::query()
                ->whereKey($currency->id)
                ->lockForUpdate()
                ->firstOrFail();

            if (($validated['is_default'] ?? false) === true) {
                if (
                    array_key_exists('is_active', $validated) &&
                    !$validated['is_active']
                ) {
                    throw \Illuminate\Validation\ValidationException::withMessages([
                        'is_default' => 'An inactive currency cannot be the default.',
                    ]);
                }

                if (
                    !$lockedCurrency->is_active &&
                    !($validated['is_active'] ?? false)
                ) {
                    throw \Illuminate\Validation\ValidationException::withMessages([
                        'is_default' => 'An inactive currency cannot be the default.',
                    ]);
                }

                Currency::query()->update(['is_default' => false]);
            }

            $oldRate = (string) $lockedCurrency->exchange_rate;

            $lockedCurrency->update($validated);
            $lockedCurrency->refresh();

            if (
                array_key_exists('exchange_rate', $validated) &&
                bccomp($oldRate, (string) $lockedCurrency->exchange_rate, 8) !== 0
            ) {
                ExchangeRateHistory::create([
                    'currency_id' => $lockedCurrency->id,
                    'exchange_rate' => $lockedCurrency->exchange_rate,
                    'source' => 'manual',
                    'recorded_at' => now(),
                    'changed_by' => Auth::id(),
                    'metadata' => [
                        'reason' => 'Exchange rate changed through admin API',
                    ],
                ]);
            }

            return $lockedCurrency;
        });

        return response()->json([
            'status' => 'success',
            'message' => 'Currency updated successfully.',
            'data' => $currency,
        ]);
    }

    /**
     * PATCH /api/admin/currencies/{currency}/status
     * Enable or disable a currency.
     */
    public function updateStatus(
        Request $request,
        Currency $currency
    ): JsonResponse {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'is_active' => ['required', 'boolean'],
        ]);

        $updatedCurrency = DB::transaction(function () use ($currency, $validated) {
            $currencies = Currency::query()
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            $target = $currencies->firstWhere('id', $currency->id);

            if (!$target) {
                abort(404, 'Currency not found.');
            }

            if (!$validated['is_active'] && $target->is_default) {
                throw \Illuminate\Validation\ValidationException::withMessages([
                    'is_active' => 'The default currency cannot be deactivated. Set another active currency as default first.',
                ]);
            }

            $target->update([
                'is_active' => $validated['is_active'],
            ]);

            return $target->fresh();
        });

        return response()->json([
            'status' => 'success',
            'message' => 'Currency status updated successfully.',
            'data' => $updatedCurrency,
        ]);
    }

    /**
     * POST /api/admin/currencies/{currency}/set-default
     * Set an active currency as the default.
     */
    public function setDefault(
        Request $request,
        Currency $currency
    ): JsonResponse {
        $this->authorizeAdmin($request);

        $defaultCurrency = DB::transaction(function () use ($currency) {
            $currencies = Currency::query()
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            $target = $currencies->firstWhere('id', $currency->id);

            if (!$target) {
                abort(404, 'Currency not found.');
            }

            if (!$target->is_active) {
                throw \Illuminate\Validation\ValidationException::withMessages([
                    'currency' => 'An inactive currency cannot be the default.',
                ]);
            }

            Currency::query()->update(['is_default' => false]);

            $target->update(['is_default' => true]);

            return $target->fresh();
        });

        return response()->json([
            'status' => 'success',
            'message' => 'Default currency updated successfully.',
            'data' => $defaultCurrency,
        ]);
    }

    /**
     * GET /api/currencies/convert?amount=10&from=USD&to=KHR
     */
    public function convert(
        Request $request,
        CurrencyService $currencyService
    ): JsonResponse {
        $validated = $request->validate([
            'amount' => [
                'required',
                'numeric',
                'min:0',
                'max:999999999999',
            ],
            'from' => [
                'required',
                'string',
                'size:3',
                'alpha',
                'uppercase',
            ],
            'to' => [
                'required',
                'string',
                'size:3',
                'alpha',
                'uppercase',
            ],
        ]);

        $result = $currencyService->convert(
            $validated['from'],
            $validated['to'],
            (float) $validated['amount']
        );

        return response()->json([
            'status' => 'success',
            'data' => $result,
        ]);
    }

    /**
     * GET /api/currencies/summary
     */
    public function summary(
        CurrencyService $currencyService
    ): JsonResponse {
        return response()->json([
            'status' => 'success',
            'data' => [
                'currencies' => $currencyService->activeCurrencies(),
                'default_currency' => $currencyService
                    ->defaultCurrency()?->code,
            ],
        ]);
    }
}