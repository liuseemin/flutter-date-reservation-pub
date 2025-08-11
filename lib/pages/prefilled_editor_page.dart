import 'package:flutter/material.dart';

// [TODO]
// Not complete yet
// Performance issue

class PrefilledEditorPage extends StatefulWidget {
  const PrefilledEditorPage({super.key});

  @override
  State<PrefilledEditorPage> createState() => _PrefilledEditorPageState();
}

class _PrefilledEditorPageState extends State<PrefilledEditorPage> {
  late DateTime startDate;
  late int numDays;
  late List<String> areas;
  late List<Map<String, dynamic>> employees;
  late List<Map<String, dynamic>> localPrefilled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('傳入參數錯誤')));
      Navigator.pop(context);
      return;
    }

    try {
      startDate = DateTime.tryParse(args['start_date'] ?? '') ?? DateTime.now();
      numDays = args['num_days'] ?? 30;
      areas = (args['areas'] as List).cast<String>();
      employees = (args['employees'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      localPrefilled = (args['prefilled'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('初始化失敗：$e')));
      Navigator.pop(context);
    }
  }

  String? _getCharForId(String id) {
    final emp = employees.firstWhere((e) => e['id'] == id, orElse: () => {});
    return emp['char']?.toString();
  }

  Map<String, dynamic>? _getPrefillData(int day, String area) {
    try {
      return localPrefilled.firstWhere(
        (e) => e['day'] == day && e['area'] == area,
      );
    } catch (e) {
      return null;
    }
  }

  void _swapPrefill(int day1, String area1, int day2, String area2) {
    final prefill1 = _getPrefillData(day1, area1);
    final prefill2 = _getPrefillData(day2, area2);

    setState(() {
      localPrefilled.removeWhere(
        (e) =>
            (e['day'] == day1 && e['area'] == area1) ||
            (e['day'] == day2 && e['area'] == area2),
      );

      if (prefill1 != null && prefill1.isNotEmpty) {
        localPrefilled.add({
          'day': day2,
          'area': area2,
          'employee_id': prefill1['employee_id'],
          'name': prefill1['name'],
        });
      }

      if (prefill2 != null && prefill2.isNotEmpty) {
        localPrefilled.add({
          'day': day1,
          'area': area1,
          'employee_id': prefill2['employee_id'],
          'name': prefill2['name'],
        });
      }
    });
  }

  void _assignEmployeeToCell(
    int day,
    String area,
    Map<String, dynamic> employee,
  ) {
    setState(() {
      localPrefilled.removeWhere((e) => e['day'] == day && e['area'] == area);
      localPrefilled.add({
        'day': day,
        'area': area,
        'employee_id': employee['id'],
        'name': employee['name'],
      });
    });
  }

  void _removeEmployeeFromCell(int day, String area) {
    setState(() {
      localPrefilled.removeWhere((e) => e['day'] == day && e['area'] == area);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shownDays = List.generate(numDays, (i) => i);
    // 固定儲存格的寬度，您可以根據實際內容調整此值
    const double cellWidth = 60.0; // 例如，設定為60像素寬

    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯 Prefilled 班表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              Navigator.pop(context, localPrefilled);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        // 保持水平滾動，因為可能有超過螢幕寬度的天數
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 0, // 移除欄位間距，讓寬度更容易控制
          columns: [
            // 第一個欄位，可以給予固定寬度或依照內容決定
            DataColumn(
              label: Container(
                width: 40, // 給區域欄位一個固定寬度
                alignment: Alignment.centerLeft,
                child: const Text('區域'),
              ),
            ),
            for (final day in shownDays)
              DataColumn(
                label: Container(
                  width: cellWidth, // 固定天數欄位的寬度
                  alignment: Alignment.center,
                  child: Text('$day'),
                ),
              ),
          ],
          rows: areas.map((area) {
            return DataRow(
              cells: [
                DataCell(
                  Container(
                    width: 40, // 與欄位標題寬度一致
                    alignment: Alignment.centerLeft,
                    child: Text(area),
                  ),
                ),
                ...shownDays.map((day) {
                  final matched = _getPrefillData(day, area);
                  final char = _getCharForId(matched?['employee_id'] ?? '');

                  final cellInner = Container(
                    height: 40,
                    width: cellWidth, // 固定儲存格的寬度
                    alignment: Alignment.center,
                    color: Colors.grey.shade200,
                    child: Text(
                      char ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );

                  return DataCell(
                    DragTarget<Map<String, dynamic>>(
                      builder: (context, candidate, rejected) {
                        if (char != null && char.isNotEmpty) {
                          return Draggable<Map<String, dynamic>>(
                            data: {
                              'day': day,
                              'area': area,
                              'employee_id': matched!['employee_id'],
                              'name': matched['name'],
                              'char': char,
                            },
                            feedback: Material(
                              elevation: 4.0,
                              child: Container(
                                height: 40,
                                width: cellWidth, // 反饋也使用固定寬度
                                alignment: Alignment.center,
                                color: Colors.blue.withOpacity(0.7),
                                child: Text(
                                  char,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Container(
                              height: 40,
                              width: cellWidth, // 拖曳時也使用固定寬度
                              alignment: Alignment.center,
                              color: Colors.grey.shade300,
                              child: const Text(''),
                            ),
                            child: GestureDetector(
                              onTap: () => _showEmployeePicker(day, area),
                              child: cellInner,
                            ),
                          );
                        } else {
                          return GestureDetector(
                            onTap: () => _showEmployeePicker(day, area),
                            child: cellInner,
                          );
                        }
                      },
                      onAccept: (dragData) {
                        if (dragData.containsKey('employee_id')) {
                          _swapPrefill(
                            dragData['day'],
                            dragData['area'],
                            day,
                            area,
                          );
                        }
                      },
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEmployeePicker(int day, String area) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return ListView(
          shrinkWrap: true,
          children:
              employees.map((emp) {
                return ListTile(
                  title: Text('${emp['char']} ${emp['name']}'),
                  onTap: () {
                    Navigator.pop(context);
                    _assignEmployeeToCell(day, area, emp);
                  },
                );
              }).toList()..add(
                ListTile(
                  title: const Text('移除排班'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeEmployeeFromCell(day, area);
                  },
                ),
              ),
        );
      },
    );
  }
}
