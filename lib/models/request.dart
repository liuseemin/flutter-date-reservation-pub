import 'package:cloud_firestore/cloud_firestore.dart';

/// Date‑Reservation 資料模型
///
/// - [id]：Firestore documentId，可為 null（尚未寫入時用）
/// - [dates]：已轉成 DateTime 方便 UI 直接使用
/// - `fromDoc` / `toMap`：Firestore 映射用
/// - 若日後要加欄位（ex. 狀態 status, approver），只需在此集中維護

class DateReservationRequest {
  final String? id;
  final String name;
  final String rank;
  final String employeeId;
  final String unit; // 單選→直接 string
  final List<DateTime> dates;
  final String note;
  final DateTime createdAt;

  DateReservationRequest({
    this.id,
    required this.name,
    required this.rank,
    required this.employeeId,
    required this.unit,
    required this.dates,
    required this.note,
    required this.createdAt,
  });

  /// Factory：Firestore DocumentSnapshot → Model
  factory DateReservationRequest.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data();
    return DateReservationRequest(
      id: doc.id,
      name: m['name'] ?? '',
      rank: m['rank'] ?? '',
      employeeId: m['employeeId'] ?? '',
      unit: (m['units'] as List).isNotEmpty ? m['units'][0] : '',
      dates: (m['dates'] as List)
          .map<DateTime>((t) => (t as Timestamp).toDate())
          .toList(),
      note: m['note'] ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// 將 Model 轉回 Map，方便 FirestoreService 寫入
  Map<String, dynamic> toMap() => {
    'name': name,
    'rank': rank,
    'employeeId': employeeId,
    'units': [unit], // 仍以陣列儲存以保相容
    'dates': dates.map(Timestamp.fromDate).toList(),
    'note': note,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
