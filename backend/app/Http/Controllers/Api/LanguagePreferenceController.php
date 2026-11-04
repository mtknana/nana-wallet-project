<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;

class LanguagePreferenceController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'status' => 'success',
            'data' => [
                'locale' => $user->locale ?? 'en',
                'supported_locales' => [
                    ['code' => 'en', 'name' => 'English'],
                    ['code' => 'km', 'name' => 'Khmer'],
                ],
            ],
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'locale' => ['required', 'string', 'in:en,km'],
        ]);

        $user = $request->user();
        $user->locale = $validated['locale'];
        $user->save();

        App::setLocale($user->locale);

        return response()->json([
            'status' => 'success',
            'message' => __('api.language_updated'),
            'data' => [
                'locale' => $user->locale,
            ],
        ]);
    }
}