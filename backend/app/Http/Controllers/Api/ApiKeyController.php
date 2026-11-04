<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ApiKey;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ApiKeyController extends Controller
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
     * List API keys without exposing their secret hashes.
     */
    public function index(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);

        $keys = ApiKey::query()
            ->select([
                'id',
                'name',
                'key_prefix',
                'abilities',
                'created_by',
                'last_used_at',
                'expires_at',
                'is_active',
                'created_at',
                'updated_at',
            ])
            ->latest()
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $keys,
        ]);
    }

    /**
     * Create an API key. The secret is returned only once.
     */
    public function store(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'abilities' => ['nullable', 'array', 'max:10'],
            'abilities.*' => [
                'required',
                'string',
                'max:50',
                'distinct',
                'regex:/\A[a-zA-Z0-9:_-]+\z/',
            ],
            'expires_at' => [
                'nullable',
                'date',
                'after:now',
            ],
        ]);

        $secret = 'nw_' . Str::random(64);
        $prefix = substr($secret, 0, 14);

        $apiKey = ApiKey::create([
            'name' => $validated['name'],
            'key_prefix' => $prefix,
            'key_hash' => hash('sha256', $secret),
            'abilities' => $validated['abilities'] ?? ['read'],
            'created_by' => $request->user()->id,
            'expires_at' => $validated['expires_at'] ?? null,
            'is_active' => true,
        ]);

        Log::info('API key created.', [
            'api_key_id' => $apiKey->id,
            'admin_user_id' => $request->user()->id,
            'key_prefix' => $prefix,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'API key created. Copy the secret now; it will not be shown again.',
            'data' => [
                'id' => $apiKey->id,
                'name' => $apiKey->name,
                'key_prefix' => $apiKey->key_prefix,
                'secret' => $secret,
                'abilities' => $apiKey->abilities,
                'expires_at' => $apiKey->expires_at,
                'is_active' => $apiKey->is_active,
            ],
        ], 201);
    }

    /**
     * Revoke an API key.
     */
    public function revoke(
        Request $request,
        ApiKey $apiKey
    ): JsonResponse {
        $this->authorizeAdmin($request);

        if (!$apiKey->is_active) {
            throw ValidationException::withMessages([
                'api_key' => 'This API key has already been revoked.',
            ]);
        }

        $apiKey->update(['is_active' => false]);

        Log::warning('API key revoked.', [
            'api_key_id' => $apiKey->id,
            'admin_user_id' => $request->user()->id,
            'key_prefix' => $apiKey->key_prefix,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'API key revoked successfully.',
        ]);
    }
}