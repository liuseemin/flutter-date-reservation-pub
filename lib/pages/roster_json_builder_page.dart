import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web/web.dart' as web;
import 'package:flutter_date_reserve/models/idlist.dart';

class RosterJsonBuilderPage extends StatefulWidget {
  const RosterJsonBuilderPage({super.key});

  @override
  State<RosterJsonBuilderPage> createState() => _RosterJsonBuilderPageState();
}

class _RosterJsonBuilderPageState extends State<RosterJsonBuilderPage> {
  // ===== 基本參數可編輯 =====
  final _startDateCtrl = TextEditingController(text: '2025-06-29');
  final _numDaysCtrl = TextEditingController(text: '33');
  final _extraHolidaysCtrl = TextEditingController(text: '');
  final _areasCtrl = TextEditingController(text: 'A,B,C,D');
  final _deptBlockCtrl = TextEditingController(
    text: '{"PEDS":[0,3],"Trauma":[2,6],"GU":[0,1,2,3,6],"NS":[0]}',
  );

  final Map<String, TextEditingController> _controllerCache = {};
  final Map<String, Timer> _debounceTimers = {};
  // toggle editing mode
  // final Map<String, bool> _editing = {};

  // 利用controller cache 來增加效率
  TextEditingController _getCachedController({
    required Map<String, dynamic> row,
    required String key,
    bool number = false,
    bool isList = false,
  }) {
    final controllerKey = '${_employees.indexOf(row)}:$key';

    if (!_controllerCache.containsKey(controllerKey)) {
      final initial = row[key];
      final controller = TextEditingController(
        text: isList && initial is List
            ? initial.join(',')
            : initial.toString(),
      );

      controller.addListener(() {
        // final value = controller.text;
        _debounceTimers[key]?.cancel();

        _debounceTimers[key] = Timer(const Duration(milliseconds: 300), () {
          _updateFieldCallback(
            row,
            key,
            controller,
            number: number,
            isList: isList,
            info: 'Debouncer',
          );
        });
      });

      _controllerCache[key] = controller;
    }

    return _controllerCache[key]!;
  }

  final Map<String, FocusNode> _FocusNodeCache = {};

  FocusNode _getCachedFocusNode({
    required Map<String, dynamic> row,
    required String key,
    required TextEditingController controller,
    bool number = false,
    bool isList = false,
  }) {
    final focusnodeKey = '${_employees.indexOf(row)}:$key';

    if (!_FocusNodeCache.containsKey(focusnodeKey)) {
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (!focusNode.hasFocus) {
          _debounceTimers[key]?.cancel();
          // final value = _getCachedController(row: row, key: key).text;
          _updateFieldCallback(
            row,
            key,
            controller,
            number: number,
            isList: isList,
            info: 'FocusNode',
          );
        }
      });

      _FocusNodeCache[key] = focusNode;
    }

    return _FocusNodeCache[key]!;
  }

  void _updateFieldCallback(
    Map<String, dynamic> row,
    String key,
    TextEditingController controller, {
    bool number = false,
    bool isList = false,
    String info = '',
  }) {
    final value = controller.text;
    if (isList) {
      // 逗號分隔；依 number 決定回傳 int[] 或 String[]
      final parts = value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      row[key] = number
          ? parts.map((e) => int.tryParse(e)).whereType<int>().toList()
          : parts;
    } else if (number) {
      row[key] = int.tryParse(value) ?? 0;
    } else {
      row[key] = value;
    }
    debugPrint(
      '[$info][${row['id']} ${row['name']}] Updated $key -> $value (${row[key]})',
    );
  }

  // ===== Sort table =====
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // final Set<int> _selectedPrefilledRows = {};
  // 用valueNotifyer
  final Map<int, ValueNotifier<bool>> _selectedPrefilledRowsNotifier = {};
  final ValueNotifier<bool> _anyPrefillSelectedNotifier = ValueNotifier(false);

  // bool _selectedAllPrefilled = false;

  void _setupSelectedPrefilledRowListeners() {
    for (final notifier in _selectedPrefilledRowsNotifier.values) {
      notifier.addListener(_updateAnyPrefillSelected);
    }
  }

  void _updateAnyPrefillSelected() {
    final anySelected = _selectedPrefilledRowsNotifier.values.any(
      (v) => v.value,
    );
    _anyPrefillSelectedNotifier.value = anySelected;
  }

  // ===== 資料列 =====
  final List<Map<String, dynamic>> _employees = [];
  final List<Map<String, dynamic>> _prefilled = [];

  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _init();
  }

  Future<void> _init() async {
    final args = ModalRoute.of(context)!.settings.arguments;
    final ids = args is List<String> ? args : const <String>[];
    if (ids.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('dateReservations')
        .where(FieldPath.documentId, whereIn: ids)
        .get();

    for (final d in snap.docs) {
      final m = d.data();
      final preferDays = (m['dates'] as List<dynamic>)
          .map((t) => (t as Timestamp).toDate().day)
          .toList();

      _employees.add({
        'id': m['employeeId'],
        'name': m['name'],
        'char': '',
        'dept': (m['units'] as List).isNotEmpty ? m['units'][0] : '',
        'rank': m['rank'] ?? '',
        'is_new': false,
        'max_shifts': 8,
        'prefer_days_off': preferDays,
        'area_allow': [],
      });
    }
    setState(() => _loading = false);
  }

  // ===== UI：新增列 =====
  void _addEmptyEmp() {
    setState(() {
      _employees.add({
        'id': '',
        'name': '',
        'char': '',
        'dept': '',
        'rank': '',
        'is_new': false,
        'max_shifts': 8,
        'prefer_days_off': [],
        'area_allow': [],
      });
    });
  }

  void _addEmptyPrefill() {
    setState(() {
      final index = _prefilled.length;
      _prefilled.add({'day': 0, 'area': '', 'employee_id': '', 'name': ''});
      _selectedPrefilledRowsNotifier[index] = ValueNotifier(false);
      _setupSelectedPrefilledRowListeners();
    });
  }

  // ===== 匯出 =====
  void _exportJson() {
    try {
      // 最後保險：flatten [[]] → []
      for (final emp in _employees) {
        for (final k in ['area_allow', 'prefer_days_off']) {
          if (emp[k] is List && emp[k].isNotEmpty && emp[k][0] is List) {
            emp[k] = List.from(emp[k][0]); // flatten
          }
        }
        // 確保 prefer_days_off 是 List<int>
        if (emp['prefer_days_off'] is List) {
          emp['prefer_days_off'] = List<int>.from(
            emp['prefer_days_off'].map((x) => int.tryParse(x.toString()) ?? []),
          );
        }
      }

      // (可選)去除note資料
      // for (final emp in _employees) {
      //   emp.removeWhere((key, value) => key == 'note');
      // }

      final roster = {
        'start_date': _startDateCtrl.text.trim(),
        'num_days': int.tryParse(_numDaysCtrl.text.trim()) ?? 30,
        'extra_holidays': List<int>.from(
          _extraHolidaysCtrl.text
              .split(',')
              .map((s) => int.tryParse(s.trim()) ?? []),
        ),
        'areas': _areasCtrl.text.split(',').map((s) => s.trim()).toList(),
        'dept_block_weekday': jsonDecode(_deptBlockCtrl.text.trim()),
        'employees': _employees,
        'prefilled': _prefilled,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(roster);
      final blob = web.Blob(
        <web.BlobPart>[jsonStr as web.BlobPart].toJS,
        web.BlobPropertyBag(type: 'application/json'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = 'roster_input.json'
        ..style.display = 'none';
      web.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      web.URL.revokeObjectURL(url);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('JSON 產生失敗: $e')));
    }
  }

  // _importEmployeesJson 匯入員工 JSON
  Future<void> _importEmployeesJson() async {
    // 1️⃣  建立 <input type="file" accept=".json">
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = 'application/json,application/JSON,.json';

    // 2️⃣  監聽檔案選擇
    input.onChange.first.then((_) {
      final files = input.files;
      if (files == null || files.length == 0) return;
      final file = files.item(0);

      if (file == null) return;

      // 3️⃣  用 FileReader 讀文字
      final reader = web.FileReader();
      reader.readAsText(file as web.Blob);
      reader.onLoadEnd.first.then((_) {
        final content = reader.result as String;

        try {
          final decoded = jsonDecode(content);

          // 4️⃣  允許匯入「單一 Map」或「List<Map>」
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map) {
                if (item['dates'] == null) {
                  item['dates'] = item['prefer_days_off']
                      .map((d) => d.toString())
                      .join(',');
                }
                _employees.add(Map<String, dynamic>.from(item));
              }
            }
          } else if (decoded is Map) {
            _employees.add(Map<String, dynamic>.from(decoded));
          }

          setState(() {}); // 5️⃣  立即刷新表格
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('匯入完成！')));
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('JSON 格式錯誤')));
        }
      });
    });

    // 6️⃣  觸發瀏覽器檔案挑選對話框
    input.click();
  }

  Future<void> _importConfigJson() async {
    setState(() => _loading = true);

    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = 'application/json,.json';

    // 把 input 加到 DOM 後再 click，確保對話框可彈出
    web.document.body!.append(input);
    input.click();

    debugPrint('等待選擇檔案');
    await input.onChange.first;
    final files = input.files;
    final file = (files == null || files.length == 0) ? null : files.item(0);
    if (file == null) {
      input.remove();
      setState(() => _loading = false); // 關閉讀取畫面
      return;
    }

    // 讀文字
    final reader = web.FileReader()..readAsText(file as web.Blob);
    debugPrint('等待讀取檔案');
    await reader.onLoadEnd.first;
    final content = reader.result as String;
    input.remove(); // 清理隱藏 input
    debugPrint('清理隱藏 input');

    try {
      final Map<String, dynamic> m = jsonDecode(content);

      // ======= 塞回全域欄位 =======

      debugPrint('開始填入欄位');
      _startDateCtrl.text = m['start_date']?.toString() ?? '';
      _numDaysCtrl.text = m['num_days']?.toString() ?? '';
      _areasCtrl.text = (m['areas'] as List?)?.join(',') ?? '';
      _extraHolidaysCtrl.text = (m['extra_holidays'] as List?)?.join(',') ?? '';
      _deptBlockCtrl.text = const JsonEncoder.withIndent(
        '  ',
      ).convert(m['dept_block_weekday'] ?? {});

      // ======= 重新載入 employees / prefilled =======
      debugPrint('載入 employees');
      _employees
        ..clear()
        ..addAll((m['employees'] as List?)?.cast<Map<String, dynamic>>() ?? []);

      // ---- 若舊檔沒有就補成空清單 ----
      for (final emp in _employees) {
        emp.putIfAbsent('is_new', () => false);
        emp.putIfAbsent('area_allow', () => []);
        emp.putIfAbsent('char', () => '');
      }

      debugPrint('載入 prefilled');
      _prefilled
        ..clear()
        ..addAll((m['prefilled'] as List?)?.cast<Map<String, dynamic>>() ?? []);

      for (final notifyer in _selectedPrefilledRowsNotifier.values) {
        notifyer.dispose();
      }
      _selectedPrefilledRowsNotifier.clear();
      for (final prefilled in _prefilled) {
        final index = _prefilled.indexOf(prefilled);
        _selectedPrefilledRowsNotifier[index] = ValueNotifier(false);
      }
      _setupSelectedPrefilledRowListeners();
      setState(() => _loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Roster JSON 匯入完成')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯入失敗：$e')));
    } finally {
      debugPrint('完成');
      setState(() => _loading = false); // 關閉讀取畫面
    }
  }

  void _autoId() {
    for (var i = 0; i < _employees.length; i++) {
      // 如果原本已有 id，則跳過
      final currentId = _employees[i]['id']?.toString().trim();
      if (currentId != null && currentId.isNotEmpty) continue;

      // 否則從 idList 對應 name
      String? id = idList.entries
          .firstWhere(
            (entry) => entry.value == _employees[i]['name'],
            orElse: () => const MapEntry('', ''),
          )
          .key;

      if (id.isNotEmpty) {
        _employees[i]['id'] = id;
      }
    }

    for (var i = 0; i < _prefilled.length; i++) {
      final currentId = _prefilled[i]['employee_id']?.toString().trim();
      if (currentId != null && currentId.isNotEmpty) continue;

      String? id = idList.entries
          .firstWhere(
            (entry) => entry.value == _prefilled[i]['name'],
            orElse: () => const MapEntry('', ''),
          )
          .key;

      if (id.isNotEmpty) {
        _prefilled[i]['employee_id'] = id;
      }
    }

    setState(() {});
  }

  void _autoChar() {
    final Set<String> assignedChars = {}; // To keep track of used characters
    // 先檢查現有的代表字是否有重複，一邊加入assignedChars
    for (var i = 0; i < _employees.length; i++) {
      if (assignedChars.contains(_employees[i]['char'])) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('代表字有重複：${_employees[i]['char']}')),
        );
        return;
      }
      assignedChars.add(_employees[i]['char']?.toString().trim() ?? '');
    }

    // Create a temporary list to store results for proper assignment after calculation
    final Map<int, String> newChars = {};

    for (var i = 0; i < _employees.length; i++) {
      final employee = _employees[i];
      final name = employee['name']?.toString().trim() ?? '';
      if (employee['char']?.toString().trim() != '') {
        newChars[i] = employee['char']?.toString().trim() ?? '';
        continue; // Skip if already assigned
      }
      if (name.isEmpty) {
        newChars[i] = ''; // No name, no char
        continue;
      }
      String? assignedChar;

      // Try finding a unique character from the right (reversed name)
      for (int j = name.length - 1; j >= 0; j--) {
        final char = name[j];
        if (!assignedChars.contains(char)) {
          assignedChar = char;
          assignedChars.add(char);
          break;
        }
      }

      // If no unique char found, keep as full name
      if (assignedChar == null) {
        assignedChar = name;
        break;
      }

      newChars[i] = assignedChar;
    }

    // Update the _employees list with the newly assigned characters
    setState(() {
      newChars.forEach((index, char) {
        _employees[index]['char'] = char;
      });
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('員工代表字自動填入完成')));
  }

  void _importPrefilledFromCsv() async {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = '.csv';

    web.document.body!.append(input);
    input.click();

    await input.onChange.first;
    final file = input.files?.item(0);
    if (file == null) return;

    final reader = web.FileReader();
    reader.readAsText(file);
    await reader.onLoadEnd.first;

    final csvContent = reader.result as String;
    final lines = const LineSplitter().convert(csvContent);
    if (lines.isEmpty) return;

    final header = lines[0].split(',');
    final dayOffset = int.tryParse(header[1]) ?? 0;

    final charToId = {
      for (var e in _employees)
        if ((e['char'] ?? '').toString().isNotEmpty)
          e['char'].toString(): e['id'].toString(),
    };

    final newPrefilled = <Map<String, dynamic>>[];

    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',');
      if (parts.length < 2) continue;
      final area = parts[0];

      for (var d = 1; d < parts.length; d++) {
        final char = parts[d].trim();
        if (char.isEmpty) continue;
        final day = d - 1 + dayOffset;
        final empId = charToId[char];
        if (empId == null) continue;
        final emp = _employees.firstWhere(
          (e) => e['id'] == empId,
          orElse: () => {},
        );

        newPrefilled.add({
          'day': day,
          'area': area,
          'employee_id': empId,
          'name': emp['name'] ?? '',
        });
      }
    }

    setState(() {
      _prefilled.clear();
      _prefilled.addAll(newPrefilled);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV Prefilled 匯入完成')));
  }

  Future<void> _fetchPreferOffDays() async {
    final Set<String> idsToFetch = {};
    for (var i = 0; i < _employees.length; i++) {
      debugPrint(_employees[i]['prefer_days_off'].toString());
      if (_employees[i]['prefer_days_off'].isEmpty) {
        idsToFetch.add(_employees[i]['id']);
      }
    }
    debugPrint('idsToFetch: $idsToFetch, length: ${idsToFetch.length}');
    List<String> idList = idsToFetch.toList();
    List<DocumentSnapshot> results = [];

    for (var i = 0; i < idList.length; i += 30) {
      final batch = idList.sublist(
        i,
        i + 30 < idList.length ? i + 30 : idList.length,
      );
      final snap = await FirebaseFirestore.instance
          .collection('dateReservations')
          .where('employeeId', whereIn: batch)
          .get();
      results.addAll(snap.docs);
    }

    // 讓最新的排在後面
    results.sort(
      (a, b) => (a['createdAt'] as Timestamp).toDate().compareTo(
        (b['createdAt'] as Timestamp).toDate(),
      ),
    );

    // 要在開始排班日之後的預假
    DateTime start = DateTime.parse(_startDateCtrl.text);
    for (final doc_map in results) {
      final employeeId = doc_map['employeeId'];
      final dates = doc_map['dates'] as List<dynamic>;
      // debugPrint('[$employeeId] preferDays: $dates');
      if (dates[0].toDate().isAfter(start)) {
        debugPrint(
          '[$employeeId] preferDays: ${dates.map((t) => (t).toDate()).toList()}',
        );
        final preferDays = dates.map((t) => (t).toDate().day).toList();
        _employees[_employees.indexWhere(
              (e) => e['id'] == employeeId,
            )]['prefer_days_off'] =
            preferDays;
      }
    }

    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('匯入最新預假日完成')));
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _numDaysCtrl.dispose();
    _areasCtrl.dispose();
    _deptBlockCtrl.dispose();
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    for (final controller in _controllerCache.values) {
      controller.dispose();
    }
    for (final notifyer in _selectedPrefilledRowsNotifier.values) {
      notifyer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roster JSON 產生器'),
        actions: [
          IconButton(
            tooltip: '取得最新預假日',
            icon: const Icon(Icons.update),
            onPressed: _fetchPreferOffDays,
          ),
          IconButton(
            tooltip: '匯入 Prefilled CSV',
            icon: const Icon(Icons.file_upload),
            onPressed: _importPrefilledFromCsv,
          ),
          IconButton(
            tooltip: '自動填入員編',
            icon: const Icon(Icons.numbers),
            onPressed: _autoId,
          ),
          IconButton(
            tooltip: '自動填入代表字', // <--- ADD THIS BUTTON
            icon: const Icon(Icons.font_download), // Or another suitable icon
            onPressed: _autoChar,
          ),
          IconButton(
            tooltip: '匯入員工 JSON',
            icon: const Icon(Icons.upload_file),
            onPressed: _importEmployeesJson,
          ),
          IconButton(
            tooltip: '匯入Config JSON',
            icon: const Icon(Icons.settings),
            onPressed: _importConfigJson,
          ),
          IconButton(
            tooltip: '下載 JSON',
            icon: const Icon(Icons.download),
            onPressed: _exportJson,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 全域參數 =====
            _paramField('start_date', _startDateCtrl),
            _paramField(
              'num_days',
              _numDaysCtrl,
              keyboard: TextInputType.number,
            ),
            _paramField('extra_holidays', _extraHolidaysCtrl),
            _paramField('areas (逗號分隔)', _areasCtrl),
            _paramField(
              'dept_block_weekday (JSON)',
              _deptBlockCtrl,
              maxLines: 3,
            ),

            const SizedBox(height: 16),
            Text('員工表', style: Theme.of(context).textTheme.titleMedium),

            _buildEmployeeTable(),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                onPressed: _addEmptyEmp,
                icon: const Icon(Icons.add),
                label: const Text('新增員工列'),
              ),
            ),

            const SizedBox(height: 24),
            Text('Prefill 表', style: Theme.of(context).textTheme.titleMedium),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _addEmptyPrefill,
                    icon: const Icon(Icons.add),
                    label: const Text('新增 Prefill 列'),
                  ),
                  deleteSelectedPrefillButton(),
                ],
              ),
            ),
            _buildPrefillList(),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _addEmptyPrefill,
                    icon: const Icon(Icons.add),
                    label: const Text('新增 Prefill 列'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: deleteSelectedPrefillButton(),
    );
  }

  Widget deleteSelectedPrefillButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _anyPrefillSelectedNotifier,
      builder: (context, anySelected, _) {
        return ElevatedButton.icon(
          onPressed: anySelected
              ? () {
                  setState(() {
                    final selectedIndexes =
                        _selectedPrefilledRowsNotifier.entries
                            .where((entry) => entry.value.value)
                            .map((entry) => entry.key)
                            .toList()
                          ..sort((a, b) => b.compareTo(a));
                    for (final i in selectedIndexes) {
                      _prefilled.removeAt(i);
                      _selectedPrefilledRowsNotifier[i]!.dispose();
                      _selectedPrefilledRowsNotifier.remove(i);
                    }

                    _selectedPrefilledRowsNotifier.clear();
                    for (var j = 0; j < _prefilled.length; j++) {
                      _selectedPrefilledRowsNotifier[j] = ValueNotifier(false);
                    }

                    // 重新設定anyPrefillSelectedListender，並主動一次更新聚合值
                    _setupSelectedPrefilledRowListeners();
                    _updateAnyPrefillSelected();
                  });
                }
              : null,
          icon: const Icon(Icons.remove),
          label: const Text('刪除'),
        );
      },
    );
  }

  // ===== 可編輯參數欄位 =====
  Widget _paramField(
    String label,
    TextEditingController c, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // --- 員工顯示改成 ListView ---
  Widget _buildEmployeeList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _employees.length,
      itemBuilder: (context, i) {
        final row = _employees[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _fixedWidth(_editField(row, 'id', label: 'ID')),
                _fixedWidth(_editField(row, 'name', label: 'Name')),
                _fixedWidth(_editField(row, 'char', label: 'Char')),
                _fixedWidth(_editField(row, 'dept', label: 'Dept')),
                _fixedWidth(_editField(row, 'rank', label: 'Rank')),
                _fixedWidth(
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Is New'),
                    value: row['is_new'] == true,
                    onChanged: (v) => setState(() => row['is_new'] = v!),
                  ),
                ),
                _fixedWidth(
                  _editField(
                    row,
                    'max_shifts',
                    label: 'Max Shifts',
                    number: true,
                  ),
                ),
                _fixedWidth(
                  _editField(
                    row,
                    'area_allow',
                    label: 'Area Allow',
                    isList: true,
                  ),
                ),
                _fixedWidth(
                  _editField(
                    row,
                    'prefer_days_off',
                    label: 'Prefer Days',
                    isList: true,
                    number: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => _employees.removeAt(i)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrefillList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _prefilled.length,
      itemBuilder: (context, i) {
        _selectedPrefilledRowsNotifier.putIfAbsent(
          i,
          () => ValueNotifier(false),
        );
        return ValueListenableBuilder(
          valueListenable: _selectedPrefilledRowsNotifier[i]!,
          builder: (context, selected, child) {
            final row = _prefilled[i];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: selected ? Colors.red.withOpacity(0.1) : null,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        _selectedPrefilledRowsNotifier[i]!.value = !selected;
                      },
                      child: Row(
                        children: [
                          _fixedWidth(
                            _editField(row, 'day', label: 'Day', number: true),
                          ),
                          _fixedWidth(_editField(row, 'area', label: 'Area')),
                          _fixedWidth(
                            _editField(row, 'employee_id', label: 'Emp ID'),
                          ),
                          _fixedWidth(_editField(row, 'name', label: 'Name')),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => setState(() {
                              _prefilled.removeAt(i);
                              _selectedPrefilledRowsNotifier[i]!.dispose();
                              _selectedPrefilledRowsNotifier.remove(i);

                              _selectedPrefilledRowsNotifier.clear();
                              for (var j = 0; j < _prefilled.length; j++) {
                                _selectedPrefilledRowsNotifier[j] =
                                    ValueNotifier(false);
                              }

                              // 重新設定anyPrefillSelectedListender，並主動一次更新聚合值
                              _setupSelectedPrefilledRowListeners();
                              _updateAnyPrefillSelected();
                            }),
                          ),
                          selected
                              ? IconButton(
                                  onPressed: () {
                                    for (var k = 0; k < i; k++) {
                                      _selectedPrefilledRowsNotifier[k]!.value =
                                          !_selectedPrefilledRowsNotifier[k]!
                                              .value;
                                    }
                                  },
                                  icon: const Icon(Icons.arrow_upward),
                                )
                              : Container(),
                          selected
                              ? IconButton(
                                  onPressed: () {
                                    for (
                                      var k = i + 1;
                                      k < _prefilled.length;
                                      k++
                                    ) {
                                      _selectedPrefilledRowsNotifier[k]!.value =
                                          !_selectedPrefilledRowsNotifier[k]!
                                              .value;
                                    }
                                  },
                                  icon: const Icon(Icons.arrow_downward),
                                )
                              : Container(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _editField(
    Map<String, dynamic> row,
    String key, {
    required String label,
    bool number = false,
    bool isList = false,
  }) {
    TextEditingController controller = _getCachedController(
      row: row,
      key: key,
      number: number,
      isList: isList,
    );
    FocusNode focusNode = _getCachedFocusNode(
      row: row,
      key: key,
      controller: controller,
      number: number,
      isList: isList,
    );
    return Padding(
      padding: const EdgeInsets.all(4),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: number ? TextInputType.number : TextInputType.text,
      ),
    );
  }

  Widget _fixedWidth(Widget child, {double width = 150}) {
    return SizedBox(width: width, child: child);
  }

  // ===== 員工 DataTable =====
  Widget _buildEmployeeTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        columns: [
          const DataColumn(label: Text('ID')),
          const DataColumn(label: Text('Name')),
          const DataColumn(label: Text('Char')),
          DataColumn(
            label: const Text('Dept'),
            onSort: (columnIndex, ascending) {
              setState(() {
                _sortColumnIndex = columnIndex;
                _sortAscending = ascending;
                _employees.sort((a, b) {
                  final aVal = a['dept'] ?? '';
                  final bVal = b['dept'] ?? '';
                  return ascending
                      ? aVal.compareTo(bVal)
                      : bVal.compareTo(aVal);
                });
              });
            },
          ),
          DataColumn(
            label: const Text('Rank'),
            onSort: (columnIndex, ascending) {
              setState(() {
                _sortColumnIndex = columnIndex;
                _sortAscending = ascending;
                _employees.sort((a, b) {
                  final aVal = a['rank'] ?? '';
                  final bVal = b['rank'] ?? '';
                  return ascending
                      ? aVal.compareTo(bVal)
                      : bVal.compareTo(aVal);
                });
              });
            },
          ),
          DataColumn(
            label: const Text('Is New'),
            numeric: false,
            onSort: (columnIndex, ascending) {
              setState(() {
                _sortColumnIndex = columnIndex;
                _sortAscending = ascending;
                _employees.sort((a, b) {
                  final aVal = (a['is_new'] ?? false) ? 1 : 0;
                  final bVal = (b['is_new'] ?? false) ? 1 : 0;
                  return ascending ? aVal - bVal : bVal - aVal;
                });
              });
            },
          ),
          const DataColumn(label: Text('Max Shifts')),
          const DataColumn(label: Text('Area Allow')),
          const DataColumn(label: Text('Prefer Days (e.g. 1,5)')),
          const DataColumn(label: Text('刪')),
        ],
        rows: List.generate(_employees.length, (i) {
          final row = _employees[i];
          return DataRow(
            cells: [
              _editCell(row, 'id'),
              _editCell(row, 'name'),
              _editCell(row, 'char'),
              _editCell(row, 'dept'),
              _editCell(row, 'rank'),
              DataCell(
                Checkbox(
                  value: row['is_new'] == true,
                  onChanged: (v) => setState(() => row['is_new'] = v!),
                ),
              ),
              _editCell(row, 'max_shifts', number: true),
              _editCell(
                row,
                'area_allow',
                isList: true, // 逗號分隔字串
              ),
              _editCell(
                row,
                'prefer_days_off',
                isList: true,
                number: true,
              ), // 逗號分隔數字
              DataCell(
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => setState(() => _employees.removeAt(i)),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ===== Prefill DataTable =====
  // Widget _buildPrefillTable() {
  //   return SingleChildScrollView(
  //     scrollDirection: Axis.horizontal,
  //     child: DataTable(
  //       columns: const [
  //         DataColumn(label: Text('Day')),
  //         DataColumn(label: Text('Area')),
  //         DataColumn(label: Text('Employee ID')),
  //         DataColumn(label: Text('Name')),
  //         DataColumn(label: Text('刪')),
  //       ],
  //       rows: List.generate(_prefilled.length, (i) {
  //         final row = _prefilled[i];
  //         return DataRow(
  //           selected: _selectedPrefilledRows.contains(i),
  //           onSelectChanged: (selected) {
  //             setState(() {
  //               if (selected!) {
  //                 _selectedPrefilledRows.add(i);
  //               } else {
  //                 _selectedPrefilledRows.remove(i);
  //               }
  //               _selectedAllPrefilled =
  //                   _selectedPrefilledRows.length == _prefilled.length;
  //             });
  //           },
  //           cells: [
  //             _editCell(row, 'day', number: true),
  //             _editCell(row, 'area'),
  //             _editCell(row, 'employee_id'),
  //             _editCell(row, 'name'),
  //             DataCell(
  //               IconButton(
  //                 icon: const Icon(Icons.delete, size: 18),
  //                 onPressed: () => setState(() => _prefilled.removeAt(i)),
  //               ),
  //             ),
  //           ],
  //         );
  //       }),
  //     ),
  //   );
  // }

  // ===== 通用可編輯 cell =====
  DataCell _editCell(
    Map<String, dynamic> row,
    String key, {
    bool number = false,
    bool isList = false,
    String? hint,
  }) {
    // // 改由 controllerCache 處理
    // final initial = row[key];
    // final controller = TextEditingController(
    //   text: isList && initial is List ? initial.join(',') : initial.toString(),
    // );

    // // initialize editing
    // final editKey = '${row.hashCode}:$key';
    // _editing[editKey] ??= false;
    // if (_editing[editKey]!) {
    TextEditingController controller = _getCachedController(
      row: row,
      key: key,
      number: number,
      isList: isList,
    );
    FocusNode focusNode = _getCachedFocusNode(
      row: row,
      key: key,
      controller: controller,
      number: number,
      isList: isList,
    );
    return DataCell(
      SizedBox(
        width: 140,
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          onEditingComplete: () {
            _updateFieldCallback(
              row,
              key,
              controller,
              number: number,
              isList: isList,
              info: 'onEditingComplete',
            );
            // debugPrint(_employees.indexOf(row).toString());
            // debugPrint('Next focusKey: ${_employees.indexOf(row) + 1}:$key');
            // focusNode.unfocus();
            // focusNode.nextFocus();
            // FocusScope.of(context).requestFocus(
            //   _getCachedFocusNode(
            //     row: _employees[_employees.indexOf(row) + 1],
            //     key: key,
            //     number: number,
            //     isList: isList,
            //   ),
            // );
          },
          // // 改由 controller.addListener 處理
          // onChanged: (v) {
          //   if (isList) {
          //     // 逗號分隔；依 number 決定回傳 int[] 或 String[]
          //     final parts = v
          //         .split(',')
          //         .map((e) => e.trim())
          //         .where((e) => e.isNotEmpty)
          //         .toList();
          //     row[key] = number
          //         ? parts.map((e) => int.tryParse(e)).whereType<int>().toList()
          //         : parts;
          //   } else if (number) {
          //     row[key] = int.tryParse(v) ?? 0;
          //   } else {
          //     row[key] = v;
          //   }
          // },
        ),
      ),
    );
    // } else {
    //   return DataCell(
    //     Text(
    //       isList && row[key] is List ? row[key].join(',') : row[key].toString(),
    //     ),
    //     onTap: () => setState(() => _editing[editKey] = true),
    //   );
    // }
  }
}
