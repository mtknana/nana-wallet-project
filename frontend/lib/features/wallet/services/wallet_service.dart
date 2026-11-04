import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:digital_wallet_app/core/config/api_config.dart';

// ============================================================
// TRANSACTION NOTIFICATION STATE
// ============================================================

final ValueNotifier<int> transactionUnreadCount = ValueNotifier<int>(0);

void addTransactionNotification() {
  transactionUnreadCount.value++;
}

void clearTransactionNotifications() {
  transactionUnreadCount.value = 0;
}

// ============================================================
// WALLET MODEL
// ============================================================

class WalletModel {
  final int? id;
  final double balance;
  final String currency;
  final String status;
  final String name;

  WalletModel({
    this.id,
    required this.balance,
    required this.currency,
    required this.status,
    required this.name,
  });

  factory WalletModel.fromJson(
    Map<String, dynamic> json, {
    String? fallbackName,
  }) {
    return WalletModel(
      id: int.tryParse(json['id']?.toString() ?? ''),
      balance: double.tryParse(json['balance']?.toString() ?? '0.00') ?? 0.0,
      currency: json['currency']?.toString().toUpperCase() ?? 'USD',
      status:
          json['wallet_status']?.toString() ??
          json['status']?.toString() ??
          'active',
      name:
          json['user_name']?.toString() ??
          json['name']?.toString() ??
          fallbackName ??
          'User Account',
    );
  }

  String get symbol {
    switch (currency.toUpperCase()) {
      case 'KHR':
        return '៛';
      case 'USD':
      default:
        return '\$';
    }
  }

  String get formattedBalance {
    if (currency.toUpperCase() == 'KHR') {
      return balance.toStringAsFixed(0);
    }
    return balance.toStringAsFixed(2);
  }
}

// ============================================================
// TRANSACTION MODEL
// ============================================================

class TransactionModel {
  final String type;
  final double amount;
  final String description;
  final String referenceId;
  final String createdAt;
  final String status;
  final String currency;

  TransactionModel({
    required this.type,
    required this.amount,
    required this.description,
    required this.referenceId,
    required this.createdAt,
    required this.status,
    this.currency = 'USD',
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      type: json['type']?.toString() ?? 'deposit',
      amount: double.tryParse(json['amount']?.toString() ?? '0.00') ?? 0.0,
      description: json['description']?.toString() ?? '',
      referenceId:
          json['reference_id']?.toString() ??
          json['referenceId']?.toString() ??
          '',
      createdAt:
          json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
      status: json['status']?.toString().toLowerCase() ?? 'completed',
      currency: json['currency']?.toString().toUpperCase() ?? 'USD',
    );
  }

  String get symbol {
    switch (currency.toUpperCase()) {
      case 'KHR':
        return '៛';
      case 'USD':
      default:
        return '\$';
    }
  }

  String get formattedAmount {
    if (currency.toUpperCase() == 'KHR') {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }
}

// ============================================================
// WALLET SERVICE
// ============================================================

class WalletService {
  // For Flutter Web / desktop using a local Laravel server.
  // For an Android emulator, use http://10.0.2.2:8000/api instead.
  // For a physical phone, use your computer's LAN IP address.
  static const String baseUrl = ApiConfig.baseUrl;

  // ==========================================================
  // TOKEN VALIDATION
  // ==========================================================

  static String _validateToken(String token) {
    final sanitizedToken = token.trim();

    if (sanitizedToken.isEmpty) {
      throw Exception('Authentication token is empty. Please login again.');
    }

    return sanitizedToken;
  }

  // ==========================================================
  // COMMON GET REQUEST
  // ==========================================================

  static Future<Map<String, dynamic>> _getRequest(
    String endpoint,
    String token,
  ) async {
    try {
      final sanitizedToken = _validateToken(token);

      debugPrint('GET: $endpoint');

      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $sanitizedToken',
        },
      );

      debugPrint('Response [$endpoint]: ${response.statusCode}');

      if (response.body.trim().isEmpty) {
        return {'status': 'error', 'message': 'Empty server response'};
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return {
          'status': response.statusCode >= 200 && response.statusCode < 300
              ? 'success'
              : 'error',
          ...decoded,
        };
      }

      return {'status': 'error', 'message': 'Invalid server response'};
    } catch (e) {
      debugPrint('Exception in GET $endpoint: $e');

      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ==========================================================
  // COMMON POST REQUEST
  // ==========================================================

  static Future<Map<String, dynamic>> _postRequest(
    String endpoint,
    String token,
    Map<String, dynamic> body,
  ) async {
    try {
      final sanitizedToken = _validateToken(token);

      debugPrint('POST: $endpoint');

      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sanitizedToken',
        },
        body: jsonEncode(body),
      );

      debugPrint('Response [$endpoint]: ${response.statusCode}');

      final httpSuccess =
          response.statusCode >= 200 && response.statusCode < 300;

      if (response.body.trim().isEmpty) {
        if (httpSuccess) {
          return {
            'status': 'success',
            'message': 'Request completed successfully.',
          };
        }

        return {
          'status': 'error',
          'message': 'Request failed with HTTP status ${response.statusCode}.',
        };
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        if (!httpSuccess) {
          debugPrint(
            'API Error [$endpoint]: '
            '${response.statusCode} - ${response.body}',
          );
        }

        return {...decoded, 'status': httpSuccess ? 'success' : 'error'};
      }

      return {
        'status': httpSuccess ? 'success' : 'error',
        'message': 'Invalid server response',
      };
    } catch (e) {
      debugPrint('Exception in POST $endpoint: $e');

      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  static Future<Map<String, dynamic>> logout({required String token}) {
    return _postRequest('logout', token, {});
  }

  static Future<Map<String, dynamic>> sendChatbotMessage({
    required String token,
    required String message,
  }) {
    return _postRequest('chatbot/message', token, {'message': message});
  }

  // ==========================================================
  // WALLET BALANCES
  // ==========================================================

  static Future<List<WalletModel>> fetchWalletBalances(String token) async {
    try {
      final result = await _getRequest('wallet/balance', token);

      if (result['status'] != 'success') {
        debugPrint('Failed to fetch wallet balances');
        return [];
      }

      String userName =
          result['user_name']?.toString() ??
          result['name']?.toString() ??
          'User Account';

      dynamic walletsData = result['wallets'];

      if (walletsData is List) {
        return walletsData.whereType<Map>().map((wallet) {
          return WalletModel.fromJson(
            Map<String, dynamic>.from(wallet),
            fallbackName: userName,
          );
        }).toList();
      }

      if (result['data'] is Map) {
        final data = Map<String, dynamic>.from(result['data'] as Map);

        userName =
            data['user_name']?.toString() ??
            data['name']?.toString() ??
            userName;

        walletsData = data['wallets'];

        if (walletsData is List) {
          return walletsData.whereType<Map>().map((wallet) {
            return WalletModel.fromJson(
              Map<String, dynamic>.from(wallet),
              fallbackName: userName,
            );
          }).toList();
        }
      }

      if (result['balance'] != null) {
        return [WalletModel.fromJson(result, fallbackName: userName)];
      }

      debugPrint('No wallets found in response');
      return [];
    } catch (e) {
      debugPrint('Exception in fetchWalletBalances: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> fetchWallets({required String token}) {
    return _getRequest('wallet/balance', token);
  }

  static Future<WalletModel?> fetchBalance(String token) async {
    try {
      final wallets = await fetchWalletBalances(token);

      if (wallets.isEmpty) return null;

      for (final wallet in wallets) {
        if (wallet.currency.toUpperCase() == 'USD') {
          return wallet;
        }
      }

      return wallets.first;
    } catch (e) {
      debugPrint('Exception in fetchBalance: $e');
      return null;
    }
  }

  // ==========================================================
  // TRANSACTION PIN — SET
  // ==========================================================

  static Future<Map<String, dynamic>> setTransactionPin({
    required String token,
    required String transactionPin,
  }) {
    return _postRequest('set-transaction-pin', token, {
      'pin': transactionPin,
      'pin_confirmation': transactionPin,
    });
  }

  // ==========================================================
  // TRANSACTION PIN — CHANGE
  // ==========================================================

  static Future<Map<String, dynamic>> changeTransactionPin({
    required String token,
    required String currentPin,
    required String newPin,
  }) {
    return _postRequest('change-transaction-pin', token, {
      'current_pin': currentPin,
      'new_pin': newPin,
      'new_pin_confirmation': newPin,
    });
  }

  // ==========================================================
  // TRANSACTION PIN — STATUS
  // ==========================================================

  static Future<Map<String, dynamic>> getTransactionPinStatus({
    required String token,
  }) {
    return _getRequest('transaction-pin-status', token);
  }

  // ==========================================================
  // TRANSACTION PIN — VERIFY
  // ==========================================================

  static Future<Map<String, dynamic>> verifyTransactionPin({
    required String token,
    required String transactionPin,
  }) {
    return _postRequest('verify-transaction-pin', token, {
      'pin': transactionPin,
    });
  }

  // ==========================================================
  // WALLET TRANSFER BETWEEN USD / KHR — US-029
  // ==========================================================

  static Future<Map<String, dynamic>> executeWalletTransfer({
    required String token,
    required String fromCurrency,
    required String toCurrency,
    required double amount,
    required String idempotencyKey,
  }) async {
    final cleanFromCurrency = fromCurrency.toUpperCase();
    final cleanToCurrency = toCurrency.toUpperCase();
    final cleanIdempotencyKey = idempotencyKey.trim();

    if (cleanFromCurrency == cleanToCurrency) {
      return {
        'status': 'error',
        'message':
            'Source and destination wallets must use different currencies.',
      };
    }

    if (amount <= 0) {
      return {
        'status': 'error',
        'message': 'Transfer amount must be greater than zero.',
      };
    }

    if (cleanIdempotencyKey.isEmpty) {
      return {
        'status': 'error',
        'message': 'Transfer idempotency key is missing.',
      };
    }

    return _postRequest('wallet/transfer-between', token, {
      'from_currency': cleanFromCurrency,
      'to_currency': cleanToCurrency,
      'amount': amount,
      'idempotency_key': cleanIdempotencyKey,
    });
  }

  // ==========================================================
  // DEPOSIT
  // ==========================================================

  static Future<Map<String, dynamic>> executeDeposit({
    required String token,
    required double amount,
    required String idempotencyKey,
    String currency = 'USD',
  }) {
    return _postRequest('wallet/deposit', token, {
      'amount': amount,
      'currency': currency.toUpperCase(),
      'idempotency_key': idempotencyKey,
    });
  }

  // ==========================================================
  // WITHDRAW
  // ==========================================================

  static Future<Map<String, dynamic>> executeWithdraw({
    required String token,
    required double amount,
    required String idempotencyKey,
    String currency = 'USD',
  }) {
    return _postRequest('wallet/withdraw', token, {
      'amount': amount,
      'currency': currency.toUpperCase(),
      'idempotency_key': idempotencyKey,
    });
  }

  // ==========================================================
  // PROFILE
  // ==========================================================

  static Future<Map<String, dynamic>> fetchProfile({required String token}) {
    return _getRequest('profile', token);
  }

  // ==========================================================
  // CHANGE PASSWORD
  // ==========================================================

  static Future<Map<String, dynamic>> updateProfilePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) {
    return _postRequest('change-password', token, {
      'old_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': newPassword,
    });
  }

  // ==========================================================
  // VERIFY EMAIL
  // ==========================================================

  static Future<Map<String, dynamic>> verifyEmail({
    required String token,
    required String otpCode,
  }) {
    return _postRequest('verify-email', token, {'otp_code': otpCode});
  }

  // ==========================================================
  // VERIFY PHONE
  // ==========================================================

  static Future<Map<String, dynamic>> verifyPhone({
    required String token,
    required String otpCode,
  }) {
    return _postRequest('verify-phone', token, {'otp_code': otpCode});
  }

  // ==========================================================
  // LOGIN NOTIFICATIONS — US-049
  // ==========================================================

  static Future<List<Map<String, dynamic>>> fetchLoginNotifications({
    required String token,
  }) async {
    try {
      final result = await _getRequest('login-notifications', token);

      if (result['status'] != 'success') return [];

      final notifications = result['notifications'];

      if (notifications is! List) return [];

      return notifications
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Exception in fetchLoginNotifications: $e');
      return [];
    }
  }

  // ==========================================================
  // SECURITY EVENTS — US-048
  // ==========================================================

  static Future<List<Map<String, dynamic>>> fetchSecurityEvents({
    required String token,
  }) async {
    try {
      final result = await _getRequest('security-events', token);

      if (result['status'] != 'success') return [];

      final events = result['events'];

      if (events is! List) return [];

      return events
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Exception in fetchSecurityEvents: $e');
      return [];
    }
  }

  // ==========================================================
  // TWO-FACTOR AUTHENTICATION
  // ==========================================================

  static Future<Map<String, dynamic>> toggleTwoFactor({
    required String token,
    required bool enable,
  }) {
    return _postRequest('toggle-2fa', token, {'enable': enable});
  }

  static Future<Map<String, dynamic>> getTwoFactorStatus({
    required String token,
  }) {
    return _getRequest('two-factor-status', token);
  }

  // ==========================================================
  // TRANSACTION NOTIFICATIONS — US-050
  // ==========================================================

  static Future<List<TransactionModel>> fetchTransactionNotifications({
    required String token,
  }) async {
    try {
      final result = await _getRequest(
        'wallet/transaction-notifications',
        token,
      );

      if (result['status'] != 'success') return [];

      dynamic transactions;

      if (result['transactions'] is List) {
        transactions = result['transactions'];
      } else if (result['notifications'] is List) {
        transactions = result['notifications'];
      } else if (result['data'] is List) {
        transactions = result['data'];
      } else if (result['data'] is Map &&
          result['data']['transactions'] is List) {
        transactions = result['data']['transactions'];
      }

      if (transactions is! List) return [];

      return transactions
          .whereType<Map>()
          .map(
            (item) =>
                TransactionModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      debugPrint('Exception in fetchTransactionNotifications: $e');
      return [];
    }
  }

  // ==========================================================
  // PAYMENT HISTORY — US-041
  // ==========================================================

  static Future<List<TransactionModel>> fetchHistory(String token) async {
    try {
      final result = await _getRequest('wallet/history', token);

      if (result['status'] != 'success') return [];

      dynamic transactions;

      if (result['transactions'] is List) {
        transactions = result['transactions'];
      } else if (result['data'] is List) {
        transactions = result['data'];
      } else if (result['data'] is Map &&
          result['data']['transactions'] is List) {
        transactions = result['data']['transactions'];
      }

      if (transactions is! List) return [];

      return transactions
          .whereType<Map>()
          .map(
            (item) =>
                TransactionModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      debugPrint('Exception in fetchHistory: $e');
      return [];
    }
  }

  // ==========================================================
  // P2P TRANSFER — US-027
  // ==========================================================

  static Future<Map<String, dynamic>> executeP2pTransfer({
    required String token,
    required String email,
    required double amount,
    required String idempotencyKey,
    String description = '',
    String currency = 'USD',
  }) {
    return _postRequest('wallet/transfer', token, {
      'receiver_email': email,
      'amount': amount,
      'currency': currency.toUpperCase(),
      'idempotency_key': idempotencyKey,
      'description': description,
    });
  }

  // ==========================================================
  // QR WALLET TRANSFER — NaNa user QR codes resolve to a user ID.
  // ==========================================================

  static Future<Map<String, dynamic>> executeQrWalletTransfer({
    required String token,
    required int receiverUserId,
    required double amount,
    required String idempotencyKey,
    String currency = 'USD',
    String description = 'QR wallet payment',
  }) {
    return _postRequest('wallet/transfer', token, {
      'receiver_user_id': receiverUserId,
      'amount': amount,
      'currency': currency.toUpperCase(),
      'idempotency_key': idempotencyKey,
      'description': description,
    });
  }

  // Merchant QR payments use merchant IDs, not personal NaNa account QR codes.
  static Future<Map<String, dynamic>> executeMerchantQrPayment({
    required String token,
    required int merchantId,
    required double amount,
    required String idempotencyKey,
    String? qrPayload,
    String currency = 'USD',
  }) {
    return _postRequest('wallet/pay-qr', token, {
      'merchant_id': merchantId,
      'amount': amount,
      'currency': currency.toUpperCase(),
      'idempotency_key': idempotencyKey,
      if (qrPayload != null && qrPayload.trim().isNotEmpty)
        'qr_payload': qrPayload.trim(),
    });
  }

  // ==========================================================
  // SPLIT BILL — US-042
  // ==========================================================

  static Future<Map<String, dynamic>> submitSplitBill({
    required String token,
    required String title,
    required double totalAmount,
    required List<String> memberEmails,
    String currency = 'USD',
  }) {
    return _postRequest('wallet/split-bill', token, {
      'title': title,
      'total_amount': totalAmount,
      'currency': currency.toUpperCase(),
      'members': memberEmails
          .map((email) => {'email': email.trim().toLowerCase()})
          .toList(),
    });
  }

  static String readableErrorMessage(
    Map<String, dynamic> response, {
    required String fallback,
  }) {
    final errors = response['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }

    final message = response['message']?.toString().trim();
    return message == null || message.isEmpty ? fallback : message;
  }

  // ==========================================================
  // MERCHANTS
  // ==========================================================

  static Future<List<Map<String, dynamic>>> fetchMerchants({
    required String token,
    String? category,
  }) async {
    try {
      String endpoint = 'merchants';
      final cleanCategory = category?.trim();

      if (cleanCategory != null && cleanCategory.isNotEmpty) {
        endpoint =
            'merchants?category=${Uri.encodeQueryComponent(cleanCategory)}';
      }

      final result = await _getRequest(endpoint, token);

      if (result['status'] != 'success') return [];

      final merchants = result['merchants'];

      if (merchants is! List) return [];

      return merchants
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Exception in fetchMerchants: $e');
      return [];
    }
  }

  // ==========================================================
  // BILL PAYMENT — US-033
  // ==========================================================

  static Future<Map<String, dynamic>> executeBillPayment({
    required String token,
    required int merchantId,
    required String consumerNumber,
    required double amount,
    required String idempotencyKey,
    String currency = 'USD',
  }) {
    return _postRequest('wallet/pay-bill', token, {
      'merchant_id': merchantId,
      'consumer_number': consumerNumber,
      'amount': amount,
      'currency': currency.toUpperCase(),
      'idempotency_key': idempotencyKey,
    });
  }

  // ==========================================================
  // MOBILE TOP-UP — US-034
  // ==========================================================

  static Future<Map<String, dynamic>> executeMobileTopUp({
    required String token,
    required String phoneNumber,
    required double amount,
    required String idempotencyKey,
    String currency = 'USD',
  }) {
    return _postRequest('wallet/top-up', token, {
      'phone': phoneNumber,
      'amount': amount,
      'currency': currency.toUpperCase(),
      'idempotency_key': idempotencyKey,
    });
  }

  // ==========================================================
  // CANCEL TRANSACTION — US-038
  // ==========================================================

  static Future<Map<String, dynamic>> cancelTransaction({
    required String token,
    required String referenceId,
  }) {
    return _postRequest('wallet/cancel-tx', token, {
      'reference_id': referenceId,
    });
  }

  // ==========================================================
  // EMAIL RECEIPT — US-040
  // ==========================================================

  static Future<Map<String, dynamic>> emailTransactionReceipt({
    required String token,
    required String referenceId,
  }) {
    return _postRequest('wallet/email-receipt', token, {
      'reference_id': referenceId,
    });
  }

  // ==========================================================
  // SCHEDULED PAYMENT — US-035
  // ==========================================================

  static Future<Map<String, dynamic>> createScheduledPayment({
    required String token,
    required String paymentType,
    required String recipient,
    required double amount,
    required String currency,
    required String scheduledDate,
    String? description,
    bool isRecurring = false,
    String? recurrencePeriod,
  }) {
    return _postRequest('scheduled-payments', token, {
      'payment_type': paymentType,
      'recipient': recipient,
      'amount': amount,
      'currency': currency.toUpperCase(),
      'scheduled_date': scheduledDate,
      'description': description,
      'is_recurring': isRecurring,
      'recurrence_period': recurrencePeriod,
    });
  }

  // ==========================================================
  // FETCH SCHEDULED PAYMENTS
  // ==========================================================

  static Future<Map<String, dynamic>> fetchScheduledPayments({
    required String token,
  }) {
    return _getRequest('scheduled-payments', token);
  }

  // ==========================================================
  // CANCEL SCHEDULED PAYMENT
  // ==========================================================

  static Future<Map<String, dynamic>> cancelScheduledPayment({
    required String token,
    required int id,
  }) async {
    try {
      final sanitizedToken = _validateToken(token);

      final response = await http.delete(
        Uri.parse('$baseUrl/scheduled-payments/$id'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $sanitizedToken',
        },
      );

      debugPrint('Scheduled payment response: ${response.statusCode}');

      if (response.body.trim().isEmpty) {
        return {'status': 'error', 'message': 'Empty server response'};
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return {
          ...decoded,
          'status': response.statusCode >= 200 && response.statusCode < 300
              ? 'success'
              : 'error',
        };
      }

      return {'status': 'error', 'message': 'Invalid server response'};
    } catch (e) {
      debugPrint('Exception in cancelScheduledPayment: $e');

      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ==========================================================
  // DOWNLOAD PDF STATEMENT — US-075-A
  // ==========================================================

  static Future<Uint8List> downloadPdfStatement({
    required String token,
    required String currency,
    String? startDate,
    String? endDate,
  }) async {
    final sanitizedToken = _validateToken(token);

    final queryParameters = <String, String>{
      'currency': currency.toUpperCase(),
    };

    if (startDate != null && startDate.trim().isNotEmpty) {
      queryParameters['start_date'] = startDate.trim();
    }

    if (endDate != null && endDate.trim().isNotEmpty) {
      queryParameters['end_date'] = endDate.trim();
    }

    final uri = Uri.parse(
      '$baseUrl/reports/statement/pdf',
    ).replace(queryParameters: queryParameters);

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/pdf',
        'Authorization': 'Bearer $sanitizedToken',
      },
    );

    debugPrint('Statement response: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) {
        throw Exception('The server returned an empty PDF.');
      }

      return response.bodyBytes;
    }

    String message = 'Unable to generate statement.';

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        message =
            decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            message;
      }
    } catch (_) {
      // The error response was not JSON.
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please login again.');
    }

    if (response.statusCode == 422) {
      throw Exception(message);
    }

    throw Exception('$message (HTTP ${response.statusCode})');
  }

  // ==========================================================
  // EXCHANGE RATES — US-085
  // ==========================================================

  static Future<Map<String, dynamic>> fetchCurrencies({required String token}) {
    return _getRequest('currencies', token);
  }

  static Future<Map<String, dynamic>> convertCurrency({
    required String token,
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    final query = Uri(
      queryParameters: {
        'amount': amount.toString(),
        'from': fromCurrency.toUpperCase(),
        'to': toCurrency.toUpperCase(),
      },
    ).query;

    return _getRequest('currencies/convert?$query', token);
  }

  // ==========================================================
  // US-086 — AI SPENDING PREDICTION
  // ==========================================================

  static Future<Map<String, dynamic>> fetchSpendingPrediction({
    required String token,
    String currency = 'USD',
  }) {
    final query = Uri(
      queryParameters: {'currency': currency.toUpperCase()},
    ).query;

    return _getRequest('spending/prediction?$query', token);
  }

  // ==========================================================
  // NANA QUICK LOAN
  // ==========================================================

  // Fetch the authenticated user's loan history.
  static Future<Map<String, dynamic>> fetchLoans({required String token}) {
    return _getRequest('loans', token);
  }

  // Submit a new loan application.
  static Future<Map<String, dynamic>> applyForLoan({
    required String token,
    required double amount,
    required String currency,
    required int termDays,
    required String idempotencyKey,
  }) {
    return _postRequest('loans', token, {
      'amount': amount,
      'currency': currency.toUpperCase(),
      'term_days': termDays,
      'idempotency_key': idempotencyKey,
    });
  }

  // Fetch a specific loan and its repayment records.
  static Future<Map<String, dynamic>> fetchLoanDetails({
    required String token,
    required int loanId,
  }) {
    return _getRequest('loans/$loanId', token);
  }

  // Manually repay an existing loan.
  static Future<Map<String, dynamic>> repayLoan({
    required String token,
    required int loanId,
    required double amount,
    required String idempotencyKey,
  }) {
    return _postRequest('loans/$loanId/repay', token, {
      'amount': amount.toString(),
      'idempotency_key': idempotencyKey,
    });
  }
}
