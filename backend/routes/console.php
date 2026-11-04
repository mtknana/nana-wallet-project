<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;
Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Schedule::command('currency:snapshot-rates')
    ->dailyAt('23:55')
    ->withoutOverlapping();

Schedule::command('currency:refresh-rates')
    ->dailyAt('00:10')
    ->withoutOverlapping();

Schedule::command('loans:process-due')
    ->everyMinute()
    ->withoutOverlapping();