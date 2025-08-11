import 'package:cloud_firestore/cloud_firestore.dart';

/// 封裝所有與 Cloud Firestore 互動的邏輯。
///
/// 目前提供：
///   • addRequest(...)   新增一筆日期預約
///   • streamAll()       監聽整個 collection（依建立時間倒序）
///
/// 如需擴充（update / delete / query by employeeId 等）
/// 可依照相同寫法再加方法。

class FirestoreService {
  /// Collection 名稱統一集中定義，方便日後改動
  static const _collectionName = 'dateReservations';

  /// 快速取得 collection reference
  final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection(_collectionName);

  /// 新增一筆預約資料
  Future<void> addRequest({
    required String name,
    required String rank,
    required String employeeId,
    required List<String> units,
    required List<DateTime> dates,
    required String note,
  }) async {
    await _col.add({
      'name': name,
      'rank': rank,
      'employeeId': employeeId,
      'units': units,
      'dates': dates.map(Timestamp.fromDate).toList(),
      'datesStr': dates.map((d) => d.day.toString()).toList(),
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRequest(String id) => _col.doc(id).delete();

  Future<void> batchDeleteRequests(List<String> ids) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var id in ids) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();
  }

  /// 回傳 collection 的 snapshot stream（依 createdAt 倒序）
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAll() =>
      _col.orderBy('createdAt', descending: true).snapshots();
}
