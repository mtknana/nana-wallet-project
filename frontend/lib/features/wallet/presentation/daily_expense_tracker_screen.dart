import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class DailyExpenseTrackerScreen extends StatefulWidget {
  final String activeToken;

  DailyExpenseTrackerScreen({super.key, required this.activeToken});

  @override
  State<DailyExpenseTrackerScreen> createState() =>
      _DailyExpenseTrackerScreenState();
}

class _DailyExpenseTrackerScreenState extends State<DailyExpenseTrackerScreen> {
  static const String baseUrl = ApiConfig.baseUrl;

  bool _isLoading = true;
  bool _isSaving = false;

  List<dynamic> _expenses = [];

  double _totalUsd = 0;
  double _totalKhr = 0;

  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.activeToken}',
  };

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/expenses'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final data = decoded['data'];

        final List<dynamic> expenses = data is Map && data['data'] is List
            ? data['data']
            : data is List
            ? data
            : [];

        setState(() {
          _expenses = expenses;
        });

        await _loadSummary();
      } else {
        _showMessage('Unable to load expenses.', isError: true);
      }
    } catch (e) {
      _showMessage('Could not connect to the server.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSummary() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/expenses/summary'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'];

        setState(() {
          _totalUsd = double.tryParse('${data['total_usd'] ?? 0}') ?? 0;

          _totalKhr = double.tryParse('${data['total_khr'] ?? 0}') ?? 0;
        });
      }
    } catch (_) {
      // Summary failure should not prevent the expense list from loading.
    }
  }

  Future<void> _addExpense() async {
    final category = ValueNotifier<String>('food');
    final currency = ValueNotifier<String>('USD');

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    DateTime selectedDate = DateTime.now();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: AppColors.adaptiveSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Color(0xFF607177),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    SizedBox(height: 22),

                    Text(
                      'Add Expense',
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 6),

                    Text(
                      'Track your daily spending',
                      style: TextStyle(color: Color(0xFFB7C4C8), fontSize: 14),
                    ),

                    SizedBox(height: 24),

                    Text(
                      'Category',
                      style: TextStyle(
                        color: Color(0xFFD7E0E3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 8),

                    ValueListenableBuilder<String>(
                      valueListenable: category,
                      builder: (context, value, _) {
                        return DropdownButtonFormField<String>(
                          value: value,
                          dropdownColor: AppColors.adaptiveSurface,
                          style: TextStyle(color: AppColors.themeText),
                          decoration: _inputDecoration(
                            'Select category',
                            Icons.category_outlined,
                          ),
                          items:  [
                            DropdownMenuItem(
                              value: 'food',
                              child: Text('🍔 Food'),
                            ),
                            DropdownMenuItem(
                              value: 'transport',
                              child: Text('🚌 Transport'),
                            ),
                            DropdownMenuItem(
                              value: 'study',
                              child: Text('📚 Study Costs'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('🧾 Other'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              category.value = value;
                              setModalState(() {});
                            }
                          },
                        );
                      },
                    ),

                    SizedBox(height: 18),

                    Text(
                      'Amount',
                      style: TextStyle(
                        color: Color(0xFFD7E0E3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: TextStyle(
                              color: AppColors.themeText,
                              fontSize: 17,
                            ),
                            decoration: _inputDecoration(
                              '0.00',
                              Icons.attach_money,
                            ),
                          ),
                        ),

                        SizedBox(width: 10),

                        ValueListenableBuilder<String>(
                          valueListenable: currency,
                          builder: (context, value, _) {
                            return Container(
                              decoration: BoxDecoration(
                                color: AppColors.adaptiveSurfaceAlt,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.royalBlue.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: value,
                                  dropdownColor: AppColors.adaptiveSurface,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  style: TextStyle(
                                    color: AppColors.themeText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  items:  [
                                    DropdownMenuItem(
                                      value: 'USD',
                                      child: Text('USD'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'KHR',
                                      child: Text('KHR'),
                                    ),
                                  ],
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      currency.value = newValue;
                                      setModalState(() {});
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: 18),

                    Text(
                      'Description',
                      style: TextStyle(
                        color: Color(0xFFD7E0E3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 8),

                    TextField(
                      controller: descriptionController,
                      maxLength: 255,
                      style: TextStyle(color: AppColors.themeText),
                      decoration: _inputDecoration(
                        'e.g. Lunch, bus fare, books',
                        Icons.notes_outlined,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Expense Date',
                      style: TextStyle(
                        color: Color(0xFFD7E0E3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 8),

                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: AppColors.royalBlue,
                                  surface: AppColors.adaptiveSurface,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (picked != null) {
                          setModalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.adaptiveSurfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Color(
                              0xFF607177,
                            ).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              color: AppColors.royalBlue,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(
                              _formatDate(selectedDate),
                              style: TextStyle(
                                color: AppColors.themeText,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final amount = double.tryParse(
                                  amountController.text.trim(),
                                );

                                if (amount == null || amount <= 0) {
                                  _showMessage(
                                    'Please enter a valid amount.',
                                    isError: true,
                                  );
                                  return;
                                }

                                setState(() {
                                  _isSaving = true;
                                });

                                final success = await _createExpense(
                                  category: category.value,
                                  amount: amount,
                                  currency: currency.value,
                                  description: descriptionController.text
                                      .trim(),
                                  date: selectedDate,
                                );

                                if (mounted) {
                                  setState(() {
                                    _isSaving = false;
                                  });
                                }

                                if (success && context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.royalBlue,
                          foregroundColor: AppColors.themeText,
                          disabledBackgroundColor: AppColors.royalBlue
                              .withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.themeText,
                                ),
                              )
                            : Text(
                                'Save Expense',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    category.dispose();
    currency.dispose();
    amountController.dispose();
    descriptionController.dispose();

    if (result == true) {
      await _loadExpenses();
    }
  }

  Future<bool> _createExpense({
    required String category,
    required double amount,
    required String currency,
    required String description,
    required DateTime date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/expenses'),
        headers: _headers,
        body: jsonEncode({
          'category': category,
          'amount': amount,
          'currency': currency,
          'description': description.isEmpty ? null : description,
          'expense_date':
              '${date.year.toString().padLeft(4, '0')}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}',
        }),
      );

      if (response.statusCode == 201) {
        _showMessage('Expense added successfully.');
        return true;
      }

      try {
        final decoded = jsonDecode(response.body);

        final errors = decoded['errors'];

        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;

          if (firstError is List && firstError.isNotEmpty) {
            _showMessage(firstError.first.toString(), isError: true);
            return false;
          }
        }

        _showMessage(
          decoded['message']?.toString() ?? 'Unable to add expense.',
          isError: true,
        );
      } catch (_) {
        _showMessage('Unable to add expense.', isError: true);
      }

      return false;
    } catch (_) {
      _showMessage('Could not connect to the server.', isError: true);

      return false;
    }
  }

  Future<void> _deleteExpense(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          title: Text(
            'Delete Expense?',
            style: TextStyle(color: AppColors.themeText),
          ),
          content: Text(
            'This expense will be permanently removed.',
            style: TextStyle(color: Color(0xFFD7E0E3)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/expenses/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        _showMessage('Expense deleted.');
        await _loadExpenses();
      } else {
        _showMessage('Unable to delete expense.', isError: true);
      }
    } catch (_) {
      _showMessage('Could not connect to the server.', isError: true);
    }
  }

  List<dynamic> get _filteredExpenses {
    if (_selectedFilter == 'All') {
      return _expenses;
    }

    return _expenses.where((expense) {
      final category = expense['category']?.toString().toLowerCase();

      return category == _selectedFilter.toLowerCase();
    }).toList();
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'food':
        return 'Food';
      case 'transport':
        return 'Transport';
      case 'study':
        return 'Study Costs';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'transport':
        return Icons.directions_bus_outlined;
      case 'study':
        return Icons.menu_book_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return '-';
    }

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  String _formatAmount(dynamic value) {
    final amount = double.tryParse(value.toString()) ?? 0;

    return amount.toStringAsFixed(2);
  }

  String _currencySymbol(String currency) {
    return currency == 'KHR' ? '៛' : '\$';
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Color(0xFF7E8C91)),
      prefixIcon: Icon(icon, color: AppColors.royalBlue),
      filled: true,
      fillColor: AppColors.adaptiveSurfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Color(0xFF607177).withValues(alpha: 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.royalBlue),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppColors.royalBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.royalBlue.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppColors.royalBlue),
              SizedBox(width: 10),
              Text(
                'Expense Summary',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _summaryAmount(
                  label: 'USD',
                  amount: '\$${_totalUsd.toStringAsFixed(2)}',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _summaryAmount(
                  label: 'KHR',
                  amount: '៛${_totalKhr.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryAmount({required String label, required String amount}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Color(0xFFB7C4C8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 5),
          Text(
            amount,
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = ['All', 'Food', 'Transport', 'Study', 'Other'];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == filter;

          return ChoiceChip(
            label: Text(filter),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _selectedFilter = filter;
              });
            },
            selectedColor: AppColors.royalBlue,
            backgroundColor: AppColors.adaptiveSurface,
            labelStyle: TextStyle(
              color: selected ? AppColors.themeText : Color(0xFFD7E0E3),
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: selected
                  ? AppColors.royalBlue
                  : Color(0xFF607177).withValues(alpha: 0.35),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpenseCard(dynamic expense) {
    final category = expense['category']?.toString() ?? 'other';

    final currency = expense['currency']?.toString() ?? 'USD';

    final amount = expense['amount'];

    final description = expense['description']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color(0xFF607177).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_categoryIcon(category), color: AppColors.royalBlue),
          ),

          SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _categoryLabel(category),
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  description?.isNotEmpty == true
                      ? description!
                      : _formatDate(expense['expense_date']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFB7C4C8),
                    fontSize: 12,
                  ),
                ),

                if (description?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      _formatDate(expense['expense_date']),
                      style: TextStyle(
                        color: Color(0xFF7E8C91),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_currencySymbol(currency)}'
                '${_formatAmount(amount)}',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 5),

              InkWell(
                onTap: () {
                  final id = int.tryParse(expense['id'].toString());

                  if (id != null) {
                    _deleteExpense(id);
                  }
                },
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,

      appBar: AppBar(
        backgroundColor: AppColors.adaptiveSurfaceAlt,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Daily Expenses',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadExpenses,
            icon: Icon(Icons.refresh_rounded, color: AppColors.themeText),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        backgroundColor: AppColors.royalBlue,
        foregroundColor: AppColors.themeText,
        icon: Icon(Icons.add),
        label: Text(
          'Add Expense',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _loadExpenses,
        color: AppColors.royalBlue,
        backgroundColor: AppColors.adaptiveSurface,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.royalBlue),
              )
            : ListView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                children: [
                  _buildSummaryCard(),

                  SizedBox(height: 22),

                  Text(
                    'Categories',
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 10),

                  _buildFilterChips(),

                  SizedBox(height: 22),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Expenses',
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_filteredExpenses.length} records',
                        style: TextStyle(
                          color: Color(0xFFB7C4C8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  if (_filteredExpenses.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 50,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.adaptiveSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            color: Color(0xFF607177),
                            size: 48,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'No expenses yet',
                            style: TextStyle(
                              color: AppColors.themeText,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tap "Add Expense" to start tracking your daily spending.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFB7C4C8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._filteredExpenses.map(_buildExpenseCard),
                ],
              ),
      ),
    );
  }
}
