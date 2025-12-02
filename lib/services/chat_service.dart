// lib/services/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_models.dart';
import '../models/chat_room_models.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _chatRoomsCollection = 'chat_start';
  static const String _messagesCollection = 'messages';

  static const int _batchSize = 500;

  // ----------------------------------------------------
  // 1. 채팅방 생성 또는 조회 (유지)
  // ----------------------------------------------------
  Future<ChatRoom> getOrCreateChatRoom({
    required String currentUserId,
    required String opponentUserId,
    required String itemId,
  }) async {
    final String sellerId = opponentUserId;
    final String buyerId = currentUserId;

    final chatCollection = _firestore.collection(_chatRoomsCollection);

    try {
      final querySnapshot = await chatCollection
          .where('itemId', isEqualTo: itemId)
          .where('sellerId', isEqualTo: sellerId)
          .where('buyerId', isEqualTo: buyerId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        if (kDebugMode) {
          print('✅ 기존 채팅방 조회 성공: ${doc.id}');
        }
        return ChatRoom.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null);
      } else {
        final now = Timestamp.now();
        final newChatRoomData = ChatRoom(
          chatId: '',
          sellerId: sellerId,
          buyerId: buyerId,
          itemId: itemId,
          updatedAt: now,
          lastMessageSenderId: '',
          lastMessageText: '채팅 시작',
        );

        final newDocRef = await chatCollection.add(newChatRoomData.toFirestore());
        final createdChatRoom = newChatRoomData.copyWith(chatId: newDocRef.id);

        if (kDebugMode) {
          print('✅ 새로운 채팅방 생성 성공: ${newDocRef.id}');
        }

        return createdChatRoom;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 채팅방 조회/생성 실패: $e');
      }
      rethrow;
    }
  }


  // ----------------------------------------------------
  // 2. 메시지 전송 및 채팅방 정보 업데이트 (⭐️ [수정])
  // ----------------------------------------------------
  /// 텍스트 메시지 또는 장소 메시지를 전송합니다.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String content, // 텍스트 메시지의 경우 내용, 장소 메시지의 경우 주소
    String type = 'text', // ⭐️ [추가] 메시지 타입 (기본값 'text')
    double? locationLat,  // ⭐️ [추가] 장소 메시지 위도
    double? locationLng,  // ⭐️ [추가] 장소 메시지 경도
  }) async {
    if (content.trim().isEmpty) return;
    if (type == 'location' && (locationLat == null || locationLng == null)) {
      if (kDebugMode) {
        print('⚠️ 장소 메시지 전송 실패: 위치 정보가 누락되었습니다.');
      }
      return;
    }

    final Timestamp timestamp = Timestamp.now();

    // ⭐️ [수정]: Message 모델에 type 및 위치 정보 전달
    final newMessage = Message(
      senderId: senderId,
      text: content,
      timestamp: timestamp,
      type: type,
      locationLat: locationLat,
      locationLng: locationLng,
    );

    // ⭐️ [수정]: 채팅방 목록에 표시될 마지막 메시지 텍스트 결정
    String lastMessageText;
    if (type == 'location') {
      lastMessageText = '📍 장소 공유';
    } else {
      lastMessageText = content;
    }

    // [쓰기 작업 1]: messages 하위 컬렉션에 메시지 저장
    final messageRef = _firestore
        .collection(_chatRoomsCollection)
        .doc(chatId)
        .collection(_messagesCollection);

    await messageRef.add(newMessage.toFirestore());

    // [쓰기 작업 2]: 채팅방 문서 업데이트 (목록 화면 갱신을 위함)
    await _firestore.collection(_chatRoomsCollection).doc(chatId).set({
      'lastMessage': lastMessageText, // ⭐️ [수정] 마지막 메시지 텍스트
      'lastMessageSenderId': senderId,
      'updatedAt': timestamp,
    }, SetOptions(merge: true));

    if (kDebugMode) {
      print('✅ 메시지 전송 (${type}) 및 채팅방 업데이트 성공: $chatId');
    }
  }

  // ----------------------------------------------------
  // 3. 특정 채팅방의 실시간 메시지 목록 스트림 (유지)
  // ----------------------------------------------------
  Stream<List<Message>> getChatMessages(String chatId) {
    return _firestore
        .collection(_chatRoomsCollection)
        .doc(chatId)
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Message.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null);
      }).toList();
    });
  }

  // ----------------------------------------------------
  // 4. 사용자가 참여하는 채팅방 목록 스트림 (유지)
  // ----------------------------------------------------
  Stream<List<ChatRoom>> getChatRooms(String userId) {
    return _firestore
        .collection(_chatRoomsCollection)
        .where(Filter.or(
      Filter('sellerId', isEqualTo: userId),
      Filter('buyerId', isEqualTo: userId),
    ))
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatRoom.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null);
      }).toList();
    });
  }

  // ----------------------------------------------------
  // 5. 단일 채팅방 삭제 로직 (유지)
  // ----------------------------------------------------
  Future<void> deleteChatRoom(String chatRoomId) async {
    final chatRoomRef = _firestore.collection(_chatRoomsCollection).doc(chatRoomId);
    final messagesRef = chatRoomRef.collection(_messagesCollection);

    int messagesDeleted = 0;
    try {
      bool hasMore = true;
      while (hasMore) {
        final messagesSnapshot = await messagesRef.limit(_batchSize).get();
        final batch = _firestore.batch();
        for (var doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        if (messagesSnapshot.docs.isNotEmpty) {
          await batch.commit();
          messagesDeleted += messagesSnapshot.size;
        }
        if (messagesSnapshot.size < _batchSize) {
          hasMore = false;
        }
      }
      if (kDebugMode) {
        print('✅ ChatRoom $chatRoomId의 총 $messagesDeleted개 메시지 삭제 완료.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 메시지 삭제 중 오류 발생: $e (메인 채팅방 문서는 삭제 시도)');
      }
    }

    try {
      await chatRoomRef.delete();
      if (kDebugMode) {
        print('✅ ChatRoom $chatRoomId 메인 문서 삭제 완료.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 채팅방 $chatRoomId 메인 문서 삭제 실패: $e');
      }
      rethrow;
    }
  }

  // ----------------------------------------------------
  // 6. 모든 사용자 채팅방 삭제 로직 (유지)
  // ----------------------------------------------------
  Future<void> deleteAllUserChatRooms(String userId) async {
    if (kDebugMode) {
      print('⏳ 사용자 $userId의 모든 채팅방 삭제 시작...');
    }

    final querySeller = _firestore.collection(_chatRoomsCollection).where('sellerId', isEqualTo: userId);
    final queryBuyer = _firestore.collection(_chatRoomsCollection).where('buyerId', isEqualTo: userId);

    final snapshotSeller = await querySeller.get();
    final snapshotBuyer = await queryBuyer.get();

    final allDocs = [...snapshotSeller.docs, ...snapshotBuyer.docs];
    final uniqueDocIds = allDocs.map((doc) => doc.id).toSet();

    int deletedCount = 0;

    for (var docId in uniqueDocIds) {
      try {
        await deleteChatRoom(docId);
        deletedCount++;
      } catch (e) {
        if (kDebugMode) {
          print('❌ 개별 채팅방 $docId 삭제 중 최종 오류 발생: $e');
        }
      }
    }

    if (kDebugMode) {
      print('✅ 사용자 $userId의 채팅방 총 $deletedCount개 삭제 완료.');
    }
  }
}