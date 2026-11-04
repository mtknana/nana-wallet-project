import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class SavingsGoalScreen extends StatefulWidget {
  final String activeToken;

  SavingsGoalScreen({super.key, required this.activeToken});

  @override
  State<SavingsGoalScreen> createState() => _SavingsGoalScreenState();
}

class _SavingsGoalScreenState extends State<SavingsGoalScreen> {
  static const String _baseUrl = ApiConfig.baseUrl;

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _goals = [];

  Map<String, dynamic> _summary = {};

  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Active', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _loadSavingsGoals();
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.activeToken}',
  };

  Future<void> _loadSavingsGoals() async {
    if (widget.activeToken.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

      _showMessage(
        'Authentication token is missing. Please login again.',
        isError: true,
      );

      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final query = _selectedFilter == 'All'
          ? ''
          : '?status=${_selectedFilter.toLowerCase()}';

      final response = await http.get(
        Uri.parse('$_baseUrl/savings-goals$query'),
        headers: _headers,
      );

      final summaryResponse = await http.get(
        Uri.parse('$_baseUrl/savings-goals/summary'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List<dynamic> rawGoals = data['goals'] ?? [];

        _goals = rawGoals
            .map((goal) => Map<String, dynamic>.from(goal))
            .toList();
      } else {
        throw Exception(_extractError(response));
      }

      if (summaryResponse.statusCode == 200) {
        final summaryData = jsonDecode(summaryResponse.body);

        _summary = Map<String, dynamic>.from(summaryData['summary'] ?? {});
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Unable to load savings goals.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _createGoal() async {
    final result = await _showGoalForm();

    if (result == null) {
      return;
    }

    await _submitCreateGoal(result);
  }

  Future<void> _submitCreateGoal(Map<String, dynamic> data) async {
    setState(() {
      _saving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/savings-goals'),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        _showMessage('Savings goal created successfully.');

        await _loadSavingsGoals();
      } else {
        _showMessage(_extractError(response), isError: true);
      }
    } catch (_) {
      _showMessage('Unable to create savings goal.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editGoal(Map<String, dynamic> goal) async {
    final result = await _showGoalForm(goal: goal);

    if (result == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/savings-goals/${goal['id']}'),
        headers: _headers,
        body: jsonEncode(result),
      );

      if (response.statusCode == 200) {
        _showMessage('Savings goal updated successfully.');

        await _loadSavingsGoals();
      } else {
        _showMessage(_extractError(response), isError: true);
      }
    } catch (_) {
      _showMessage('Unable to update savings goal.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _addContribution(Map<String, dynamic> goal) async {
    final controller = TextEditingController();

    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ContributionSheet(
          controller: controller,
          currency: goal['currency'] ?? 'USD',
        );
      },
    );

    controller.dispose();

    if (amount == null || amount <= 0) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/savings-goals/${goal['id']}/contribute'),
        headers: _headers,
        body: jsonEncode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final updatedGoal = Map<String, dynamic>.from(data['goal'] ?? {});

        final completed = updatedGoal['status'] == 'completed';

        _showMessage(
          completed
              ? '🎉 Savings goal completed!'
              : 'Contribution added successfully.',
        );

        await _loadSavingsGoals();
      } else {
        _showMessage(_extractError(response), isError: true);
      }
    } catch (_) {
      _showMessage('Unable to add contribution.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteGoal(Map<String, dynamic> goal) async {
    final confirmed = await _showConfirmation(
      title: 'Delete Savings Goal?',
      message: 'This will permanently remove "${goal['name']}".',
      confirmText: 'Delete',
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/savings-goals/${goal['id']}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        _showMessage('Savings goal deleted.');

        await _loadSavingsGoals();
      } else {
        _showMessage(_extractError(response), isError: true);
      }
    } catch (_) {
      _showMessage('Unable to delete savings goal.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _cancelGoal(Map<String, dynamic> goal) async {
    final confirmed = await _showConfirmation(
      title: 'Cancel Savings Goal?',
      message: 'The goal will remain visible but will no longer be active.',
      confirmText: 'Cancel Goal',
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/savings-goals/${goal['id']}/cancel'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        _showMessage('Savings goal cancelled.');

        await _loadSavingsGoals();
      } else {
        _showMessage(_extractError(response), isError: true);
      }
    } catch (_) {
      _showMessage('Unable to cancel savings goal.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _showGoalForm({
    Map<String, dynamic>? goal,
  }) async {
    final isEditing = goal != null;

    final nameController = TextEditingController(
      text: goal?['name']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: goal?['description']?.toString() ?? '',
    );

    final targetController = TextEditingController(
      text: goal?['target_amount']?.toString() ?? '',
    );

    final currentController = TextEditingController(
      text: goal?['current_amount']?.toString() ?? '0',
    );

    String currency = goal?['currency']?.toString() ?? 'USD';

    DateTime? targetDate;

    if (goal?['target_date'] != null &&
        goal!['target_date'].toString().isNotEmpty) {
      targetDate = DateTime.tryParse(goal['target_date'].toString());
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.adaptiveSurface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.themeText.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      Text(
                        isEditing ? 'Edit Savings Goal' : 'Create Savings Goal',
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        isEditing
                            ? 'Update your savings target.'
                            : 'Set a target and track your progress.',
                        style: TextStyle(
                          color: Color(0xFFB7C4C8),
                          fontSize: 13,
                        ),
                      ),

                      SizedBox(height: 22),

                      _input(
                        controller: nameController,
                        label: 'Goal Name',
                        hint: 'e.g. New Laptop',
                        icon: Icons.flag_outlined,
                      ),

                      SizedBox(height: 14),

                      _input(
                        controller: descriptionController,
                        label: 'Description',
                        hint: 'Optional description',
                        icon: Icons.notes_outlined,
                        maxLines: 2,
                      ),

                      SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: _input(
                              controller: targetController,
                              label: 'Target Amount',
                              hint: '1000',
                              icon: Icons.track_changes,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),

                          SizedBox(width: 12),

                          Expanded(
                            child: _input(
                              controller: currentController,
                              label: 'Already Saved',
                              hint: '0',
                              icon: Icons.savings_outlined,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 14),

                      Text(
                        'Currency',
                        style: TextStyle(
                          color: Color(0xFFD7E0E3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.adaptiveSurfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.themeText.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _currencyButton('USD', currency, () {
                                setSheetState(() {
                                  currency = 'USD';
                                });
                              }),
                            ),
                            Expanded(
                              child: _currencyButton('KHR', currency, () {
                                setSheetState(() {
                                  currency = 'KHR';
                                });
                              }),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      Text(
                        'Target Date',
                        style: TextStyle(
                          color: Color(0xFFD7E0E3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      SizedBox(height: 8),

                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: targetDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              Duration(days: 3650),
                            ),
                          );

                          if (selected != null) {
                            setSheetState(() {
                              targetDate = selected;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.adaptiveSurfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.themeText.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                color: Color(0xFFB7C4C8),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  targetDate == null
                                      ? 'Choose target date'
                                      : _formatDate(targetDate!),
                                  style: TextStyle(
                                    color: AppColors.themeText,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: Color(0xFFB7C4C8),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameController.text.trim();

                            final target = double.tryParse(
                              targetController.text.trim(),
                            );

                            final current = double.tryParse(
                              currentController.text.trim(),
                            );

                            if (name.isEmpty) {
                              _showMessage(
                                'Please enter a goal name.',
                                isError: true,
                              );

                              return;
                            }

                            if (target == null || target <= 0) {
                              _showMessage(
                                'Please enter a valid target amount.',
                                isError: true,
                              );

                              return;
                            }

                            if (current == null || current < 0) {
                              _showMessage(
                                'Please enter a valid saved amount.',
                                isError: true,
                              );

                              return;
                            }

                            Navigator.pop(context, {
                              'name': name,
                              'description':
                                  descriptionController.text.trim().isEmpty
                                  ? null
                                  : descriptionController.text.trim(),
                              'target_amount': target,
                              'current_amount': current,
                              'currency': currency,
                              'target_date': targetDate == null
                                  ? null
                                  : _dateForApi(targetDate!),
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.royalBlue,
                            foregroundColor: AppColors.themeText,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isEditing ? 'Save Changes' : 'Create Goal',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    targetController.dispose();
    currentController.dispose();

    return result;
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: AppColors.themeText),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Color(0xFFB7C4C8)),
        hintStyle: TextStyle(color: Color(0xFF607277)),
        prefixIcon: Icon(icon, color: Color(0xFFB7C4C8)),
        filled: true,
        fillColor: AppColors.adaptiveSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.themeText.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.royalBlue.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _currencyButton(String value, String selected, VoidCallback onTap) {
    final active = value == selected;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.royalBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              color: active ? AppColors.themeText : Color(0xFFB7C4C8),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final total = _summary['total_goals'] ?? 0;

    final active = _summary['active_goals'] ?? 0;

    final completed = _summary['completed_goals'] ?? 0;

    final usd = Map<String, dynamic>.from(_summary['usd'] ?? {});

    final khr = Map<String, dynamic>.from(_summary['khr'] ?? {});

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.royalBlue.withValues(alpha: 0.28),
            AppColors.adaptiveSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.themeText.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.savings_outlined, color: AppColors.themeText),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Savings Overview',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 18),

          Row(
            children: [
              Expanded(child: _summaryItem('Goals', '$total')),
              Expanded(child: _summaryItem('Active', '$active')),
              Expanded(child: _summaryItem('Completed', '$completed')),
            ],
          ),

          SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _moneySummary(
                  'USD',
                  usd['saved_amount'],
                  usd['target_amount'],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _moneySummary(
                  'KHR',
                  khr['saved_amount'],
                  khr['target_amount'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(color: Color(0xFFB7C4C8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _moneySummary(String currency, dynamic saved, dynamic target) {
    final savedAmount = (saved as num?)?.toDouble() ?? 0;

    final targetAmount = (target as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currency,
            style: TextStyle(
              color: Color(0xFFB7C4C8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 5),
          Text(
            _formatMoney(savedAmount, currency),
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'of ${_formatMoney(targetAmount, currency)}',
            style: TextStyle(color: Color(0xFF7E9095), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final target = (goal['target_amount'] as num?)?.toDouble() ?? 0;

    final current = (goal['current_amount'] as num?)?.toDouble() ?? 0;

    final remaining =
        (goal['remaining_amount'] as num?)?.toDouble() ??
        maxDouble(0, target - current);

    final progress = (goal['progress_percentage'] as num?)?.toDouble() ?? 0;

    final currency = goal['currency']?.toString() ?? 'USD';

    final status = goal['status']?.toString() ?? 'active';

    final completed = status == 'completed';

    final cancelled = status == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: completed
              ? Colors.green.withValues(alpha: 0.35)
              : AppColors.themeText.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: completed
                      ? Colors.green.withValues(alpha: 0.16)
                      : AppColors.royalBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  completed
                      ? Icons.check_circle_outline
                      : Icons.savings_outlined,
                  color: completed ? Colors.greenAccent : AppColors.themeText,
                ),
              ),

              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal['name']?.toString() ?? 'Savings Goal',
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    if (goal['description'] != null &&
                        goal['description'].toString().isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        goal['description'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF8EA0A5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              _statusBadge(status),
            ],
          ),

          SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatMoney(current, currency),
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'of ${_formatMoney(target, currency)}',
                style: TextStyle(color: Color(0xFFB7C4C8), fontSize: 12),
              ),
            ],
          ),

          SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (progress / 100).clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: AppColors.themeText.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                completed ? Colors.greenAccent : AppColors.royalBlue,
              ),
            ),
          ),

          SizedBox(height: 9),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.toStringAsFixed(1)}% completed',
                style: TextStyle(
                  color: completed
                      ? Colors.greenAccent
                      : Color(0xFFD7E0E3),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!completed && !cancelled)
                Text(
                  '${_formatMoney(remaining, currency)} remaining',
                  style: TextStyle(
                    color: Color(0xFF8EA0A5),
                    fontSize: 11,
                  ),
                ),
            ],
          ),

          if (goal['target_date'] != null &&
              goal['target_date'].toString().isNotEmpty) ...[
            SizedBox(height: 13),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Color(0xFF8EA0A5),
                ),
                SizedBox(width: 6),
                Text(
                  'Target: ${_formatApiDate(goal['target_date'].toString())}',
                  style: TextStyle(
                    color: Color(0xFF8EA0A5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],

          if (!cancelled) ...[
            SizedBox(height: 16),

            Row(
              children: [
                if (!completed)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _addContribution(goal),
                      icon: Icon(Icons.add, size: 17),
                      label: Text('Save'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.themeText,
                        side: BorderSide(
                          color: AppColors.royalBlue.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),

                if (!completed) SizedBox(width: 8),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _editGoal(goal),
                    icon: Icon(Icons.edit_outlined, size: 16),
                    label: Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFFB7C4C8),
                      side: BorderSide(
                        color: AppColors.themeText.withValues(alpha: 0.08),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 8),

                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: Color(0xFFB7C4C8)),
                  color: AppColors.adaptiveSurface,
                  onSelected: (value) {
                    if (value == 'cancel') {
                      _cancelGoal(goal);
                    }

                    if (value == 'delete') {
                      _deleteGoal(goal);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!completed)
                      PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              color: Colors.orange,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Cancel Goal',
                              style: TextStyle(color: AppColors.themeText),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Goal',
                            style: TextStyle(color: AppColors.themeText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;

    switch (status) {
      case 'completed':
        color = Colors.greenAccent;
        break;
      case 'cancelled':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.orangeAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFilter() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (_, index) {
          final filter = _filters[index];

          final selected = filter == _selectedFilter;

          return GestureDetector(
            onTap: () {
              if (_selectedFilter == filter) {
                return;
              }

              setState(() {
                _selectedFilter = filter;
              });

              _loadSavingsGoals();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? AppColors.royalBlue : AppColors.adaptiveSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.royalBlue
                      : AppColors.themeText.withValues(alpha: 0.06),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? AppColors.themeText : Color(0xFFB7C4C8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.themeText.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.savings_outlined,
              color: AppColors.themeText,
              size: 32,
            ),
          ),

          SizedBox(height: 16),

          Text(
            'No Savings Goals Yet',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: 7),

          Text(
            'Create your first goal and start tracking your progress.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8EA0A5),
              fontSize: 13,
              height: 1.4,
            ),
          ),

          SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: _createGoal,
            icon: Icon(Icons.add, size: 18),
            label: Text('Create Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalBlue,
              foregroundColor: AppColors.themeText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmation({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          title: Text(
            title,
            style: TextStyle(
              color: AppColors.themeText,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(color: Color(0xFFB7C4C8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep',
                style: TextStyle(color: Color(0xFFB7C4C8)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                confirmText,
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : AppColors.adaptiveSurface,
      ),
    );
  }

  String _extractError(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      if (data['message'] != null) {
        return data['message'].toString();
      }

      if (data['errors'] is Map) {
        final errors = data['errors'] as Map;

        if (errors.isNotEmpty) {
          final first = errors.values.first;

          if (first is List && first.isNotEmpty) {
            return first.first.toString();
          }
        }
      }
    } catch (_) {}

    return 'Something went wrong. Please try again.';
  }

  String _formatMoney(double amount, String currency) {
    if (currency == 'KHR') {
      return '៛${amount.toStringAsFixed(0)}';
    }

    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatApiDate(String value) {
    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return value;
    }

    return _formatDate(parsed);
  }

  String _dateForApi(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  double maxDouble(double a, double b) {
    return a > b ? a : b;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,

      appBar: AppBar(
        backgroundColor: AppColors.adaptiveSurfaceAlt,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.themeText),
        title: Text(
          'Savings Goals',
          style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadSavingsGoals,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _createGoal,
        backgroundColor: AppColors.royalBlue,
        foregroundColor: AppColors.themeText,
        icon: Icon(Icons.add),
        label: Text(
          'New Goal',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSavingsGoals,
              color: AppColors.royalBlue,
              child: ListView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _buildSummary(),

                  SizedBox(height: 18),

                  _buildFilter(),

                  SizedBox(height: 18),

                  if (_goals.isEmpty)
                    _buildEmptyState()
                  else
                    ..._goals.map(_buildGoalCard),
                ],
              ),
            ),
    );
  }
}

class _ContributionSheet extends StatelessWidget {
  final TextEditingController controller;
  final String currency;

  _ContributionSheet({required this.controller, required this.currency});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.adaptiveSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.themeText.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            SizedBox(height: 20),

            Text(
              'Add Savings',
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),

            SizedBox(height: 6),

            Text(
              'Add an amount to your savings progress. '
              'Your wallet balance will not be changed.',
              style: TextStyle(
                color: Color(0xFF8EA0A5),
                fontSize: 12,
                height: 1.4,
              ),
            ),

            SizedBox(height: 20),

            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                prefixText: currency == 'KHR' ? '៛ ' : '\$ ',
                prefixStyle: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                hintText: '0.00',
                hintStyle: TextStyle(color: Color(0xFF607277)),
                filled: true,
                fillColor: AppColors.adaptiveSurfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(controller.text.trim());

                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid amount.'),
                      ),
                    );

                    return;
                  }

                  Navigator.pop(context, amount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.royalBlue,
                  foregroundColor: AppColors.themeText,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  'Add to Goal',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
