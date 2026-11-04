import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

enum _QrPaymentStep { scan, amount, success }

class QrPaymentScreen extends StatefulWidget {
  QrPaymentScreen({super.key});

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _payloadController = TextEditingController();

  late final MobileScannerController _scannerController;

  String _token = '';
  String _currentUserId = '';
  String _scannedUserId = '';
  String _scannedUserName = '';
  String _cameraError = '';

  CameraFacing _cameraFacing = CameraFacing.unknown;

  bool _initialized = false;
  bool _profileLoading = true;
  bool _cameraRunning = false;
  bool _switchingCamera = false;
  bool _hasScanned = false;
  bool _isProcessing = false;
  _QrPaymentStep _currentStep = _QrPaymentStep.scan;
  String _successReference = '';
  String _successMessage = '';
  String _pendingIdempotencyKey = '';

  double _selectedAmount = 5.0;

  final List<double> _quickAmounts = [1, 5, 10, 20, 50];

  @override
  void initState() {
    super.initState();

    // IMPORTANT:
    // Let the mounted MobileScanner widget start the camera.
    // Do not call controller.start() here before the scanner
    // widget has entered the widget tree.
    _scannerController = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    _scannerController.addListener(_onCameraStateChanged);
  }

  void _onCameraStateChanged() {
    if (!mounted) return;

    final state = _scannerController.value;

    final running = state.isRunning;
    final facing = state.cameraDirection;

    if (_cameraRunning != running ||
        _cameraFacing != facing ||
        (_cameraError.isNotEmpty && running)) {
      setState(() {
        _cameraRunning = running;
        _cameraFacing = facing;
        if (running) _cameraError = '';
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is String && args.trim().isNotEmpty) {
      _token = args.trim();
      _loadCurrentUser();
    } else {
      _profileLoading = false;
    }
  }

  @override
  void dispose() {
    _scannerController.removeListener(_onCameraStateChanged);
    _scannerController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _payloadController.dispose();
    super.dispose();
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> _loadCurrentUser() async {
    if (_token.isEmpty) {
      if (mounted) setState(() => _profileLoading = false);
      return;
    }

    try {
      final result = await WalletService.fetchProfile(token: _token);

      if (!mounted) return;

      final user = result['user'];

      if (result['status'] != 'success' ||
          user is! Map<String, dynamic> ||
          user['id'] == null) {
        setState(() => _profileLoading = false);
        _showError('NaNa could not verify your account. Please log in again.');
        return;
      }

      setState(() {
        _currentUserId = user['id'].toString();
        _profileLoading = false;
      });
    } catch (e) {
      debugPrint('Profile loading error: $e');

      if (!mounted) return;

      setState(() => _profileLoading = false);
      _showError('Unable to verify your account. Check your connection.');
    }
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> _switchCamera() async {
    if (_switchingCamera) return;

    final requested = _cameraFacing == CameraFacing.front
        ? CameraFacing.back
        : CameraFacing.front;

    setState(() {
      _switchingCamera = true;
      _cameraError = '';
    });

    try {
      await _scannerController.switchCamera(
        SelectCamera(facingDirection: requested),
      );

      if (!mounted) return;

      final state = _scannerController.value;

      setState(() {
        _cameraFacing = state.cameraDirection;
        _cameraRunning = state.isRunning;
        _switchingCamera = false;
      });

      debugPrint(
        'Camera switch: requested=${requested.name}, '
        'actual=${state.cameraDirection.name}, '
        'running=${state.isRunning}',
      );

      if (state.cameraDirection != requested &&
          state.cameraDirection != CameraFacing.unknown) {
        _showInfo(
          'This device may not have a separate ${requested.name} camera.',
        );
      }
    } catch (e) {
      debugPrint('Camera switch error: $e');

      if (!mounted) return;

      setState(() => _switchingCamera = false);
      _showInfo(
        'Unable to switch cameras on this device. '
        'You can still use the available camera.',
      );
    }
  }

  Future<void> _toggleTorch() async {
    if (_scannerController.value.torchState == TorchState.unavailable) {
      _showInfo('Torch is unavailable on this camera.');
      return;
    }

    try {
      await _scannerController.toggleTorch();
    } catch (e) {
      debugPrint('Torch error: $e');
      _showInfo('This camera does not support the torch.');
    }
  }

  Future<void> _restartScanner() async {
    setState(() {
      _currentStep = _QrPaymentStep.scan;
      _isProcessing = false;
      _hasScanned = false;
      _scannedUserId = '';
      _scannedUserName = '';
      _successReference = '';
      _successMessage = '';
      _pendingIdempotencyKey = '';
      _recipientController.clear();
      _amountController.clear();
      _payloadController.clear();
      _selectedAmount = 5.0;
      _cameraError = '';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _scannerController.start();
      } catch (e) {
        debugPrint('Scanner restart error: $e');
        if (mounted)
          setState(() => _cameraError = 'Unable to restart the camera.');
      }
    });
  }

  // ============================================================
  // QR DETECTION
  // ============================================================

  void _onQrDetected(BarcodeCapture capture) {
    if (_hasScanned || _profileLoading) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();

      if (value == null || value.isEmpty) continue;

      debugPrint('QR detected: $value');

      _processScannedQr(value);
      return;
    }
  }

  void _processScannedQr(String value) {
    if (_hasScanned) return;

    if (_currentUserId.isEmpty) {
      _showError('NaNa could not verify your account. Please log in again.');
      return;
    }

    setState(() {
      _hasScanned = true;
      _payloadController.text = value;
    });

    // Pause scanning after the first successful detection.
    _scannerController.stop();

    if (value.toLowerCase().startsWith('nana://pay')) {
      _processNaNaQr(value);
    } else {
      _showInfo(
        'QR detected. Only supported NaNa payment QR codes '
        'can identify a NaNa recipient.',
      );
    }
  }

  void _processNaNaQr(String value) {
    try {
      final uri = Uri.parse(value);
      final userId = uri.queryParameters['user_id'] ?? '';
      final name = uri.queryParameters['name'] ?? '';

      if (userId.isEmpty) {
        _showQrError('This QR code does not contain a valid NaNa account ID.');
        return;
      }

      final parsedUserId = int.tryParse(userId);
      if (parsedUserId == null || parsedUserId <= 0) {
        _showQrError('This QR code contains an invalid NaNa account ID.');
        return;
      }

      if (userId == _currentUserId) {
        setState(() {
          _scannedUserId = '';
          _scannedUserName = '';
          _recipientController.clear();
        });
        _showSelfQrDialog();
        return;
      }

      setState(() {
        _scannedUserId = userId;
        _scannedUserName = name.trim().isEmpty
            ? 'NaNa Wallet user'
            : name.trim();
        _recipientController.text = _scannedUserName;
        _currentStep = _QrPaymentStep.amount;
      });
    } catch (e) {
      debugPrint('QR parsing error: $e');
      _showQrError('This QR code could not be read.');
    }
  }

  // ============================================================
  // PAYMENT
  // ============================================================

  void _selectAmount(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(2);
      _pendingIdempotencyKey = '';
    });
  }

  void _amountChanged(String value) {
    final amount = double.tryParse(value);

    if (amount != null) {
      setState(() {
        _selectedAmount = amount;
        _pendingIdempotencyKey = '';
      });
    }
  }

  Future<void> _submitPayment() async {
    FocusScope.of(context).unfocus();

    if (_token.isEmpty) {
      _showError('Your login session is missing. Please log in again.');
      return;
    }
    if (_scannedUserId.isEmpty || _payloadController.text.trim().isEmpty) {
      _showError('Scan a valid NaNa payment QR first.');
      return;
    }
    if (_scannedUserId == _currentUserId) {
      _showSelfQrDialog();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('Enter a valid payment amount.');
      return;
    }

    final receiverUserId = int.tryParse(_scannedUserId);
    if (receiverUserId == null || receiverUserId <= 0) {
      _showError('The scanned QR does not contain a valid NaNa account ID.');
      return;
    }

    final idempotencyKey = _pendingIdempotencyKey.isEmpty
        ? 'QR-PAY-${DateTime.now().microsecondsSinceEpoch}'
        : _pendingIdempotencyKey;
    _pendingIdempotencyKey = idempotencyKey;

    setState(() => _isProcessing = true);
    try {
      final pinVerified = await Navigator.pushNamed(
        context,
        '/transaction-pin-verify',
        arguments: _token,
      );
      if (!mounted) return;

      if (pinVerified != true) {
        setState(() => _isProcessing = false);
        _showInfo('PIN verification was cancelled. No payment was made.');
        return;
      }

      final result = await WalletService.executeQrWalletTransfer(
        token: _token,
        receiverUserId: receiverUserId,
        amount: amount,
        currency: 'USD',
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) return;

      if (result['status']?.toString().toLowerCase() == 'success') {
        final data = result['data'];
        final reference =
            result['reference_id'] ??
            result['reference'] ??
            (data is Map ? data['reference_id'] ?? data['reference'] : null);
        final fee = double.tryParse(result['fee']?.toString() ?? '');
        final totalDebit = double.tryParse(
          result['total_debit']?.toString() ?? '',
        );
        final baseMessage =
            result['message']?.toString() ??
            'Your wallet transfer was completed successfully.';
        final successMessage = fee != null && totalDebit != null
            ? '$baseMessage\nFee: \$${fee.toStringAsFixed(2)} USD · Total wallet debit: \$${totalDebit.toStringAsFixed(2)} USD.'
            : baseMessage;
        setState(() {
          _currentStep = _QrPaymentStep.success;
          _successReference = reference?.toString() ?? '';
          _successMessage = successMessage;
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
        _showError(
          WalletService.readableErrorMessage(
            result,
            fallback: 'Payment failed. Please try again.',
          ),
        );
      }
    } catch (e) {
      debugPrint('QR payment error: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Unable to complete the payment. Please try again.');
    }
  }

  // ============================================================
  // MESSAGES / DIALOGS
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.royalBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQrError(String message) {
    _showMessageDialog(
      title: 'Invalid QR Code',
      message: message,
      icon: LucideIcons.qrCode,
    );
  }

  void _showSelfQrDialog() {
    _showMessageDialog(
      title: "That's Your QR",
      message:
          "You can't make a payment to your own NaNa Wallet. "
          'Scan another person’s NaNa QR code.',
      icon: LucideIcons.shieldAlert,
    );
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
    required IconData icon,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.adaptiveSurface,
        icon: Icon(icon, color: AppColors.neonPink, size: 34),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.themeText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.themeText.withValues(alpha: 0.72),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('OK', style: TextStyle(color: AppColors.royalBlue)),
          ),
          if (title != "That's Your QR")
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _restartScanner();
              },
              child: Text(
                'SCAN AGAIN',
                style: TextStyle(color: AppColors.neonPink),
              ),
            ),
          if (title == "That's Your QR")
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _restartScanner();
              },
              child: Text(
                'SCAN ANOTHER',
                style: TextStyle(color: AppColors.neonPink),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    final title = switch (_currentStep) {
      _QrPaymentStep.scan => 'QR Payment',
      _QrPaymentStep.amount => 'Enter Amount',
      _QrPaymentStep.success => 'Payment Complete',
    };

    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,
      appBar: AppBar(
        backgroundColor: AppColors.adaptiveSurfaceAlt,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: _currentStep == _QrPaymentStep.scan,
        leading: _currentStep == _QrPaymentStep.scan
            ? null
            : IconButton(
                onPressed: _isProcessing
                    ? null
                    : _currentStep == _QrPaymentStep.success
                    ? _finishSuccess
                    : _restartScanner,
                icon: Icon(LucideIcons.arrowLeft, color: AppColors.themeText),
              ),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.themeText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: _currentStep == _QrPaymentStep.scan
              ? _buildScanStep()
              : _currentStep == _QrPaymentStep.amount
              ? _buildAmountStep()
              : _buildSuccessStep(),
        ),
      ),
    );
  }

  Widget _buildScanStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [_buildHeader(), const SizedBox(height: 20), _buildScanner()],
    );
  }

  Widget _buildAmountStep() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _buildAmountProgress(colors),
        const SizedBox(height: 22),
        _card(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(LucideIcons.userRound, color: AppColors.royalBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scannedUserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verified NaNa recipient · #$_scannedUserId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.58),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.circleCheck,
                color: AppColors.brandMintBright,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'How much would you like to send?',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the amount in USD. A configured P2P service fee may apply; you’ll verify your transaction PIN next.',
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.60),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        _buildAmount(),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.royalBlue, AppColors.brandMintBright],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _submitPayment,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.shieldCheck, size: 19),
              label: Text(
                _isProcessing ? 'VERIFYING & SENDING…' : 'CONTINUE TO PIN',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.themeText,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'No transfer is sent until your PIN is verified.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.52),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountProgress(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'STEP 2 OF 3',
              style: TextStyle(
                color: colors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Text(
              'Amount → PIN → Success',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: const LinearProgressIndicator(
            value: 0.66,
            minHeight: 5,
            color: AppColors.royalBlue,
            backgroundColor: AppColors.glassWhite,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    final colors = Theme.of(context).colorScheme;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: _card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: AppColors.brandMintBright.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.circleCheck,
                  color: AppColors.brandMintBright,
                  size: 46,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Payment successful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _successMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.62),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandMintBright.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.brandMintBright.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '\$${amount.toStringAsFixed(2)} USD',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Sent to $_scannedUserName',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                    if (_successReference.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reference: $_successReference',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.54),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _finishSuccess,
                  icon: const Icon(LucideIcons.check, size: 18),
                  label: const Text('DONE'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.royalBlue,
                    foregroundColor: AppColors.themeText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _restartScanner,
                icon: const Icon(LucideIcons.scanQrCode, size: 17),
                label: const Text('SEND ANOTHER PAYMENT'),
                style: TextButton.styleFrom(foregroundColor: colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finishSuccess() {
    Navigator.pop(context, true);
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.royalBlue, AppColors.neonPink],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(LucideIcons.qrCode, color: AppColors.themeText, size: 25),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan & Pay',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Scan a NaNa QR and pay securely',
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.62),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SCANNER PREVIEW
  // ============================================================

  Widget _buildScanner() {
    final compact = MediaQuery.of(context).size.width < 420;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.scanQrCode,
                  color: AppColors.royalBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan a payment QR',
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Securely scan a NaNa Wallet code',
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.58),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: double.infinity,
              height: compact ? 285 : 320,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  MobileScanner(
                    controller: _scannerController,
                    fit: BoxFit.cover,
                    onDetect: _onQrDetected,
                    errorBuilder: (context, error) {
                      return Container(
                        color: AppColors.adaptiveSurfaceAlt,
                        padding: const EdgeInsets.all(18),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.cameraOff,
                                color: AppColors.neonPink,
                                size: 35,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Camera preview unavailable',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.themeText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                error.errorDetails?.message ??
                                    error.errorCode.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.themeText.withValues(
                                    alpha: 0.62,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _restartScanner,
                                icon: const Icon(
                                  LucideIcons.refreshCw,
                                  size: 16,
                                ),
                                label: const Text('Try camera again'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    placeholderBuilder: (context) => Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        color: AppColors.brandMintBright,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                  const IgnorePointer(
                    child: CustomPaint(painter: _QrFramePainter()),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _cameraRunning
                                  ? AppColors.brandMintBright
                                  : Colors.orangeAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _cameraRunning ? 'CAMERA ACTIVE' : 'CONNECTING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 32, 18, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.66),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Align QR code within the frame',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Scanning starts automatically',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFD9E3E2),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_profileLoading)
                    Container(
                      color: const Color(0xB80F1C20),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.brandMintBright,
                            strokeWidth: 2.5,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Verifying your NaNa account…',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  if (_switchingCamera)
                    Container(
                      color: const Color(0xB80F1C20),
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        color: AppColors.brandMintBright,
                      ),
                    ),
                  if (_hasScanned && !_profileLoading)
                    Container(
                      color: const Color(0xAA0F1C20),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.circleCheck,
                            color: AppColors.brandMintBright,
                            size: 46,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'QR CODE CAPTURED',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_cameraError.isNotEmpty)
                    Container(
                      color: const Color(0xEE0F1C20),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        _cameraError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Icon(
                _cameraRunning ? LucideIcons.camera : LucideIcons.cameraOff,
                color: _cameraRunning
                    ? AppColors.brandMint
                    : AppColors.neonPink,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _cameraRunning ? _cameraLabel() : 'Waiting for camera access',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.70),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_cameraRunning)
                Text(
                  'AUTO SCAN',
                  style: TextStyle(
                    color: AppColors.royalBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleTorch,
                  icon: const Icon(LucideIcons.flashlight, size: 17),
                  label: const Text('Torch'),
                  style: _cameraButtonStyle(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _switchingCamera ? null : _switchCamera,
                  icon: const Icon(LucideIcons.switchCamera, size: 17),
                  label: Text(
                    _cameraFacing == CameraFacing.front
                        ? 'Back camera'
                        : 'Flip camera',
                  ),
                  style: _cameraButtonStyle(),
                ),
              ),
            ],
          ),
          if (_hasScanned) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _restartScanner,
                icon: const Icon(LucideIcons.refreshCw, size: 17),
                label: const Text('SCAN ANOTHER QR'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.royalBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _cameraLabel() {
    switch (_cameraFacing) {
      case CameraFacing.front:
        return 'Front camera active';
      case CameraFacing.back:
        return 'Back camera active';
      case CameraFacing.external:
        return 'External camera active';
      case CameraFacing.unknown:
        return 'Browser camera active';
    }
  }

  ButtonStyle _cameraButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.themeText,
      side: BorderSide(color: AppColors.themeText.withValues(alpha: 0.12)),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }

  // ============================================================
  // RECIPIENT
  // ============================================================

  Widget _buildAmount() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(LucideIcons.dollarSign, 'Payment Amount'),
          SizedBox(height: 14),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _amountChanged,
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            decoration: _inputDecoration(
              hint: '0.00',
              icon: LucideIcons.dollarSign,
              suffix: 'USD',
            ),
            validator: (value) {
              final amount = double.tryParse(value?.trim() ?? '');
              if (amount == null || amount <= 0) {
                return 'Enter a valid payment amount.';
              }
              return null;
            },
          ),
          SizedBox(height: 13),
          Text(
            'Quick Amount',
            style: TextStyle(
              color: AppColors.themeText.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickAmounts.map((amount) {
              final selected = _selectedAmount == amount;

              return GestureDetector(
                onTap: () => _selectAmount(amount),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.royalBlue.withValues(alpha: 0.16)
                        : AppColors.themeText.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppColors.royalBlue
                          : AppColors.themeText.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    '\$${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: selected
                          ? AppColors.royalBlue
                          : AppColors.themeText.withValues(alpha: 0.70),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYLOAD
  // ============================================================

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.themeText.withValues(alpha: 0.055)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.royalBlue, size: 19),
        SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.themeText.withValues(alpha: 0.42),
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: AppColors.royalBlue, size: 19),
      suffixText: suffix,
      suffixStyle: TextStyle(
        color: AppColors.royalBlue,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      filled: true,
      fillColor: AppColors.adaptiveSurfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(
          color: AppColors.themeText.withValues(alpha: 0.06),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(
          color: AppColors.themeText.withValues(alpha: 0.06),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: AppColors.royalBlue, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      errorStyle: TextStyle(fontSize: 10),
    );
  }
}

// ================================================================
// QR CORNER FRAME
// ================================================================

class _QrFramePainter extends CustomPainter {
  const _QrFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = size.width < size.height ? size.width : size.height;
    final frameSide = (shortestSide * 0.74).clamp(180.0, 260.0).toDouble();
    final frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSide,
      height: frameSide,
    );
    final roundedFrame = RRect.fromRectAndRadius(
      frame,
      const Radius.circular(23),
    );

    final shadePath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(roundedFrame);
    canvas.drawPath(
      shadePath,
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );

    canvas.drawRRect(
      roundedFrame,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final cornerPaint = Paint()
      ..color = AppColors.brandMintBright
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cornerLength = frameSide * 0.17;
    final left = frame.left;
    final top = frame.top;
    final right = frame.right;
    final bottom = frame.bottom;

    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - cornerLength, top),
      Offset(right, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom - cornerLength),
      Offset(left, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLength, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - cornerLength, bottom),
      Offset(right, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, bottom - cornerLength),
      Offset(right, bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
