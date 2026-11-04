<?php

namespace Database\Seeders;

use App\Models\Transaction;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use RuntimeException;

class DemoFunderSeeder extends Seeder
{
    private const EMAIL = 'demo-funder@nanawallet.test';
    private const OPENING_BALANCE = '10000.00';

    /**
     * Create the school-demo funder with simulated funds only.
     * Existing balances are never reset or topped up on subsequent runs.
     */
    public function run(): void
    {
        DB::transaction(function (): void {
            $funder = User::query()
                ->whereRaw('LOWER(email) = ?', [self::EMAIL])
                ->lockForUpdate()
                ->first();

            if ($funder && $funder->role !== 'admin') {
                throw new RuntimeException(
                    'Refusing to grant admin access to the existing demo-funder email.'
                );
            }

            if (!$funder) {
                $funder = User::create([
                    'name' => 'NaNa Demo Funder',
                    'email' => self::EMAIL,
                    'email_verified_at' => now(),
                    'password' => Hash::make(Str::random(64)),
                    'role' => 'admin',
                    'locale' => 'en',
                ]);
            }

            $wallet = Wallet::query()
                ->where('user_id', $funder->id)
                ->where('currency', 'USD')
                ->lockForUpdate()
                ->first();

            if ($wallet) {
                if ($this->command) {
                    $this->command->info(
                        'Demo funder already has a USD wallet; its balance was left unchanged.'
                    );
                }

                return;
            }

            Wallet::create([
                'user_id' => $funder->id,
                'balance' => self::OPENING_BALANCE,
                'currency' => 'USD',
                'status' => 'active',
            ]);

            Transaction::create([
                'user_id' => $funder->id,
                'type' => 'deposit',
                'amount' => self::OPENING_BALANCE,
                'fee_charged' => '0.00',
                'currency' => 'USD',
                'description' => 'Opening balance for NaNa school demo; simulated funds only.',
                'reference_id' => 'DEMO-FUNDER-OPENING-' . $funder->id,
                'idempotency_key' => 'demo-funder-opening-' . $funder->id,
                'status' => 'completed',
            ]);

            if ($this->command) {
                $this->command->info(
                    'Created the NaNa demo funder with a $10,000.00 simulated USD balance.'
                );
            }
        });
    }
}
