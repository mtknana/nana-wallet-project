<?php

namespace Database\Seeders;

use App\Models\SystemSetting;
use Illuminate\Database\Seeder;

class SystemSettingSeeder extends Seeder
{
    public function run(): void
    {
        $settings = [
            [
                'key' => 'app_name',
                'value' => 'NaNa Wallet',
                'group' => 'general',
                'description' => 'Application display name.',
            ],
            [
                'key' => 'default_currency',
                'value' => 'USD',
                'group' => 'currency',
                'description' => 'Default application currency.',
            ],
            [
                'key' => 'default_language',
                'value' => 'en',
                'group' => 'localization',
                'description' => 'Default application language.',
            ],
            [
                'key' => 'maintenance_mode',
                'value' => 'false',
                'group' => 'system',
                'description' => 'Whether maintenance mode is enabled.',
            ],
            [
                'key' => 'notifications_enabled',
                'value' => 'true',
                'group' => 'notifications',
                'description' => 'Enable or disable application notifications.',
            ],
            [
                'key' => 'support_email',
                'value' => '',
                'group' => 'general',
                'description' => 'Customer support email address.',
            ],
            [
                'key' => 'session_timeout_minutes',
                'value' => '30',
                'group' => 'security',
                'description' => 'Session timeout in minutes.',
            ],
        ];

        foreach ($settings as $setting) {
            SystemSetting::updateOrCreate(
                ['key' => $setting['key']],
                [
                    'value' => $setting['value'],
                    'group' => $setting['group'],
                    'description' => $setting['description'],
                ]
            );
        }
    }
}