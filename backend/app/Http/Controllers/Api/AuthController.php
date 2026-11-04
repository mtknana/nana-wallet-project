<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Wallet;
use App\Models\SecurityEvent;
use App\Models\Device;
use App\Services\SecurityEventLogger;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    // ============================================================
    // REGISTER
    // ============================================================

    public function register(Request $request)
    {
        $validator = Validator::make(
            $request->all(),
            [
                'name' => 'required|string|max:255',
                'email' => 'required|string|email|max:255|unique:users',
                'password' => 'required|string|min:8|confirmed',
            ]
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $result = DB::transaction(function () use ($request) {

                $user = User::create([
                    'name' => $request->name,
                    'email' => $request->email,
                    'password' => Hash::make($request->password),
                    'role' => 'user',
                ]);

                // Create USD wallet
                Wallet::create([
                    'user_id' => $user->id,
                    'currency' => 'USD',
                    'balance' => 0.00,
                    'status' => 'active',
                    'name' => 'USD Wallet',
                ]);

                // Create KHR wallet
                Wallet::create([
                    'user_id' => $user->id,
                    'currency' => 'KHR',
                    'balance' => 0.00,
                    'status' => 'active',
                    'name' => 'KHR Wallet',
                ]);

                // Create Sanctum token
                $newToken = $user->createToken(
                    'walletapptoken'
                );

                $newToken->accessToken->update([
                    'ip_address' => $request->ip(),
                    'user_agent' => $request->userAgent(),
                ]);

                return [
                    'user' => $user,
                    'token' => $newToken->plainTextToken,
                ];
            });

            SecurityEventLogger::log(
                $result['user'],
                'account_created',
                'Account Created',
                'A new NaNa Wallet account was created.',
                'info',
                null,
                null,
                $request
            );

            return response()->json([
                'status' => 'success',
                'message' => 'Registration successful.',
                'user' => $result['user'],
                'token' => $result['token'],
            ], 201);

        } catch (\Throwable $e) {

            return response()->json([
                'status' => 'error',
                'message' => 'Registration failed.',
                'error' => $e->getMessage(),
            ], 500);
        }
    }


    // ============================================================
    // LOGIN
    // ============================================================

    public function login(Request $request)
    {
        $fields = $request->validate([
            'email' => 'required|string',
            'password' => 'required|string',
        ]);

        $user = User::where(
            'email',
            $fields['email']
        )->first();

        // --------------------------------------------------------
        // INVALID LOGIN
        // --------------------------------------------------------

        if (
            !$user ||
            !Hash::check(
                $fields['password'],
                $user->password
            )
        ) {
            SecurityEventLogger::log(
                null,
                'login_failed',
                'Login Failed',
                'A failed login attempt was detected.',
                'warning',
                null,
                null,
                $request
            );

            return response()->json([
                'status' => 'error',
                'message' => 'Invalid credentials',
            ], 401);
        }

        // --------------------------------------------------------
        // US-054: CREATE LOGIN SESSION
        // --------------------------------------------------------

        $newToken = $user->createToken(
            'walletapptoken'
        );

        // Save IP address and browser/device information
        $newToken->accessToken->update([
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        $token = $newToken->plainTextToken;

        // --------------------------------------------------------
        // US-053: REGISTER / UPDATE DEVICE
        // --------------------------------------------------------

        try {
            $deviceId = $request->header(
                'X-Device-Id'
            );

            $deviceName = $request->header(
                'X-Device-Name'
            );

            $platform = $request->header(
                'X-Device-Platform'
            );

            if (!$deviceId) {
                $deviceId = hash(
                    'sha256',
                    ($request->userAgent() ?? 'unknown')
                    . '|'
                    . ($request->ip() ?? 'unknown')
                );
            }

            Device::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'device_id' => $deviceId,
                ],
                [
                    'device_name' =>
                        $deviceName
                        ?? 'Unknown Device',

                    'platform' =>
                        $platform
                        ?? 'Unknown',

                    'ip_address' =>
                        $request->ip(),

                    'user_agent' =>
                        $request->userAgent(),

                    'last_used_at' =>
                        now(),

                    'is_active' => true,
                ]
            );

        } catch (\Throwable $e) {
            // Device registration should not prevent login.
        }

        // --------------------------------------------------------
        // US-049: LOGIN NOTIFICATION
        // --------------------------------------------------------

        SecurityEventLogger::log(
            $user,
            'login_success',
            'Login Successful',
            'A successful login was detected on your NaNa Wallet account.',
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'user' => $user,
            'token' => $token,
        ], 200);
    }


    // ============================================================
    // FORGOT PASSWORD
    // ============================================================

    public function forgotPassword(Request $request)
    {
        $validator = Validator::make(
            $request->all(),
            [
                'email' => 'required|email',
            ]
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Please provide a valid email address.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = User::where(
            'email',
            $request->email
        )->first();

        /*
         * Do not reveal whether the account exists.
         */

        if (!$user) {
            return response()->json([
                'status' => 'success',
                'message' =>
                    'If the email exists, a reset code has been generated.',
            ], 200);
        }

        // Generate 6-digit reset code
        $resetCode = (string) random_int(
            100000,
            999999
        );

        DB::table('password_reset_tokens')
            ->updateOrInsert(
                [
                    'email' => $user->email,
                ],
                [
                    'token' => Hash::make($resetCode),
                    'created_at' => now(),
                ]
            );

        SecurityEventLogger::log(
            $user,
            'password_reset_requested',
            'Password Reset Requested',
            'A password reset code was requested for this account.',
            'info',
            null,
            null,
            $request
        );

        /*
         * School project:
         * Return the reset code directly.
         *
         * In a production application this would normally
         * be sent through email or SMS instead.
         */

        return response()->json([
            'status' => 'success',
            'message' =>
                'Password reset code generated successfully.',
            'reset_code' => $resetCode,
        ], 200);
    }


    // ============================================================
    // US-049: LOGIN NOTIFICATIONS
    // ============================================================

    public function loginNotifications(Request $request)
    {
        $user = $request->user();

        $notifications = $user->securityEvents()
            ->whereIn('event_type', [
                'login_success',
                'login_failed',
            ])
            ->orderByDesc('occurred_at')
            ->limit(20)
            ->get([
                'id',
                'event_type',
                'severity',
                'title',
                'description',
                'ip_address',
                'user_agent',
                'is_reviewed',
                'occurred_at',
            ]);

        return response()->json([
            'status' => 'success',
            'notifications' => $notifications,
        ], 200);
    }


    // ============================================================
    // US-048: SECURITY EVENTS
    // ============================================================

    public function securityEvents(Request $request)
    {
        $user = $request->user();

        $events = $user->securityEvents()
            ->orderByDesc('occurred_at')
            ->get([
                'id',
                'event_type',
                'severity',
                'title',
                'description',
                'is_reviewed',
                'occurred_at',
            ]);

        return response()->json([
            'status' => 'success',
            'events' => $events,
        ], 200);
    }


    // ============================================================
    // PROFILE
    // ============================================================

    public function profile(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'status' => 'success',
            'user' => $user,
        ], 200);
    }


    // ============================================================
    // LOGOUT
    // ============================================================

    public function logout(Request $request)
    {
        $user = $request->user();

        $currentToken = $user->currentAccessToken();

        if ($currentToken) {
            $currentToken->delete();
        }

        SecurityEventLogger::log(
            $user,
            'logout',
            'Logged Out',
            'The user logged out of the NaNa Wallet application.',
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Logged out successfully.',
        ], 200);
    }


    // ============================================================
    // CHANGE PASSWORD
    // ============================================================

    public function changePassword(Request $request)
    {
        $validator = Validator::make(
            $request->all(),
            [
                'current_password' =>
                    'required|string',

                'new_password' =>
                    'required|string|min:8|confirmed',
            ]
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = $request->user();

        if (
            !Hash::check(
                $request->current_password,
                $user->password
            )
        ) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'Current password is incorrect.',
            ], 401);
        }

        $user->password = Hash::make(
            $request->new_password
        );

        $user->save();

        SecurityEventLogger::log(
            $user,
            'password_changed',
            'Password Changed',
            'The account password was changed successfully.',
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' =>
                'Password changed successfully.',
        ], 200);
    }


    // ============================================================
    // TRANSACTION PIN STATUS
    // ============================================================

    public function transactionPinStatus(
        Request $request
    ) {
        $user = $request->user();

        return response()->json([
            'status' => 'success',
            'has_transaction_pin' =>
                !empty($user->transaction_pin),
        ], 200);
    }


    // ============================================================
    // SET TRANSACTION PIN
    // ============================================================

    public function setTransactionPin(
        Request $request
    ) {
        $validator = Validator::make(
            $request->all(),
            [
                'pin' =>
                    'required|digits:4',

                'pin_confirmation' =>
                    'required|same:pin',
            ]
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid PIN information.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = $request->user();

        if (!empty($user->transaction_pin)) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'Transaction PIN already exists.',
            ], 400);
        }

        $user->transaction_pin = Hash::make(
            $request->pin
        );

        $user->save();

        SecurityEventLogger::log(
            $user,
            'transaction_pin_created',
            'Transaction PIN Created',
            'A transaction PIN was created for the account.',
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' =>
                'Transaction PIN created successfully.',
        ], 200);
    }


    // ============================================================
    // CHANGE TRANSACTION PIN
    // ============================================================

    public function changeTransactionPin(
        Request $request
    ) {
        $validator = Validator::make(
            $request->all(),
            [
                'current_pin' =>
                    'required|digits:4',

                'new_pin' =>
                    'required|digits:4',

                'new_pin_confirmation' =>
                    'required|same:new_pin',
            ]
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid PIN information.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = $request->user();

        if (empty($user->transaction_pin)) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'Transaction PIN has not been set.',
            ], 400);
        }

        if (
            !Hash::check(
                $request->current_pin,
                $user->transaction_pin
            )
        ) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'Current PIN is incorrect.',
            ], 401);
        }

        if (
            Hash::check(
                $request->new_pin,
                $user->transaction_pin
            )
        ) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'New PIN must be different from current PIN.',
            ], 400);
        }

        $user->transaction_pin = Hash::make(
            $request->new_pin
        );

        $user->save();

        SecurityEventLogger::log(
            $user,
            'transaction_pin_changed',
            'Transaction PIN Changed',
            'The transaction PIN was changed successfully.',
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' =>
                'Transaction PIN changed successfully.',
        ], 200);
    }


    // ============================================================
    // VERIFY TRANSACTION PIN
    // ============================================================

    public function verifyTransactionPin(
        Request $request
    ) {
        $validator = Validator::make(
            $request->all(),
            [
                'pin' =>
                    'required|digits:4',
            ]
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'PIN must contain exactly 4 digits.',
            ], 422);
        }

        $user = $request->user();

        if (empty($user->transaction_pin)) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'Transaction PIN has not been set.',
            ], 400);
        }

        if (
            !Hash::check(
                $request->pin,
                $user->transaction_pin
            )
        ) {
            SecurityEventLogger::log(
                $user,
                'transaction_pin_failed',
                'Transaction PIN Failed',
                'An incorrect transaction PIN was entered.',
                'warning',
                null,
                null,
                $request
            );

            return response()->json([
                'status' => 'error',
                'message' =>
                    'Incorrect transaction PIN.',
            ], 401);
        }

        return response()->json([
            'status' => 'success',
            'message' =>
                'Transaction PIN verified successfully.',
        ], 200);
    }


    // ============================================================
    // VERIFY EMAIL
    // ============================================================

    public function verifyEmail(Request $request)
    {
        $validator = Validator::make(
            $request->all(),
            [
                'code' =>
                    'required|string',
            ]
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Verification code is required.',
            ], 422);
        }

        /*
         * School project mock verification code.
         */
        if ($request->code !== '123456') {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'Invalid email verification code.',
            ], 400);
        }

        $user = $request->user();

        $user->email_verified_at = now();
        $user->save();

        SecurityEventLogger::log(
            $user,
            'email_verified',
            'Email Verified',
            'The account email address was verified successfully.',
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' =>
                'Email verified successfully.',
        ], 200);
    }


    // ============================================================
    // VERIFY PHONE
    // ============================================================

    public function verifyPhone(Request $request)
    {
        $validator = Validator::make(
            $request->all(),
            [
                'code' =>
                    'required|string',
            ]
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Verification code is required.',
            ], 422);
        }

        /*
         * School project mock OTP.
         */
        if ($request->code !== '654321') {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'Invalid phone verification code.',
            ], 400);
        }

        $user = $request->user();

        $user->phone_verified_at = now();
        $user->save();

        SecurityEventLogger::log(
            $user,
            'phone_verified',
            'Phone Verified',
            'The account phone number was verified successfully.',
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' =>
                'Phone verified successfully.',
        ], 200);
    }


    // ============================================================
    // TOGGLE TWO FACTOR AUTHENTICATION
    // ============================================================

    public function toggleTwoFactor(
        Request $request
    ) {
        $user = $request->user();

        $user->two_factor_enabled =
            !$user->two_factor_enabled;

        /*
         * School project mock secret.
         */
        if ($user->two_factor_enabled) {
            $user->two_factor_secret =
                'KHMERWALLETSECRET2026';
        } else {
            $user->two_factor_secret = null;
        }

        $user->save();

        SecurityEventLogger::log(
            $user,
            'two_factor_changed',
            'Two-Factor Authentication Updated',
            $user->two_factor_enabled
            ? 'Two-factor authentication was enabled.'
            : 'Two-factor authentication was disabled.',
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' =>
                $user->two_factor_enabled
                ? 'Two-factor authentication enabled.'
                : 'Two-factor authentication disabled.',
            'two_factor_enabled' =>
                $user->two_factor_enabled,
        ], 200);
    }


    // ============================================================
    // TWO FACTOR STATUS
    // ============================================================

    public function twoFactorStatus(
        Request $request
    ) {
        $user = $request->user();

        return response()->json([
            'status' => 'success',
            'two_factor_enabled' =>
                (bool) $user->two_factor_enabled,
        ], 200);
    }


    // ============================================================
    // US-054: GET ACTIVE SESSIONS
    // ============================================================

    public function sessions(Request $request)
    {
        $user = $request->user();

        $currentTokenId =
            $user->currentAccessToken()?->id;

        $sessions = $user->tokens()
            ->orderByDesc('last_used_at')
            ->orderByDesc('created_at')
            ->get()
            ->map(function ($token) use ($currentTokenId) {
                return [
                    'id' => $token->id,

                    'name' =>
                        $token->name,

                    'device' =>
                        $this->detectDevice(
                            $token->user_agent
                        ),

                    'ip_address' =>
                        $token->ip_address,

                    'user_agent' =>
                        $token->user_agent,

                    'last_used_at' =>
                        $token->last_used_at,

                    'created_at' =>
                        $token->created_at,

                    'expires_at' =>
                        $token->expires_at,

                    'is_current' =>
                        $token->id === $currentTokenId,
                ];
            });

        return response()->json([
            'status' => 'success',
            'sessions' => $sessions,
        ], 200);
    }


    // ============================================================
    // US-054: REVOKE ONE SESSION
    // ============================================================

    public function revokeSession(
        Request $request,
        int $id
    ) {
        $user = $request->user();

        $token = $user->tokens()
            ->where('id', $id)
            ->first();

        if (!$token) {
            return response()->json([
                'status' => 'error',
                'message' => 'Session not found.',
            ], 404);
        }

        $currentToken =
            $user->currentAccessToken();

        if (
            $currentToken &&
            $token->id === $currentToken->id
        ) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'You cannot revoke your current session.',
            ], 400);
        }

        $token->delete();

        SecurityEventLogger::log(
            $user,
            'session_revoked',
            'Session Revoked',
            'A login session was revoked from Session Management.',
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' =>
                'Session revoked successfully.',
        ], 200);
    }


    // ============================================================
    // US-054: REVOKE ALL OTHER SESSIONS
    // ============================================================

    public function revokeOtherSessions(
        Request $request
    ) {
        $user = $request->user();

        $currentToken =
            $user->currentAccessToken();

        if (!$currentToken) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'Current session could not be identified.',
            ], 400);
        }

        $deletedCount = $user->tokens()
            ->where(
                'id',
                '!=',
                $currentToken->id
            )
            ->delete();

        SecurityEventLogger::log(
            $user,
            'other_sessions_revoked',
            'Other Sessions Revoked',
            sprintf(
                '%d other login session(s) were revoked.',
                $deletedCount
            ),
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' =>
                'All other sessions have been revoked.',
            'revoked_count' =>
                $deletedCount,
        ], 200);
    }


    // ============================================================
    // US-054: DEVICE DETECTION
    // ============================================================

    private function detectDevice(
        ?string $userAgent
    ): string {
        if (!$userAgent) {
            return 'Unknown Device';
        }

        $agent = strtolower($userAgent);

        if (
            str_contains($agent, 'iphone') ||
            str_contains($agent, 'ipad')
        ) {
            return 'iPhone / iPad';
        }

        if (str_contains($agent, 'android')) {
            return 'Android Device';
        }

        if (
            str_contains($agent, 'windows') ||
            str_contains($agent, 'macintosh') ||
            str_contains($agent, 'linux')
        ) {
            return 'Desktop / Laptop';
        }

        return 'Unknown Device';
    }
    // ============================================================
// US-055: AUDIT LOG
// ============================================================

    public function auditLog(Request $request)
    {
        $user = $request->user();

        $logs = $user->securityEvents()
            ->orderByDesc('occurred_at')
            ->limit(100)
            ->get([
                'id',
                'event_type',
                'severity',
                'title',
                'description',
                'ip_address',
                'user_agent',
                'reference_type',
                'reference_id',
                'is_reviewed',
                'occurred_at',
            ]);

        return response()->json([
            'status' => 'success',
            'logs' => $logs,
        ], 200);
    }
    // ============================================================
    // US-057: ACCOUNT RECOVERY
    // ============================================================

    public function accountRecoveryRequest(
        Request $request
    ) {
        $request->validate([
            'email' => [
                'required',
                'email',
            ],
        ]);

        $user = User::where(
            'email',
            $request->email
        )->first();

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'No account was found with this email address.',
            ], 404);
        }

        $code = (string) random_int(
            100000,
            999999
        );

        DB::table('password_reset_tokens')
            ->updateOrInsert(
                [
                    'email' => $user->email,
                ],
                [
                    'token' => Hash::make($code),
                    'created_at' => now(),
                ]
            );

        SecurityEventLogger::log(
            $user,
            'account_recovery_requested',
            'Account Recovery Requested',
            'An account recovery request was made.',
            'warning',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' =>
                'Account recovery code generated successfully.',
            'code' => $code,
        ], 200);
    }
    public function accountRecoveryVerify(
        Request $request
    ) {
        $request->validate([
            'email' => [
                'required',
                'email',
            ],
            'code' => [
                'required',
                'digits:6',
            ],
        ]);

        $record = DB::table(
            'password_reset_tokens'
        )
            ->where(
                'email',
                $request->email
            )
            ->first();

        if (!$record) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'No recovery request was found.',
            ], 404);
        }

        if (
            Carbon::parse(
                $record->created_at
            )->addMinutes(15)->isPast()
        ) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'The recovery code has expired.',
            ], 400);
        }

        if (
            !Hash::check(
                $request->code,
                $record->token
            )
        ) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'Invalid recovery code.',
            ], 400);
        }

        return response()->json([
            'status' => 'success',
            'message' =>
                'Recovery code verified successfully.',
        ], 200);
    }
    public function accountRecoveryComplete(
        Request $request
    ) {
        $request->validate([
            'email' => [
                'required',
                'email',
            ],
            'code' => [
                'required',
                'digits:6',
            ],
            'password' => [
                'required',
                'string',
                'min:8',
                'confirmed',
            ],
        ]);

        $record = DB::table(
            'password_reset_tokens'
        )
            ->where(
                'email',
                $request->email
            )
            ->first();

        if (!$record) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'No recovery request was found.',
            ], 404);
        }

        if (
            Carbon::parse(
                $record->created_at
            )->addMinutes(15)->isPast()
        ) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'The recovery code has expired.',
            ], 400);
        }

        if (
            !Hash::check(
                $request->code,
                $record->token
            )
        ) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'Invalid recovery code.',
            ], 400);
        }

        $user = User::where(
            'email',
            $request->email
        )->first();

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' =>
                    'User account not found.',
            ], 404);
        }

        $user->password = Hash::make(
            $request->password
        );

        $user->save();

        // Invalidate all existing login sessions.
        $user->tokens()->delete();

        DB::table(
            'password_reset_tokens'
        )
            ->where(
                'email',
                $request->email
            )
            ->delete();

        SecurityEventLogger::log(
            $user,
            'account_recovery_completed',
            'Account Recovery Completed',
            'The account password was successfully reset through account recovery.',
            'info',
            null,
            null,
            $request
        );

        return response()->json([
            'status' => 'success',
            'message' =>
                'Your account has been successfully recovered. Please login again.',
        ], 200);
    }
}