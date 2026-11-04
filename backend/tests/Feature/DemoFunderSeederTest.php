<?php

namespace Tests\Feature;

use App\Models\Transaction;
use App\Models\User;
use App\Models\Wallet;
use Database\Seeders\DemoFunderSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class DemoFunderSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_an_auditable_demo_balance_without_replenishing_it(): void
    {
        $seeder = app(DemoFunderSeeder::class);
        $seeder->run();

        $funder = User::query()
            ->where('email', 'demo-funder@nanawallet.test')
            ->firstOrFail();
        $wallet = Wallet::query()
            ->where('user_id', $funder->id)
            ->where('currency', 'USD')
            ->firstOrFail();

        $this->assertSame('admin', $funder->role);
        $this->assertSame('10000.00', $wallet->balance);
        $this->assertDatabaseHas('transactions', [
            'user_id' => $funder->id,
            'type' => 'deposit',
            'amount' => '10000.00',
            'currency' => 'USD',
            'reference_id' => 'DEMO-FUNDER-OPENING-' . $funder->id,
            'idempotency_key' => 'demo-funder-opening-' . $funder->id,
        ]);

        $wallet->update(['balance' => '8750.00']);
        $seeder->run();

        $this->assertSame('8750.00', $wallet->fresh()->balance);
        $this->assertSame(
            1,
            Transaction::query()
                ->where('idempotency_key', 'demo-funder-opening-' . $funder->id)
                ->count()
        );
    }

    public function test_it_does_not_escalate_an_existing_non_admin_user(): void
    {
        $user = User::factory()->create([
            'email' => 'demo-funder@nanawallet.test',
            'role' => 'user',
        ]);

        try {
            app(DemoFunderSeeder::class)->run();
            $this->fail('The seeder should reject an existing ordinary user.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('Refusing to grant admin access', $exception->getMessage());
        }

        $this->assertSame('user', $user->fresh()->role);
        $this->assertDatabaseCount('wallets', 0);
    }
}
