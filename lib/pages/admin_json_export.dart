import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter_date_reserve/models/idlist.dart';

class AdminJsonExportPage extends StatefulWidget {
  const AdminJsonExportPage({super.key});

  @override
  State<AdminJsonExportPage> createState() => _AdminJsonExportPageState();
}

class _AdminJsonExportPageState extends State<AdminJsonExportPage> {
  final List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _init();
  }

  Future<void> _init() async {
    final args = ModalRoute.of(context)!.settings.arguments;

    // ✅ 只在 args 是 List<String> 時才使用
    final ids = args is List<String> ? args : const <String>[];

    if (ids.isEmpty) {
      setState(() {
        _loading = false;
        _addEmptyRow();
      });
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('dateReservations')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    final docs = snap.docs;
    _rows.addAll(
      docs.map((d) {
        final m = d.data();
        final date = (m['dates'] as List<dynamic>)
            .map((t) => (t as Timestamp).toDate().day)
            .toList();
        final dateStr = (m['dates'] as List<dynamic>)
            .map((t) => (t as Timestamp).toDate().day.toString())
            .join(',');
        return {
          'id': m['employeeId'],
          'name': m['name'],
          'dept': (m['units'] as List).isNotEmpty ? m['units'][0] : '',
          'rank': m['rank'] ?? '',
          'is_new': false,
          'max_shifts': 8,
          'prefer_days_off': date,
          'dates': dateStr,
          'note': m['note'] ?? '',
        };
      }),
    );
    setState(() => _loading = false);
  }

  void _addEmptyRow() {
    setState(() {
      _rows.add({
        'id': '',
        'name': '',
        'dept': '',
        'rank': '',
        'is_new': false,
        'max_shifts': 8,
        'prefer_days_off': [],
        'dates': '',
        'note': '',
      });
    });
  }

  void _autoId() {
    for (var i = 0; i < _rows.length; i++) {
      String? id = idList.entries
          .firstWhere(
            (entry) => entry.value == _rows[i]['name'],
            orElse: () => const MapEntry('', ''),
          )
          .key;
      _rows[i]['id'] = id;
    }
    setState(() {});
  }

  Future<void> _importJson() async {
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
                _rows.add(Map<String, dynamic>.from(item));
              }
            }
          } else if (decoded is Map) {
            _rows.add(Map<String, dynamic>.from(decoded));
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

  void _exportJson() {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_rows);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    final blob = web.Blob(
      [bytes] as JSArray<web.BlobPart>,
      web.BlobPropertyBag(type: 'application/json'),
    );

    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = 'date_reservations.json'
      ..style.display = 'none';

    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('JSON 編輯與匯出'),
        actions: [
          IconButton(
            tooltip: '自動填入員編',
            icon: const Icon(Icons.numbers),
            onPressed: _autoId,
          ),
          IconButton(
            tooltip: '匯入JSON',
            icon: const Icon(Icons.add),
            onPressed: _importJson,
          ),
          IconButton(
            tooltip: '下載 JSON',
            icon: const Icon(Icons.download),
            onPressed: _exportJson,
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 900),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('員編')),
                  DataColumn(label: Text('姓名')),
                  DataColumn(label: Text('科別')),
                  DataColumn(label: Text('職級')),
                  DataColumn(label: Text('新生')),
                  DataColumn(label: Text('最大班數')),
                  DataColumn(label: Text('預假')),
                  DataColumn(label: Text('備註')),
                  DataColumn(label: Text('刪')),
                ],
                rows: _rows.isEmpty
                    ? []
                    : List<DataRow>.generate(_rows.length, (index) {
                        final row = _rows[index];
                        return DataRow(
                          key: ValueKey(row['id'] + index.toString()),
                          cells: [
                            _editableCell(row, 'id'),
                            _editableCell(row, 'name'),
                            _editableCell(row, 'dept'),
                            _editableCell(row, 'rank'),
                            DataCell(
                              Checkbox(
                                value: row['is_new'],
                                onChanged: (v) =>
                                    setState(() => row['is_new'] = v!),
                              ),
                            ),
                            _editableCell(row, 'max_shifts'),
                            _editableCell(row, 'dates'),
                            _editableCell(row, 'note'),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                onPressed: () => setState(() {
                                  debugPrint(
                                    '刪除 $index 列: ${_rows[index]['name']}',
                                  );
                                  _rows.removeAt(index);
                                  debugPrint(
                                    '剩下 ${_rows.length - 1} 列: ${_rows.map((r) => r['name']).join(', ')}',
                                  );
                                }),
                              ),
                            ),
                          ],
                        );
                      }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Align(
                alignment: Alignment.center, // ↙ 改成 Alignment.centerRight 可右對齊
                child: ElevatedButton.icon(
                  onPressed: _addEmptyRow,
                  icon: const Icon(Icons.add),
                  label: const Text('新增一列'),
                ),
              ),
            ),
          ],
        ),
      ),

      // ─── 置中或靠右都可以的「新增列」按鈕 ───
    );
  }

  DataCell _editableCell(Map<String, dynamic> row, String key) {
    return DataCell(
      SizedBox(
        width: 150, // 可根據需要調整寬度
        child: TextFormField(
          initialValue: row[key]?.toString() ?? '',
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            border: OutlineInputBorder(), // ✅ 加上 Outline Border
          ),
          onChanged: (v) {
            if (key == 'dates') {
              row['prefer_days_off'] = v
                  .split(',')
                  .map((e) => int.parse(e))
                  .toList();
            }
            row[key] = v;
          },
        ),
      ),
    );
  }
}
