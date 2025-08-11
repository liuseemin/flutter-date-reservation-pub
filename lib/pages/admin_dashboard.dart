import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/csv_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Future<void> _handleConfirmPressed() async {
    final confirm = await _showConfirmDialog();
    if (!confirm) return;
    await FirestoreService().batchDeleteRequests(_selectedIds);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('刪除成功！')));
  }

  _exportDataEditor() {
    Navigator.pushNamed(context, '/jsonExport', arguments: _selectedIds);
  }

  _rosterConfigBuilder() {
    Navigator.pushNamed(context, '/rosterBuilder', arguments: _selectedIds);
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: const Text('請確認是否刪除'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('刪除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  bool _isEditMode = false;
  final List<String> _selectedIds = [];

  @override
  Widget build(BuildContext context) {
    final loginPassword = ModalRoute.of(context)!.settings.arguments;

    if (loginPassword != 'password' && !kDebugMode) {
      // set Password secretly
      return Scaffold(
        appBar: AppBar(title: const Text('管理者登入')),
        body: const Center(child: Text('驗證失敗')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('預假回覆總覽'),
        actions: _buildActions(context),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService().streamAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('尚無任何回覆'));
          }

          final docs = snapshot.data!.docs;
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  if (_isEditMode)
                    const DataColumn(
                      label: Text('選擇', overflow: TextOverflow.ellipsis),
                    ),
                  const DataColumn(
                    label: Text('姓名', overflow: TextOverflow.ellipsis),
                  ),
                  const DataColumn(
                    label: Text('職級', overflow: TextOverflow.ellipsis),
                  ),
                  const DataColumn(
                    label: Text('員編', overflow: TextOverflow.ellipsis),
                  ),
                  const DataColumn(
                    label: Text('單位', overflow: TextOverflow.ellipsis),
                  ),
                  const DataColumn(
                    label: Text('日期', overflow: TextOverflow.ellipsis),
                  ),
                  const DataColumn(
                    label: Text('備註', overflow: TextOverflow.ellipsis),
                  ),
                  const DataColumn(
                    label: Text('送出時間', overflow: TextOverflow.ellipsis),
                  ),
                ],
                rows: docs.map((d) {
                  final m = d.data();
                  final dateStrings = (m['dates'] as List)
                      .map((t) {
                        final date = (t as Timestamp).toDate();
                        final month = date.month.toString();
                        final day = date.day.toString();
                        return '$month/$day';
                      })
                      .join(', ');

                  final createdAt = (m['createdAt'] as Timestamp)
                      .toDate()
                      .toIso8601String()
                      .split('T');
                  final createdatStr =
                      '${createdAt[0]} ${createdAt[1].substring(0, 5)}';
                  return DataRow(
                    selected: _isEditMode && _selectedIds.contains(d.id),
                    cells: [
                      if (_isEditMode)
                        DataCell(
                          Checkbox(
                            value: _selectedIds.contains(d.id),
                            onChanged: (bool? value) => setState(
                              () => value == true
                                  ? _selectedIds.add(d.id)
                                  : _selectedIds.remove(d.id),
                            ),
                          ),
                        ),
                      DataCell(
                        Text(m['name'] ?? '', overflow: TextOverflow.ellipsis),
                      ),
                      DataCell(
                        Text(m['rank'] ?? '', overflow: TextOverflow.ellipsis),
                      ),
                      DataCell(
                        Text(
                          m['employeeId'] ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Text(
                          (m['units'] as List).join(','),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Container(
                          width: 300,
                          child: Text(
                            dateStrings,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                      DataCell(Text(m['note'] ?? '')),
                      DataCell(Text(createdatStr)),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    debugPrint('screenWidth: $screenWidth');

    final List<Widget> actions = <Widget>[
      if (_isEditMode)
        ElevatedButton.icon(
          onPressed: _rosterConfigBuilder,
          label: const Text(
            'Config builder',
            style: TextStyle(color: Colors.white),
          ),
          icon: const Icon(Icons.build, color: Colors.white),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
      const SizedBox(width: 8),
      if (_isEditMode)
        ElevatedButton.icon(
          onPressed: _exportDataEditor,
          label: const Text('編輯並匯出', style: TextStyle(color: Colors.white)),
          icon: const Icon(Icons.archive_outlined, color: Colors.white),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      const SizedBox(width: 8),
      if (_isEditMode)
        ElevatedButton.icon(
          onPressed: _handleConfirmPressed,
          label: const Text('批次刪除', style: TextStyle(color: Colors.white)),
          icon: const Icon(Icons.delete, color: Colors.white),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      Switch(
        value: _isEditMode,
        onChanged: (v) => setState(() {
          _isEditMode = v;
        }),
        thumbIcon: WidgetStateProperty.resolveWith<Icon?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return const Icon(Icons.edit);
          }
          return const Icon(Icons.edit_off);
        }),
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: '下載 CSV',
        icon: const Icon(Icons.download),
        onPressed: () async {
          final snap = await FirestoreService().streamAll().first;
          await CsvService().download(snap.docs);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('CSV 下載完成！')));
        },
      ),
    ];

    if (screenWidth >= 600) return actions;

    return [
      if (_isEditMode)
        IconButton(
          onPressed: _rosterConfigBuilder,
          icon: const Icon(Icons.build, color: Colors.white),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
      const SizedBox(width: 8),
      if (_isEditMode)
        IconButton(
          onPressed: _exportDataEditor,
          icon: const Icon(Icons.archive_outlined, color: Colors.white),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      const SizedBox(width: 8),
      if (_isEditMode)
        IconButton(
          onPressed: _handleConfirmPressed,
          icon: const Icon(Icons.delete, color: Colors.white),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      Switch(
        value: _isEditMode,
        onChanged: (v) => setState(() {
          _isEditMode = v;
        }),
        thumbIcon: WidgetStateProperty.resolveWith<Icon?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return const Icon(Icons.edit);
          }
          return const Icon(Icons.edit_off);
        }),
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: '下載 CSV',
        icon: const Icon(Icons.download),
        onPressed: () async {
          final snap = await FirestoreService().streamAll().first;
          await CsvService().download(snap.docs);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('CSV 下載完成！')));
        },
      ),
    ];
  }
}
