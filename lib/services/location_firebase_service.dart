import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 이게 빠져서 빨간줄이 뜬 겁니다.
import 'package:google_maps_flutter/google_maps_flutter.dart'; // 👈 LatLng 때문에 필요합니다.

class LocationFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. 내 위치 업데이트
  Future<void> updateMyLocation(String chatRoomId, String myUserId, LatLng position) async {
    try {
      await _db.collection('chat_start').doc(chatRoomId).set({
        'locations': {
          myUserId: {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        }
      }, SetOptions(merge: true));
    } catch (e) {
      print('위치 업로드 실패: $e');
    }
  }

  // 2. 상대방 위치 듣기 (스트림)
  Stream<DocumentSnapshot> getChatRoomStream(String chatRoomId) {
    return _db.collection('chat_start').doc(chatRoomId).snapshots();
  }
}