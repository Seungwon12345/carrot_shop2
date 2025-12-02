// lib/models/chat_room_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  // ✅ Firestore 문서 ID와 동일한 채팅방 고유 ID
  final String chatId;
  final String itemId; // 관련 상품 ID

  // ⭐️ 채팅방에 참여하는 두 사용자 ID를 역할(판매자/구매자)로 명시
  final String sellerId;
  final String buyerId;

  // 채팅 목록 화면에 표시될 최근 정보
  final String lastMessageText;
  final String lastMessageSenderId;
  final Timestamp updatedAt; // 최근 메시지 전송 시간 (정렬 기준)

  ChatRoom({
    required this.chatId,
    required this.itemId,
    required this.sellerId,
    required this.buyerId,
    required this.lastMessageText,
    required this.lastMessageSenderId,
    required this.updatedAt,
  });

  // 1. Firestore 문서(Map)에서 ChatRoom 객체로 변환하는 팩토리 생성자
  factory ChatRoom.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("ChatRoom data is null");
    }

    // DB의 chatId는 문서 ID를 사용합니다.
    final String docId = snapshot.id;

    return ChatRoom(
      // ✅ 문서 ID를 chatId 필드에 할당
      chatId: docId,
      itemId: data['itemId'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      buyerId: data['buyerId'] as String? ?? '',
      // 💡 lastMessage 필드명이 DB에서 'lastMessage'가 아니라면 수정이 필요합니다.
      lastMessageText: data['lastMessage'] as String? ?? '대화 시작',
      lastMessageSenderId: data['lastMessageSenderId'] as String? ?? '',
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  // 2. ChatRoom 객체를 Firestore 문서(Map)로 변환하는 메서드
  Map<String, dynamic> toFirestore() {
    // chatId는 문서 ID로 자동 관리되므로 Map에는 포함하지 않습니다.
    return {
      "itemId": itemId,
      "sellerId": sellerId,
      "buyerId": buyerId,
      "lastMessage": lastMessageText,
      "lastMessageSenderId": lastMessageSenderId,
      "updatedAt": updatedAt,
      "createdAt": Timestamp.now(), // 초기 생성 시점에만 사용
    };
  }

  // ⭐️ [필수 추가] ChatService에서 Firestore가 자동 생성한 ID를 할당할 때 사용
  ChatRoom copyWith({
    String? chatId,
    String? itemId,
    String? sellerId,
    String? buyerId,
    String? lastMessageText,
    String? lastMessageSenderId,
    Timestamp? updatedAt,
  }) {
    return ChatRoom(
      chatId: chatId ?? this.chatId,
      itemId: itemId ?? this.itemId,
      sellerId: sellerId ?? this.sellerId,
      buyerId: buyerId ?? this.buyerId,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}