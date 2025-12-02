import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/item_model.dart';
import 'package:flutter/foundation.dart'; // print 사용을 위해 추가

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  static const String _itemsCollection = 'items';

  // ==========================================
  // 👤 사용자(User) 관련 메서드
  // ==========================================

  // 1. 사용자 정보 저장
  static Future<void> saveUserToFirestore(UserModel user) async {
    if (kDebugMode) {
      print('🔥 Firestore 사용자 저장 시작: ${user.id}');
    }
    try {
      final docRef = _firestore.collection(_usersCollection).doc(user.id);

      final data = {
        ...user.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await docRef.set(data, SetOptions(merge: true));
      if (kDebugMode) {
        print('✅ 사용자 정보 저장 성공');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 저장 실패: $e');
      }
      rethrow;
    }
  }

  // 2. 사용자 정보 가져오기
  static Future<UserModel?> getUserFromFirestore(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 조회 실패: $e');
      }
      return null;
    }
  }

  // 3. 사용자 정보 업데이트
  static Future<void> updateUserInFirestore(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(_usersCollection).doc(userId).update(updates);
      if (kDebugMode) {
        print('✅ 사용자 정보 업데이트 성공: $updates');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 정보 업데이트 실패: $e');
      }
      rethrow;
    }
  }

  // 4. 이메일로 사용자 찾기
  static Future<UserModel?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromJson(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 5. 닉네임 중복 확인
  static Future<bool> isNicknameAvailable(String nickname) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('nickname', isEqualTo: nickname)
          .limit(1)
          .get();
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  // 6. 사용자 닉네임 조회 (ChatRoomScreen에서 사용)
  static Future<String> getUserNickname(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final String nickname = data['nickname'] ?? '사용자(ID: $userId)';

        if (kDebugMode) {
          print('✅ 닉네임 조회 성공: $userId -> $nickname');
        }
        return nickname;
      }

      if (kDebugMode) {
        print('⚠️ 닉네임 문서 없음: $userId');
      }
      return '탈퇴한 사용자';
    } catch (e) {
      if (kDebugMode) {
        print('❌ 닉네임 조회 실패: $e');
      }
      return '오류 발생 사용자';
    }
  }

  // ==========================================
  // 📦 게시글(Item) 관련 메서드
  // ==========================================

  // 1. 게시글 저장
  static Future<void> saveItemToFirestore(ItemModel item) async {
    if (kDebugMode) {
      print('🔥 게시글 저장 시작: ${item.id}');
    }
    try {
      final docRef = _firestore.collection(_itemsCollection).doc(item.id);
      await docRef.set(item.toJson(), SetOptions(merge: true));
      if (kDebugMode) {
        print('✅ 게시글 저장 성공');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 게시글 저장 실패: $e');
      }
      rethrow;
    }
  }

  // 2. 위치 기반 게시글 조회
  static Stream<List<ItemModel>> getItemsByLocation(String locationName) {
    if (kDebugMode) {
      print('🔥 위치 기반 조회 요청: $locationName');
    }

    return _firestore
        .collection(_itemsCollection)
        .where('location', isEqualTo: locationName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ItemModel.fromJson(data);
      }).toList();
    });
  }

  // 3. 사용자별 게시글 조회 (Future 버전)
  static Future<List<ItemModel>> getItemsByUserId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_itemsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ItemModel.fromJson(data);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 판매 내역 조회 실패: $e');
      }
      return [];
    }
  }

  // ⭐️ 4. 사용자별 게시글 실시간 스트림 조회 (Stream 버전)
  /// 특정 사용자가 작성한 게시글 목록을 실시간으로 스트리밍합니다.
  static Stream<List<ItemModel>> streamItemsByUserId(String userId) {
    if (kDebugMode) {
      print('🔥 사용자 ID 기반 실시간 조회 요청: $userId');
    }

    return _firestore
        .collection(_itemsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots() // Stream 반환
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ItemModel.fromJson(data);
      }).toList();
    });
  }


  // 5. 게시글 삭제
  static Future<void> deleteItemFromFirestore(String itemId) async {
    try {
      await _firestore.collection(_itemsCollection).doc(itemId).delete();
      if (kDebugMode) {
        print('✅ 게시글 삭제 성공');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 게시글 삭제 실패: $e');
      }
      rethrow;
    }
  }
}