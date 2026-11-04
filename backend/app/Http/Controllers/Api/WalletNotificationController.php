<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\WalletNotification;
use Illuminate\Http\Request;

class WalletNotificationController extends Controller
{
    // ==========================================================
    // US-058: GET ALL NOTIFICATIONS
    // ==========================================================

    public function index(Request $request)
    {
        $user = $request->user();

        $notifications = $user->walletNotifications()
            ->orderByDesc('occurred_at')
            ->limit(100)
            ->get([
                'id',
                'type',
                'severity',
                'title',
                'message',
                'amount',
                'currency',
                'reference_type',
                'reference_id',
                'is_read',
                'read_at',
                'occurred_at',
                'created_at',
            ]);

        return response()->json([
            'status' => 'success',
            'notifications' => $notifications,
        ], 200);
    }

    // ==========================================================
    // US-058: GET UNREAD NOTIFICATION COUNT
    // ==========================================================

    public function unreadCount(Request $request)
    {
        $user = $request->user();

        $count = $user->walletNotifications()
            ->where('is_read', false)
            ->count();

        return response()->json([
            'status' => 'success',
            'unread_count' => $count,
        ], 200);
    }

    // ==========================================================
    // US-058: MARK ONE NOTIFICATION AS READ
    // ==========================================================

    public function markAsRead(
        Request $request,
        int $id
    ) {
        $user = $request->user();

        $notification = $user->walletNotifications()
            ->where('id', $id)
            ->first();

        if (!$notification) {
            return response()->json([
                'status' => 'error',
                'message' => 'Notification not found.',
            ], 404);
        }

        if (!$notification->is_read) {
            $notification->is_read = true;
            $notification->read_at = now();
            $notification->save();
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Notification marked as read.',
            'notification' => $notification,
        ], 200);
    }

    // ==========================================================
    // US-058: MARK ALL NOTIFICATIONS AS READ
    // ==========================================================

    public function markAllAsRead(Request $request)
    {
        $user = $request->user();

        $updatedCount = $user->walletNotifications()
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
                'updated_at' => now(),
            ]);

        return response()->json([
            'status' => 'success',
            'message' =>
                'All notifications have been marked as read.',
            'updated_count' => $updatedCount,
        ], 200);
    }

    // ==========================================================
    // US-058: DELETE ONE NOTIFICATION
    // ==========================================================

    public function destroy(
        Request $request,
        int $id
    ) {
        $user = $request->user();

        $notification = $user->walletNotifications()
            ->where('id', $id)
            ->first();

        if (!$notification) {
            return response()->json([
                'status' => 'error',
                'message' => 'Notification not found.',
            ], 404);
        }

        $notification->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Notification deleted successfully.',
        ], 200);
    }
}