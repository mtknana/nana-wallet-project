import 'package:flutter/material.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';
import '../services/wallet_service.dart';

class ScheduledPaymentScreen extends StatefulWidget {
  final String token;

  ScheduledPaymentScreen({super.key, required this.token});

  @override
  State<ScheduledPaymentScreen> createState() => _ScheduledPaymentScreenState();
}

class _ScheduledPaymentScreenState extends State<ScheduledPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _recipientController = TextEditingController();

  final TextEditingController _amountController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  String _paymentType = 'bill';
  String _currency = 'USD';
  String _recurrence = 'monthly';

  DateTime? _scheduledDate;

  bool _isRecurring = false;
  bool _isLoading = false;

  List<dynamic> _scheduledPayments = [];

  @override
  void initState() {
    super.initState();
    _loadScheduledPayments();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadScheduledPayments() async {
    final result = await WalletService.fetchScheduledPayments(
      token: widget.token,
    );

    if (!mounted) return;

    if (result['status'] == 'success') {
      setState(() {
        _scheduledPayments = result['scheduled_payments'] ?? [];
      });
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: now.add(Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Color(0xFF5B8CFF),
              secondary: Color(0xFFFF4F9A),
              surface: AppColors.adaptiveSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() {
        _scheduledDate = selected;
      });
    }
  }

  Future<void> _createSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_scheduledDate == null) {
      _showMessage('Please select a payment date.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final date =
        '${_scheduledDate!.year.toString().padLeft(4, '0')}-'
        '${_scheduledDate!.month.toString().padLeft(2, '0')}-'
        '${_scheduledDate!.day.toString().padLeft(2, '0')}';

    final result = await WalletService.createScheduledPayment(
      token: widget.token,
      paymentType: _paymentType,
      recipient: _recipientController.text.trim(),
      amount: double.parse(_amountController.text),
      currency: _currency,
      scheduledDate: date,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isRecurring: _isRecurring,
      recurrencePeriod: _isRecurring ? _recurrence : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['status'] == 'success') {
      _clearForm();
      await _loadScheduledPayments();

      if (!mounted) return;

      _showSuccessDialog(
        result['reference_id'] ??
            result['scheduled_payment']?['reference_id'] ??
            'Scheduled',
      );
    } else {
      _showMessage(result['message'] ?? 'Failed to schedule payment.');
    }
  }

  void _clearForm() {
    _recipientController.clear();
    _amountController.clear();
    _descriptionController.clear();

    setState(() {
      _scheduledDate = null;
      _isRecurring = false;
      _paymentType = 'bill';
      _currency = 'USD';
      _recurrence = 'monthly';
    });
  }

  Future<void> _cancelPayment(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          title: Text(
            'Cancel Scheduled Payment',
            style: TextStyle(color: AppColors.themeText),
          ),
          content: Text(
            'Are you sure you want to cancel this scheduled payment?',
            style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.70)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('NO'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('CANCEL'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final result = await WalletService.cancelScheduledPayment(
      token: widget.token,
      id: id,
    );

    if (!mounted) return;

    if (result['status'] == 'success') {
      _showMessage('Scheduled payment cancelled.');

      await _loadScheduledPayments();
    } else {
      _showMessage(result['message'] ?? 'Unable to cancel payment.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccessDialog(String reference) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF5B8CFF), size: 30),
              SizedBox(width: 10),
              Text('Payment Scheduled', style: TextStyle(color: AppColors.themeText)),
            ],
          ),
          content: Text(
            'Your payment has been scheduled successfully.\n\nReference:\n$reference',
            style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.70), height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('DONE'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';

    final value = date.toString();

    if (value.length >= 10) {
      final parts = value.substring(0, 10).split('-');

      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    }

    return value;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.greenAccent;
      case 'cancelled':
        return Colors.redAccent;
      case 'failed':
        return Colors.red;
      case 'processing':
        return Colors.orangeAccent;
      default:
        return Color(0xFF5B8CFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Scheduled Payment',
          style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadScheduledPayments,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),

              SizedBox(height: 24),

              _buildScheduleForm(),

              SizedBox(height: 30),

              _buildUpcomingSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [AppColors.adaptiveSurface, AppColors.adaptiveSurface],
        ),
        border: Border.all(color: Color(0xFF5B8CFF).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Color(0xFF5B8CFF).withOpacity(0.15),
            ),
            child: Icon(
              Icons.event_repeat,
              color: Color(0xFF5B8CFF),
              size: 30,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan your payments',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Schedule bills, transfers and top-ups for later.',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.60),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.adaptiveSurfaceAlt,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Schedule',
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 20),

            _label('Payment Type'),

            _dropdown(
              value: _paymentType,
              items:  [
                DropdownMenuItem(value: 'bill', child: Text('Bill Payment')),
                DropdownMenuItem(
                  value: 'mobile_topup',
                  child: Text('Mobile Top-Up'),
                ),
                DropdownMenuItem(
                  value: 'merchant',
                  child: Text('Merchant Payment'),
                ),
                DropdownMenuItem(
                  value: 'transfer',
                  child: Text('Money Transfer'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _paymentType = value;
                  });
                }
              },
            ),

            SizedBox(height: 16),

            _label('Recipient'),

            _textField(
              controller: _recipientController,
              hint: 'Enter recipient',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Recipient is required';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            _label('Amount'),

            Row(
              children: [
                Expanded(
                  child: _textField(
                    controller: _amountController,
                    hint: '0.00',
                    icon: Icons.attach_money,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');

                      if (amount == null || amount <= 0) {
                        return 'Invalid amount';
                      }

                      return null;
                    },
                  ),
                ),
                SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: _dropdown(
                    value: _currency,
                    items:  [
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'KHR', child: Text('KHR')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _currency = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            _label('Payment Date'),

            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveSurfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Color(0xFF5B8CFF)),
                    SizedBox(width: 12),
                    Text(
                      _scheduledDate == null
                          ? 'Select payment date'
                          : _formatDate(_scheduledDate.toString()),
                      style: TextStyle(
                        color: _scheduledDate == null
                            ? AppColors.themeText.withValues(alpha: 0.38)
                            : AppColors.themeText,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            _label('Description'),

            _textField(
              controller: _descriptionController,
              hint: 'Optional note',
              icon: Icons.notes_outlined,
              maxLines: 2,
            ),

            SizedBox(height: 10),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Recurring payment',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Automatically repeat this schedule',
                style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 12),
              ),
              value: _isRecurring,
              activeColor: Color(0xFF5B8CFF),
              onChanged: (value) {
                setState(() {
                  _isRecurring = value;
                });
              },
            ),

            if (_isRecurring) ...[
              SizedBox(height: 8),
              _label('Repeat'),

              _dropdown(
                value: _recurrence,
                items:  [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _recurrence = value;
                    });
                  }
                },
              ),
            ],

            SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5B8CFF),
                  foregroundColor: AppColors.themeText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.themeText,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.schedule_send),
                          SizedBox(width: 9),
                          Text(
                            'Schedule Payment',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Scheduled Payments',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: 14),

        if (_scheduledPayments.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.adaptiveSurfaceAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                'No scheduled payments yet.',
                style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38)),
              ),
            ),
          )
        else
          ..._scheduledPayments.map((payment) => _buildPaymentCard(payment)),
      ],
    );
  }

  Widget _buildPaymentCard(dynamic payment) {
    final status = payment['status']?.toString() ?? 'scheduled';

    final amount = payment['amount']?.toString() ?? '0';

    final currency = payment['currency']?.toString() ?? 'USD';

    final id = payment['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.themeText.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Color(0xFF5B8CFF).withOpacity(0.12),
            ),
            child: Icon(Icons.schedule, color: Color(0xFF5B8CFF)),
          ),

          SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['recipient']?.toString() ?? 'Payment',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  '${payment['payment_type']} • ${_formatDate(payment['scheduled_date'])}',
                  style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 12),
                ),

                SizedBox(height: 6),

                Text(
                  '$currency $amount',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: _statusColor(status),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (status == 'scheduled') ...[
                SizedBox(height: 8),
                InkWell(
                  onTap: () => _cancelPayment(id),
                  child: Icon(
                    Icons.close,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.themeText.withValues(alpha: 0.70),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(color: AppColors.themeText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.30)),
        prefixIcon: Icon(icon, color: Color(0xFF5B8CFF)),
        filled: true,
        fillColor: AppColors.adaptiveSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        errorStyle: TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppColors.adaptiveSurface,
      style: TextStyle(color: AppColors.themeText),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.adaptiveSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
