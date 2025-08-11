import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:web/web.dart' as web; // 新版瀏覽器 API
import 'package:js/js_util.dart'; // 提供 jsify()

class CsvService {
  /// 下載 Firestore 查詢結果為 CSV（web 平台）
  Future<void> download(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    // === 1. 欄位表頭（可自行調整順序） ================================
    const headers = [
      'name',
      'rank',
      'employeeId',
      'unit',
      'dates',
      'note',
      'createdAt',
    ];

    // === 2. 將每一筆文件轉為 List<String> ===========================
    final rows = docs.map<List<String>>((d) {
      final m = d.data();

      // 日期陣列轉 'yyyy-MM-dd|yyyy-MM-dd…'
      final dateStr = (m['dates'] as List<dynamic>)
          .map((t) => (t as Timestamp).toDate().day.toString())
          .join(',');

      // 建立時間 same 格式
      final createdAt = (m['createdAt'] as Timestamp?)
          ?.toDate()
          .toIso8601String()
          .split('T')
          .first;

      return [
        m['name'] ?? '',
        m['rank'] ?? '',
        m['employeeId'] ?? '',
        (m['units'] as List<dynamic>).isNotEmpty
            ? m['units'][0].toString()
            : '',
        dateStr,
        m['note'] ?? '',
        createdAt ?? '',
      ];
    }).toList();

    // === 3. 產生 CSV 字串 ===========================================
    final csvString = const ListToCsvConverter().convert(<List<String>>[
      headers,
      ...rows,
    ]);

    // === 4. 轉成 Blob → 觸發下載（避免 dart:html deprecated） ========
    final bytes = utf8.encode(csvString);

    // jsify() 把 Dart List 轉為 JS Array<BlobPart>
    final blob = web.Blob(jsify(<Uint8List>[Uint8List.fromList(bytes)]));
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = 'date_reservations.csv'
      ..style.display = 'none';

    web.document.body!.appendChild(anchor);
    anchor.click(); // 觸發下載
    anchor.remove();
    web.URL.revokeObjectURL(url); // 釋放資源
  }
}
