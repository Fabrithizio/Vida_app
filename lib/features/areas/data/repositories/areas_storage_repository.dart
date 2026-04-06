import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AreasStorageRepository {
  static const String boxPrefix = 'areas_box_';

  String uidOrAnon() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = (user?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  Future<Box<dynamic>> open() async {
    final uid = uidOrAnon();
    return Hive.openBox<dynamic>('$boxPrefix$uid');
  }

  String itemKey(String areaId, String itemId) => '$areaId::$itemId';

  String areaUpdatedPrefKey(String uid, String areaId) =>
      '$uid:area_updated:$areaId';
}
