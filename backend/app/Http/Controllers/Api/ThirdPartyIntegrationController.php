<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ThirdPartyIntegration;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class ThirdPartyIntegrationController extends Controller
{
    private function authorizeAdmin(Request $request): void
    {
        abort_unless(
            $request->user()?->role === 'admin',
            403,
            'Administrator access required.'
        );
    }

    private function present(ThirdPartyIntegration $integration): array
    {
        return [
            'id' => $integration->id,
            'name' => $integration->name,
            'provider' => $integration->provider,
            'settings' => $integration->settings,
            'credentials_configured' => !empty($integration->credentials),
            'is_active' => $integration->is_active,
            'status' => $integration->status,
            'last_tested_at' => $integration->last_tested_at,
            'created_at' => $integration->created_at,
            'updated_at' => $integration->updated_at,
        ];
    }

    public function index(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);

        $integrations = ThirdPartyIntegration::query()
            ->latest()
            ->get()
            ->map(
                fn(ThirdPartyIntegration $integration) =>
                    $this->present($integration)
            );

        return response()->json([
            'status' => 'success',
            'data' => $integrations,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'provider' => ['required', 'string', 'max:100'],
            'credentials' => ['nullable', 'array'],
            'credentials.*' => ['nullable', 'string', 'max:10000'],
            'settings' => ['nullable', 'array'],
            'settings.*' => ['nullable'],
        ]);

        $credentials = $validated['credentials'] ?? null;

        $integration = ThirdPartyIntegration::create([
            'name' => $validated['name'],
            'provider' => $validated['provider'],
            'credentials' => $credentials,
            'settings' => $validated['settings'] ?? null,
            'is_active' => false,
            'status' => empty($credentials)
                ? 'not_configured'
                : 'configured',
        ]);

        Log::info('Third-party integration created.', [
            'integration_id' => $integration->id,
            'admin_user_id' => $request->user()->id,
            'provider' => $integration->provider,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Integration created and kept disabled.',
            'data' => $this->present($integration),
        ], 201);
    }

    public function update(
        Request $request,
        ThirdPartyIntegration $integration
    ): JsonResponse {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'provider' => ['sometimes', 'required', 'string', 'max:100'],
            'credentials' => ['sometimes', 'nullable', 'array'],
            'credentials.*' => ['nullable', 'string', 'max:10000'],
            'settings' => ['sometimes', 'nullable', 'array'],
            'settings.*' => ['nullable'],
        ]);

        $integration->fill($validated);

        if (array_key_exists('credentials', $validated)) {
            $integration->status = empty($validated['credentials'])
                ? 'not_configured'
                : 'configured';

            // Changing credentials disables the integration until
            // the new configuration has been reviewed.
            $integration->is_active = false;
            $integration->last_error = null;
            $integration->last_tested_at = null;
        }

        $integration->save();

        Log::info('Third-party integration updated.', [
            'integration_id' => $integration->id,
            'admin_user_id' => $request->user()->id,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Integration updated. Review it before enabling.',
            'data' => $this->present($integration),
        ]);
    }

    public function updateStatus(
        Request $request,
        ThirdPartyIntegration $integration
    ): JsonResponse {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'is_active' => ['required', 'boolean'],
        ]);

        if ($validated['is_active'] && empty($integration->credentials)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Configure credentials before enabling this integration.',
            ], 422);
        }

        $integration->is_active = $validated['is_active'];
        $integration->status = $validated['is_active']
            ? 'enabled'
            : (empty($integration->credentials)
                ? 'not_configured'
                : 'configured');

        $integration->save();

        Log::info('Third-party integration status changed.', [
            'integration_id' => $integration->id,
            'admin_user_id' => $request->user()->id,
            'is_active' => $integration->is_active,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => $integration->is_active
                ? 'Integration enabled.'
                : 'Integration disabled.',
            'data' => $this->present($integration),
        ]);
    }
}