<?php

namespace Tests\Feature;

use App\Models\Currency;
use App\Models\P2pTransfer;
use App\Models\SplitBill;
use App\Models\SplitBillMember;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WalletQrAndSplitBillFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_qr_transfer_by_user_id_credits_the_recipient_and_is_idempotent(): void
    {
        $this->createCurrency('USD', 2);

        $sender = User::factory()->create(['role' => 'user']);
        $receiver = User::factory()->create(['role' => 'user']);
        $admin = User::factory()->create(['role' => 'admin']);

        $senderWallet = $this->createWallet($sender, 'USD', '100.00');
        $receiverWallet = $this->createWallet($receiver, 'USD', '5.00');
        $adminWallet = $this->createWallet($admin, 'USD', '0.00');

        Sanctum::actingAs($sender);

        $payload = [
            'receiver_user_id' => $receiver->id,
            'amount' => '10.00',
            'currency' => 'USD',
            'idempotency_key' => 'qr-wallet-transfer-test-key',
            'description' => 'QR wallet payment',
        ];

        $this->postJson('/api/wallet/transfer', $payload)
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('fee', 0.15)
            ->assertJsonPath('total_debit', 10.15);

        $this->assertSame('89.85', $senderWallet->fresh()->balance);
        $this->assertSame('15.00', $receiverWallet->fresh()->balance);
        $this->assertSame('0.15', $adminWallet->fresh()->balance);
        $this->assertSame(1, P2pTransfer::count());
        $this->assertDatabaseHas('p2p_transfers', [
            'sender_id' => $sender->id,
            'receiver_id' => $receiver->id,
            'currency' => 'USD',
            'fee_applied' => '0.15',
            'idempotency_key' => 'qr-wallet-transfer-test-key',
        ]);

        $this->postJson('/api/wallet/transfer', $payload)
            ->assertStatus(409)
            ->assertJsonPath('status', 'error');

        $this->assertSame('89.85', $senderWallet->fresh()->balance);
        $this->assertSame('15.00', $receiverWallet->fresh()->balance);
        $this->assertSame(1, P2pTransfer::count());
    }

    public function test_existing_email_transfer_contract_is_still_supported(): void
    {
        $this->createCurrency('USD', 2);
        $sender = User::factory()->create(['role' => 'user']);
        $receiver = User::factory()->create(['role' => 'user']);
        $admin = User::factory()->create(['role' => 'admin']);
        $senderWallet = $this->createWallet($sender, 'USD', '100.00');
        $receiverWallet = $this->createWallet($receiver, 'USD', '5.00');
        $this->createWallet($admin, 'USD', '0.00');

        Sanctum::actingAs($sender);

        $this->postJson('/api/wallet/transfer', [
            'receiver_email' => $receiver->email,
            'amount' => '10.00',
            'currency' => 'USD',
            'idempotency_key' => 'email-wallet-transfer-test-key',
        ])
            ->assertOk()
            ->assertJsonPath('status', 'success');

        $this->assertSame('89.85', $senderWallet->fresh()->balance);
        $this->assertSame('15.00', $receiverWallet->fresh()->balance);
        $this->assertSame(1, P2pTransfer::count());
    }

    public function test_split_bill_resolves_member_emails_and_persists_equal_owed_amounts(): void
    {
        $this->createCurrency('USD', 2);

        $creator = User::factory()->create(['role' => 'user']);
        $memberOne = User::factory()->create(['role' => 'user']);
        $memberTwo = User::factory()->create(['role' => 'user']);

        Sanctum::actingAs($creator);

        $this->postJson('/api/wallet/split-bill', [
            'title' => 'Lunch',
            'total_amount' => '10.00',
            'members' => [
                ['email' => strtoupper($memberOne->email)],
                ['email' => $memberTwo->email],
            ],
        ])
            ->assertCreated()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('split_bill.currency', 'USD');

        $splitBill = SplitBill::query()->firstOrFail();
        $this->assertSame('10.00', $splitBill->total_amount);
        $this->assertSame(2, SplitBillMember::count());

        foreach ([$memberOne, $memberTwo] as $member) {
            $this->assertDatabaseHas('split_bill_members', [
                'split_bill_id' => $splitBill->id,
                'user_id' => $member->id,
                'owed_amount' => '3.33',
                'is_paid' => false,
            ]);
        }
    }

    public function test_split_bill_returns_a_clear_validation_error_for_an_unregistered_email(): void
    {
        $this->createCurrency('USD', 2);
        $creator = User::factory()->create(['role' => 'user']);
        Sanctum::actingAs($creator);

        $this->postJson('/api/wallet/split-bill', [
            'title' => 'Lunch',
            'total_amount' => '10.00',
            'currency' => 'USD',
            'members' => [
                ['email' => 'not-registered@example.test'],
            ],
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('members');

        $this->assertSame(0, SplitBill::count());
        $this->assertSame(0, SplitBillMember::count());
    }

    public function test_khr_split_bill_rejects_fractional_totals(): void
    {
        $this->createCurrency('KHR', 0);
        $creator = User::factory()->create(['role' => 'user']);
        $member = User::factory()->create(['role' => 'user']);
        Sanctum::actingAs($creator);

        $this->postJson('/api/wallet/split-bill', [
            'title' => 'Taxi',
            'total_amount' => '5.50',
            'currency' => 'KHR',
            'members' => [
                ['email' => $member->email],
            ],
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('total_amount');

        $this->assertSame(0, SplitBill::count());
    }

    private function createCurrency(string $code, int $decimalPlaces): void
    {
        Currency::create([
            'code' => $code,
            'name' => $code === 'USD' ? 'US Dollar' : 'Cambodian Riel',
            'symbol' => $code === 'USD' ? '$' : '៛',
            'exchange_rate' => 1,
            'decimal_places' => $decimalPlaces,
            'is_active' => true,
            'is_default' => $code === 'USD',
        ]);
    }

    private function createWallet(User $user, string $currency, string $balance): Wallet
    {
        return Wallet::create([
            'user_id' => $user->id,
            'balance' => $balance,
            'currency' => $currency,
            'status' => 'active',
        ]);
    }
}
