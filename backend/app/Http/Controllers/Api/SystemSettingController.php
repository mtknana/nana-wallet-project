<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SystemSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SystemSettingController extends Controller
{
    /**
     * Default settings returned even when they have not
     * been inserted into the database yet.
     */
    private const DEFAULT_SETTINGS = [
        'app_name' => [
            'value' => 'NaNa Wallet',
            'group' => 'general',
            'description' => 'Application display name.',
        ],
        'default_currency' => [
            'value' => 'USD',
            'group' => 'currency',
            'description' => 'Default application currency.',
        ],
        'default_language' => [
            'value' => 'en',
            'group' => 'localization',
            'description' => 'Default application language.',
        ],
        'maintenance_mode' => [
            'value' => 'false',
            'group' => 'system',
            'description' => 'Whether maintenance mode is enabled.',
        ],
        'notifications_enabled' => [
            'value' => 'true',
            'group' => 'notifications',
            'description' => 'Enable or disable application notifications.',
        ],
        'support_email' => [
            'value' => '',
            'group' => 'general',
            'description' => 'Customer support email address.',
        ],
        'session_timeout_minutes' => [
            'value' => '30',
            'group' => 'security',
            'description' => 'Session timeout in minutes.',
        ],
    ];

    private function authorizeAdmin(Request $request): void
    {
        abort_unless(
            $request->user()?->role === 'admin',
            403,
            'Administrator access required.'
        );
    }

    /**
     * GET /api/admin/system-settings
     */
    public function index(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);

        $storedSettings = SystemSetting::query()
            ->get(['key', 'value', 'group', 'description'])
            ->keyBy('key');

        $settings = collect(self::DEFAULT_SETTINGS)
            ->map(function (array $default, string $key) use ($storedSettings) {
                $stored = $storedSettings->get($key);

                return [
                    'key' => $key,
                    'value' => $stored
                        ? (string) $stored->value
                        : $default['value'],
                    'group' => $stored?->group ?? $default['group'],
                    'description' => $stored?->description
                        ?? $default['description'],
                ];
            })
            ->sortBy([
                ['group', 'asc'],
                ['key', 'asc'],
            ])
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => $settings,
        ]);
    }

    /**
     * PUT /api/admin/system-settings
     */
    public function update(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);

        $allowedKeys = array_keys(self::DEFAULT_SETTINGS);

        $validated = $request->validate([
            'settings' => ['required', 'array', 'min:1'],

            'settings.*.key' => [
                'required',
                'string',
                'distinct',
                'in:' . implode(',', $allowedKeys),
            ],

            'settings.*.value' => [
                'present',
                'nullable',
                'string',
                'max:1000',
            ],
        ]);

        $values = collect($validated['settings'])
            ->mapWithKeys(fn(array $setting) => [
                $setting['key'] => $setting['value'],
            ]);

        $rules = [];

        if ($values->has('app_name')) {
            $rules['app_name'] = [
                'required',
                'string',
                'min:2',
                'max:100',
            ];
        }

        if ($values->has('default_currency')) {
            $rules['default_currency'] = [
                'required',
                'in:USD,KHR',
            ];
        }

        if ($values->has('default_language')) {
            $rules['default_language'] = [
                'required',
                'in:en,km',
            ];
        }

        if ($values->has('maintenance_mode')) {
            $rules['maintenance_mode'] = [
                'required',
                'in:true,false',
            ];
        }

        if ($values->has('notifications_enabled')) {
            $rules['notifications_enabled'] = [
                'required',
                'in:true,false',
            ];
        }

        if ($values->has('support_email')) {
            $rules['support_email'] = [
                'nullable',
                'email',
                'max:255',
            ];
        }

        if ($values->has('session_timeout_minutes')) {
            $rules['session_timeout_minutes'] = [
                'required',
                'integer',
                'between:5,1440',
            ];
        }

        if ($rules !== []) {
            validator($values->all(), $rules)->validate();
        }

        DB::transaction(function () use ($validated) {
            foreach ($validated['settings'] as $setting) {
                $key = $setting['key'];
                $default = self::DEFAULT_SETTINGS[$key];

                SystemSetting::updateOrCreate(
                    ['key' => $key],
                    [
                        'value' => $setting['value'] ?? '',
                        'group' => $default['group'],
                        'description' => $default['description'],
                    ]
                );
            }
        });

        return response()->json([
            'status' => 'success',
            'message' => 'System settings updated successfully.',
        ]);
    }
}