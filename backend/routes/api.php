<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\WalletController;
use App\Http\Controllers\Api\WalletNotificationController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ExpenseController;
use App\Http\Controllers\Api\SavingsGoalController;
use App\Http\Controllers\Api\StatementController;
use App\Http\Controllers\Api\SystemSettingController;
use App\Http\Controllers\Api\CurrencyController;
use App\Http\Controllers\Api\FinancialInsightsController;
use App\Http\Controllers\Api\TaxSettingController;
use App\Http\Controllers\Api\DatabaseBackupController;
use App\Http\Controllers\Api\DatabaseRestoreController;
use App\Http\Controllers\Api\ApiKeyController;
use App\Http\Controllers\Api\ThirdPartyIntegrationController;
use App\Http\Controllers\Api\LanguagePreferenceController;
use App\Http\Controllers\Api\SpendingPredictionController;
use App\Http\Controllers\Api\LoanController;

// Public Endpoints
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
// Public Password Recovery — Sprint 4 US-046
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('/reset-password', [AuthController::class, 'resetPassword']);

// Protected Endpoints (Requires valid Sanctum Bearer Token)
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/profile', [AuthController::class, 'profile']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/change-password', [AuthController::class, 'changePassword']);
    Route::post('/verify-email', [AuthController::class, 'verifyEmail']);
    Route::post('/verify-phone', [AuthController::class, 'verifyPhone']);
    Route::post('/toggle-2fa', [AuthController::class, 'toggleTwoFactor']);
    Route::get('/two-factor-status', [AuthController::class, 'twoFactorStatus']);
    // Sprint 2 Operational Handshake Routes
    Route::get('/wallet/balance', [WalletController::class, 'getBalance']);
    Route::post('/wallet/withdraw', [WalletController::class, 'withdraw']);
    Route::get('/wallet/history', [WalletController::class, 'getHistory']);
    Route::post('/calendar/events', [WalletController::class, 'createCalendarEvent']);
    // SPRINT 3: Payments, Merchants, and Split Room Systems Core Maps
    Route::post('/wallet/transfer', [WalletController::class, 'transferP2p']);
    Route::post(
        '/wallet/transfer-between',
        [WalletController::class, 'transferBetweenWallets']
    );
    Route::post('/wallet/pay-qr', [WalletController::class, 'payMerchantQr']);
    Route::post('/wallet/split-bill', [WalletController::class, 'createSplitBill']);
    Route::post('/wallet/top-up', [WalletController::class, 'mobileTopUp']);
    Route::post('/wallet/cancel-tx', [WalletController::class, 'cancelTransaction']);
    // PIN Setting
    Route::post('/set-transaction-pin', [AuthController::class, 'setTransactionPin']);
    Route::post('/change-transaction-pin', [AuthController::class, 'changeTransactionPin']);
    Route::post('/verify-transaction-pin', [AuthController::class, 'verifyTransactionPin']);
    Route::get('/transaction-pin-status', [AuthController::class, 'transactionPinStatus']);
    // Schedule Payments
    Route::post('/scheduled-payments', [WalletController::class, 'createScheduledPayment']);
    Route::get('/scheduled-payments', [WalletController::class, 'getScheduledPayments']);
    Route::delete('/scheduled-payments/{id}', [WalletController::class, 'cancelScheduledPayment']);
    Route::post(
        '/wallet/email-receipt',
        [WalletController::class, 'emailTransactionReceipt']
    );
    // Merchant / Bill Payment
    Route::get(
        '/merchants',
        [WalletController::class, 'getMerchants']
    );
    Route::post('/wallet/pay-bill', [WalletController::class, 'payUtilityBill']);
    // US-048 Security Alerts
    Route::get('/security-events', [AuthController::class, 'securityEvents']);
    Route::patch(
        '/security/notifications/{id}/review',
        [WalletController::class, 'reviewSecurityNotification']
    );
    // US-049 Login Notification
    Route::get('/login-notifications', [AuthController::class, 'loginNotifications']);
    // US-050 Transaction Notification
    Route::get(
        '/wallet/transaction-notifications',
        [WalletController::class, 'transactionNotifications']
    );
    // US-052 — Suspicious Activity Notifications
    Route::get(
        '/security/notifications',
        [WalletController::class, 'securityNotifications']
    );
    // US-053 — Device Management
    Route::get(
        '/security/devices',
        [WalletController::class, 'devices']
    );
    Route::delete(
        '/security/devices/{deviceId}',
        [WalletController::class, 'revokeDevice']
    );
    // US-054 — Session Management
    Route::get(
        '/security/sessions',
        [AuthController::class, 'sessions']
    );

    Route::delete(
        '/security/sessions/other',
        [AuthController::class, 'revokeOtherSessions']
    );

    Route::delete(
        '/security/sessions/{id}',
        [AuthController::class, 'revokeSession']
    );
    // US-055: AUDIT LOG
    Route::get(
        '/security/audit-log',
        [AuthController::class, 'auditLog']
    );
    // US-056: ACTIVITY HISTORY
    Route::get(
        '/wallet/activity-history',
        [WalletController::class, 'activityHistory']
    );
    // US-057: ACCOUNT RECOVERY
    Route::post(
        '/account-recovery/request',
        [AuthController::class, 'accountRecoveryRequest']
    );

    Route::post(
        '/account-recovery/verify',
        [AuthController::class, 'accountRecoveryVerify']
    );

    Route::post(
        '/account-recovery/complete',
        [AuthController::class, 'accountRecoveryComplete']
    );
    // US-058: WALLET NOTIFICATIONS
    Route::get(
        '/notifications',
        [WalletNotificationController::class, 'index']
    );

    Route::get(
        '/notifications/unread-count',
        [WalletNotificationController::class, 'unreadCount']
    );

    Route::patch(
        '/notifications/read-all',
        [WalletNotificationController::class, 'markAllAsRead']
    );

    Route::patch(
        '/notifications/{id}/read',
        [WalletNotificationController::class, 'markAsRead']
    );

    Route::delete(
        '/notifications/{id}',
        [WalletNotificationController::class, 'destroy']
    );
    // ============================================================
    // SPRINT 5 — REPORTING
    // ============================================================
    // US-059 Daily Transaction Report
    Route::get(
        '/reports/daily',
        [ReportController::class, 'daily']
    );
    // US-060 Weekly Transaction Report
    Route::get(
        '/reports/weekly',
        [ReportController::class, 'weekly']
    );
    // US-061 Monthly Transaction Report
    Route::get(
        '/reports/monthly',
        [ReportController::class, 'monthly']
    );
    // US-062 User Report
    Route::get(
        '/reports/user',
        [ReportController::class, 'userReport']
    );
    // US-063 Wallet Balance Report
    Route::get(
        '/reports/wallet-balance',
        [ReportController::class, 'walletBalanceReport']
    );
    // US-064 Payment Report
    Route::get(
        '/reports/payments',
        [ReportController::class, 'paymentReport']
    );
    // US-065 Transfer Report
    Route::get(
        '/reports/transfers',
        [ReportController::class, 'transferReport']
    );
    // US-066 Revenue Report
    Route::get(
        '/reports/revenue',
        [ReportController::class, 'revenueReport']
    );
    // US-067 Transaction Analytics
    Route::get(
        '/reports/analytics',
        [ReportController::class, 'transactionAnalytics']
    );
    // US-068 Spending Analysis
    Route::get(
        '/reports/spending',
        [ReportController::class, 'spendingAnalysis']
    );
    // US-069 Income Summary
    Route::get(
        '/reports/income',
        [ReportController::class, 'incomeSummary']
    );
    // US-070 Expense Summary
    Route::get(
        '/reports/expenses',
        [ReportController::class, 'expenseSummary']
    );
    // US-072 — Export Report
    Route::get('/reports/export', [ReportController::class, 'export']);
    // US-073 — REPORT FILTER
    Route::get(
        '/reports/filter',
        [ReportController::class, 'filter']
    );
    // ============================================================
    // US-074 — DAILY EXPENSE TRACKER
    // ============================================================

    Route::get(
        '/expenses',
        [ExpenseController::class, 'index']
    );

    Route::post(
        '/expenses',
        [ExpenseController::class, 'store']
    );

    Route::get(
        '/expenses/summary',
        [ExpenseController::class, 'summary']
    );

    Route::get(
        '/expenses/{id}',
        [ExpenseController::class, 'show']
    );

    Route::put(
        '/expenses/{id}',
        [ExpenseController::class, 'update']
    );

    Route::patch(
        '/expenses/{id}',
        [ExpenseController::class, 'update']
    );

    Route::delete(
        '/expenses/{id}',
        [ExpenseController::class, 'destroy']
    );
    // ============================================================
    // US-075: SAVINGS GOAL REMINDER
    // ============================================================

    Route::get('/savings-goals', [
        SavingsGoalController::class,
        'index',
    ]);

    Route::post('/savings-goals', [
        SavingsGoalController::class,
        'store',
    ]);

    Route::get('/savings-goals/summary', [
        SavingsGoalController::class,
        'summary',
    ]);

    Route::get('/savings-goals/{id}', [
        SavingsGoalController::class,
        'show',
    ]);

    Route::put('/savings-goals/{id}', [
        SavingsGoalController::class,
        'update',
    ]);

    Route::patch('/savings-goals/{id}', [
        SavingsGoalController::class,
        'update',
    ]);

    Route::post('/savings-goals/{id}/contribute', [
        SavingsGoalController::class,
        'contribute',
    ]);

    Route::post('/savings-goals/{id}/cancel', [
        SavingsGoalController::class,
        'cancel',
    ]);

    Route::delete('/savings-goals/{id}', [
        SavingsGoalController::class,
        'destroy',
    ]);
    // US-075-A: DOWNLOAD PDF STATEMENT
    Route::get(
        '/reports/statement/pdf',
        [StatementController::class, 'downloadPdf']
    );
    // Sprint 6 — US-076 System Settings
    Route::get(
        '/admin/system-settings',
        [SystemSettingController::class, 'index']
    );

    Route::put(
        '/admin/system-settings',
        [SystemSettingController::class, 'update']
    );
    // US-077 Currency Management
    Route::get('/currencies', [CurrencyController::class, 'index']);
    Route::get('/currencies/convert', [CurrencyController::class, 'convert']);
    Route::get(
        '/currencies/summary',
        [CurrencyController::class, 'summary']
    );
    // Administrator currency management
    Route::middleware('auth:sanctum')
        ->prefix('admin')
        ->group(function () {
            Route::get('/currencies', [CurrencyController::class, 'adminIndex']);
            Route::post('/currencies', [CurrencyController::class, 'store']);
            Route::put('/currencies/{currency}', [CurrencyController::class, 'update']);
            Route::patch('/currencies/{currency}', [CurrencyController::class, 'update']);
            Route::patch('/currencies/{currency}/status', [CurrencyController::class, 'updateStatus']);
            Route::post('/currencies/{currency}/set-default', [CurrencyController::class, 'setDefault']);
        });
    Route::get(
        '/wallet/financial-insights',
        FinancialInsightsController::class
    );
    // US-078 Tax Settings Management
    Route::get('/tax-settings', [TaxSettingController::class, 'index']);
    Route::post('/tax-settings', [TaxSettingController::class, 'store']);
    Route::put('/tax-settings/{taxSetting}', [TaxSettingController::class, 'update']);
    Route::patch('/tax-settings/{taxSetting}', [TaxSettingController::class, 'update']);
    Route::patch('/tax-settings/{taxSetting}/status', [TaxSettingController::class, 'updateStatus']);
    // US-080 Database Backup ManagementRoute::get('/database-backups', [DatabaseBackupController::class, 'index']);
    Route::post('/database-backups', [DatabaseBackupController::class, 'store']);
    Route::get('/database-backups/{filename}/download', [DatabaseBackupController::class, 'download'])
        ->where('filename', 'nana-wallet-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}\.sql');
    // US-081 Database Restore Management
    Route::post(
        '/database-restore',
        [DatabaseRestoreController::class, 'restore']
    );
    // US-083 API MANAGEMENT
    Route::get('/api-keys', [ApiKeyController::class, 'index']);
    Route::post('/api-keys', [ApiKeyController::class, 'store']);
    Route::delete('/api-keys/{apiKey}', [ApiKeyController::class, 'revoke'])
        ->whereNumber('apiKey');
    // US-084 Third-Party Integration Management
    Route::get(
        '/third-party-integrations',
        [ThirdPartyIntegrationController::class, 'index']
    );
    Route::post(
        '/third-party-integrations',
        [ThirdPartyIntegrationController::class, 'store']
    );
    Route::put(
        '/third-party-integrations/{integration}',
        [ThirdPartyIntegrationController::class, 'update']
    );
    Route::patch(
        '/third-party-integrations/{integration}/status',
        [ThirdPartyIntegrationController::class, 'updateStatus']
    );
    // US-085 Language Preference Management
    Route::get(
        '/language-preference',
        [LanguagePreferenceController::class, 'show']
    );
    Route::put(
        '/language-preference',
        [LanguagePreferenceController::class, 'update']
    );

    // US-087 — AI Spending Recommendations
    Route::get(
        '/wallet/financial-recommendations',
        \App\Http\Controllers\Api\FinancialRecommendationController::class
    );

    // US-087-A — AI Assistant Chatbot
    Route::post(
        '/chatbot/message',
        [\App\Http\Controllers\Api\ChatbotController::class, 'chat']
    );

    // AI Spending Prediction
    Route::get(
        '/spending/prediction',
        [SpendingPredictionController::class, 'predict']
    );
    // US-088 — Loan Management
    Route::get('/loans', [LoanController::class, 'index']);
    Route::post('/loans', [LoanController::class, 'store']);
    Route::get('/loans/{id}', [LoanController::class, 'show']);
    Route::post('/loans/{id}/repay', [LoanController::class, 'repay']);
});