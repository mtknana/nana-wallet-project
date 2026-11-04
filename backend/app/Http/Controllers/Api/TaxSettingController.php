<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\TaxSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TaxSettingController extends Controller
{
    private function authorizeAdmin(Request $request): void
    {
        abort_unless(
            $request->user()?->role === 'admin',
            403,
            'Administrator access required.'
        );
    }

    public function index(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);

        $taxSettings = TaxSetting::query()
            ->orderBy('name')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $taxSettings,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'code' => [
                'required',
                'string',
                'max:50',
                'alpha_dash',
                'unique:tax_settings,code',
            ],
            'rate_percent' => ['required', 'numeric', 'min:0', 'max:100'],
            'applies_to' => [
                'required',
                Rule::in([
                    'all',
                    'transfer',
                    'withdrawal',
                    'payment',
                    'bill_payment',
                    'mobile_topup',
                    'qr_payment',
                ]),
            ],
            'is_active' => ['sometimes', 'boolean'],
            'is_inclusive' => ['sometimes', 'boolean'],
            'description' => ['nullable', 'string', 'max:2000'],
        ]);

        $taxSetting = TaxSetting::create([
            ...$validated,
            'code' => strtoupper($validated['code']),
            'is_active' => $validated['is_active'] ?? false,
            'is_inclusive' => $validated['is_inclusive'] ?? false,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Tax setting created successfully.',
            'data' => $taxSetting,
        ], 201);
    }

    public function update(Request $request, TaxSetting $taxSetting): JsonResponse
    {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'code' => [
                'sometimes',
                'required',
                'string',
                'max:50',
                'alpha_dash',
                Rule::unique('tax_settings', 'code')->ignore($taxSetting->id),
            ],
            'rate_percent' => [
                'sometimes',
                'required',
                'numeric',
                'min:0',
                'max:100',
            ],
            'applies_to' => [
                'sometimes',
                'required',
                Rule::in([
                    'all',
                    'transfer',
                    'withdrawal',
                    'payment',
                    'bill_payment',
                    'mobile_topup',
                    'qr_payment',
                ]),
            ],
            'is_active' => ['sometimes', 'boolean'],
            'is_inclusive' => ['sometimes', 'boolean'],
            'description' => ['nullable', 'string', 'max:2000'],
        ]);

        if (isset($validated['code'])) {
            $validated['code'] = strtoupper($validated['code']);
        }

        $taxSetting->update($validated);

        return response()->json([
            'status' => 'success',
            'message' => 'Tax setting updated successfully.',
            'data' => $taxSetting->fresh(),
        ]);
    }

    public function updateStatus(
        Request $request,
        TaxSetting $taxSetting
    ): JsonResponse {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'is_active' => ['required', 'boolean'],
        ]);

        $taxSetting->update([
            'is_active' => $validated['is_active'],
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Tax status updated successfully.',
            'data' => $taxSetting->fresh(),
        ]);
    }
}