<?php

namespace App\Services;

use App\Models\SecurityEvent;
use App\Models\User;
use Illuminate\Http\Request;

class SecurityEventLogger
{
    public static function log(
        ?User $user,
        string $eventType,
        string $title,
        ?string $description = null,
        string $severity = 'info',
        ?string $referenceType = null,
        ?int $referenceId = null,
        ?Request $request = null
    ): SecurityEvent {
        return SecurityEvent::create([
            'user_id' => $user?->id,
            'event_type' => $eventType,
            'severity' => $severity,
            'title' => $title,
            'description' => $description,
            'ip_address' => $request?->ip(),
            'user_agent' => $request?->userAgent(),
            'reference_type' => $referenceType,
            'reference_id' => $referenceId,
            'is_reviewed' => false,
            'occurred_at' => now(),
        ]);
    }
}