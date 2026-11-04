<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;
use Symfony\Component\HttpFoundation\Response;

class SetApiLocale
{
    public function handle(Request $request, Closure $next): Response
    {
        $supportedLocales = ['en', 'km'];

        $requestedLocale = $request->header('X-Locale')
            ?? $request->query('locale');

        $userLocale = $request->user()?->locale;

        $locale = strtolower(
            $requestedLocale ?? $userLocale ?? 'en'
        );

        if (!in_array($locale, $supportedLocales, true)) {
            $locale = 'en';
        }

        App::setLocale($locale);

        return $next($request);
    }
}