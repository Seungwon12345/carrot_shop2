import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. 내 위치 업데이트
  Future<void> updateMyLocation(String chatRoomId, String myUserId, LatLng position) async {
    try {
      // ▼ [수정] 컬렉션 이름을 'chat_rooms' -> 'chat_start'로 변경
      await _db.collection('chat_start').doc(chatRoomId).set({
        'locations': {
          myUserId: {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        }
      }, SetOptions(merge: true)); // merge: true 덕분에 기존 채팅 데이터(lastMessage 등)는 안 지워짐!
    } catch (e) {
      print('위치 업로드 실패: $e');
    }
  }

  // 2. 상대방 위치 듣기 (스트림)
  Stream<DocumentSnapshot> getChatRoomStream(String chatRoomId) {
    // ▼ [수정] 여기도 'chat_start'로 변경
    return _db.collection('chat_start').doc(chatRoomId).snapshots();
  }
}