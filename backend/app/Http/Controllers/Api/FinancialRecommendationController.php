<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FinancialRecommendationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FinancialRecommendationController extends Controller
{
    public function __invoke(
        Request $request,
        FinancialRecommendationService $service
    ): JsonResponse {
        $user = $request->user();

        abort_unless($user, 401, 'Authentication required.');

        return response()->json([
            'status' => 'success',
            'data' => $service->generate((int) $user->id),
        ]);
    }
}