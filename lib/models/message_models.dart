import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderId;
  final String text; // 텍스트 메시지 내용, 또는 장소 메시지의 경우 주소
  final Timestamp timestamp;
  final bool isRead;

  // ⭐️ [추가]: 메시지 타입 (text, location 등)
  final String type;
  // ⭐️ [추가]: 장소 메시지를 위한 위치 정보 (nullable)
  final double? locationLat;
  final double? locationLng;

  Message({
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.type = 'text', // ⭐️ 기본값은 'text'
    this.locationLat,
    this.locationLng,
  });

  // Firestore 문서(Map)에서 Message 객체로 변환하는 팩토리 생성자
  factory Message.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("Message data is null");
    }
    return Message(
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] as Timestamp,
      isRead: data['isRead'] ?? false,

      // ⭐️ [추가]: 새로운 필드 로딩
      type: data['type'] ?? 'text',
      locationLat: data['locationLat'] as double?,
      locationLng: data['locationLng'] as double?,
    );
  }

  // Message 객체를 Firestore 문서(Map)로 변환하는 메서드
  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> firestoreData = {
      "senderId": senderId,
      "text": text,
      "timestamp": timestamp,
      "isRead": isRead,

      // ⭐️ [추가]: 새로운 필드 저장
      "type": type,
      "locationLat": locationLat,
      "locationLng": locationLng,
    };

    // null 값은 저장하지 않도록 정리 (Firestore는 null 필드를 저장할 수 있음)
    // Map.removeWhere((key, value) => value == null); 로직을 사용할 수도 있지만,
    // 명시적으로 null을 포함하여 저장합니다. (FirestoreService.sendMessage에서 제어할 수도 있습니다)

    return firestoreData;
  }
}