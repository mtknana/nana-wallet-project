<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FinancialChatbotService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ChatbotController extends Controller
{
    public function chat(
        Request $request,
        FinancialChatbotService $service
    ): JsonResponse {
        $validated = $request->validate([
            'message' => ['required', 'string', 'max:2000'],
        ]);

        $user = $request->user();

        abort_unless($user, 401, 'Authentication required.');

        return response()->json([
            'status' => 'success',
            'data' => $service->reply(
                (int) $user->id,
                $validated['message']
            ),
        ]);
    }
}