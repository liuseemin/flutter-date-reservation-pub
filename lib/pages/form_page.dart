import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // for Timestamp in dialog
import '../services/firestore_service.dart';
// import '../models/request.dart';          // 若你還沒加 model，可以先刪掉並改用 Map

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _empIdCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late final DateTime _nextMonthFirst;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _nextMonthFirst = DateTime(today.year, today.month + 1, 1);
  }

  /// ======== 下拉選單資料 ========
  final List<String> _unitOptions = [
    'GS',
    'CRS',
    'PEDS',
    'CS',
    'PS',
    'NS',
    'GU',
    'Trauma',
    'SICU',
    'CVS',
    'other',
  ];
  String? _selectedUnit;

  final List<String> _rankOptions = [
    'RANK 1',
    'RANK 2',
    'RANK 3',
    'RANK 4',
    'RANK 5',
  ];
  String? _selectedRank;

  /// 多日選取
  final List<DateTime?> _selectedDates = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _empIdCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String? _notEmpty(String? v) => (v == null || v.trim().isEmpty) ? '必填' : null;

  /// ======== 建立確認 Dialog ========
  Future<bool> _showConfirmDialog() async {
    final dateStr = _selectedDates
        .map((d) => d!.toIso8601String().split('T').first)
        .join(', ');

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('請確認下列內容'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('姓名：${_nameCtrl.text}'),
                Text('職級：$_selectedRank'),
                Text('員編：${_empIdCtrl.text}'),
                Text('下月科別：$_selectedUnit'),
                Text('預假日期：$dateStr'),
                Text('特殊需求：${_noteCtrl.text.isEmpty ? '（無）' : _noteCtrl.text}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('返回'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('確認送出'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Date reservation form'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/adminLogin');
            },
            icon: const Icon(Icons.lock),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                RichText(
                  text: TextSpan(
                    text: 'Due date for reservation\n',
                    style: Theme.of(context).textTheme.titleMedium,
                    children: [
                      TextSpan(
                        text: '逾期將視為無預約',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: _notEmpty,
                ),
                const SizedBox(height: 12),

                /// ======== 職級下拉 ========
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Rank'),
                  items: _rankOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  value: _selectedRank,
                  onChanged: (v) => setState(() => _selectedRank = v),
                  validator: (v) => v == null ? '必選' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _empIdCtrl,
                  decoration: const InputDecoration(labelText: 'ID'),
                  validator: _notEmpty,
                ),
                const SizedBox(height: 24),

                /// ======== 單位下拉 ========
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: '預假月份在哪一科？'),
                  items: _unitOptions
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  value: _selectedUnit,
                  onChanged: (v) => setState(() => _selectedUnit = v),
                  validator: (v) => v == null ? '必選' : null,
                ),
                const SizedBox(height: 24),

                Text(
                  'Date Reservation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '⚠️ 注意請選對月份',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                CalendarDatePicker2(
                  config: CalendarDatePicker2Config(
                    calendarType: CalendarDatePicker2Type.multi,
                    controlsTextStyle: Theme.of(context).textTheme.bodyLarge,
                    firstDate: _nextMonthFirst,
                    lastDate: _nextMonthFirst.add(const Duration(days: 182)),
                    selectableDayPredicate: (d) => !d.isBefore(_nextMonthFirst),
                  ),
                  value: _selectedDates,
                  onValueChanged: (dates) => setState(
                    () => _selectedDates
                      ..clear()
                      ..addAll(dates),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Special Request',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('送出'),
                  onPressed: _handleSubmitPressed,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Visibility(
        visible: false,
        child: FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/adminLogin');
          },
          tooltip: '管理者登入',
          child: const Icon(Icons.lock),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
    );
  }

  Future<void> _handleSubmitPressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDates.isEmpty) {
      _showSnack('請至少選一個日期');
      return;
    }

    // 確認 Dialog
    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    // ======== 寫入 Firestore ========
    await FirestoreService().addRequest(
      name: _nameCtrl.text.trim(),
      rank: _selectedRank!,
      employeeId: _empIdCtrl.text.trim(),
      units: [_selectedUnit!],
      dates: _selectedDates.cast<DateTime>(),
      note: _noteCtrl.text.trim(),
    );

    final filteredDates = _selectedDates.whereType<DateTime>().toList();
    // 建立 model 用於下一頁顯示（若不用 model 可改傳 Map）
    final request = {
      'name': _nameCtrl.text.trim(),
      'rank': _selectedRank!,
      'employeeId': _empIdCtrl.text.trim(),
      'unit': _selectedUnit!,
      'dates': filteredDates,
      'note': _noteCtrl.text.trim(),
      'createdAt': DateTime.now(),
    };

    // 清空表單
    _formKey.currentState!.reset();
    setState(() {
      _selectedRank = null;
      _selectedUnit = null;
      _selectedDates.clear();
    });

    // 導向新頁面
    if (context.mounted) {
      Navigator.pushNamed(context, '/submitted', arguments: request);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
