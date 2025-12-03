// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/item_model.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  static const String _itemsCollection = 'items';
  static const String _likesCollection = 'likes';


  // ==========================================
  // 👤 사용자(User) 관련 메서드 (기존 코드 유지)
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

  // ⭐️ 2. 게시글 상태 업데이트 (PostDetailScreen에서 사용)
  static Future<void> updateItemStatus(String itemId, String newStatus) async {
    try {
      final itemRef = _firestore.collection(_itemsCollection).doc(itemId);

      // 'status' 필드와 'updatedAt' 필드를 업데이트합니다.
      await itemRef.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ 게시글 ID $itemId 의 상태가 $newStatus 로 성공적으로 업데이트되었습니다.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firestore 상태 업데이트 오류: $e');
      }
      rethrow;
    }
  }

  // 3. 위치 기반 게시글 조회 (실시간 동기화)
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

  // ⭐️ 4. 위치 및 카테고리 기반 게시글 조회 (HomeScreen 카테고리 필터링용)
  /// 카테고리가 '동네소식'이 아닐 경우 필터링을 적용합니다.
  static Stream<List<ItemModel>> getItemsByLocationAndCategory(String locationName, String category) {
    if (kDebugMode) {
      print('🔥 위치 및 카테고리 조회 요청: $locationName, $category');
    }

    Query query = _firestore
        .collection(_itemsCollection)
        .where('location', isEqualTo: locationName);

    // '동네소식'은 전체보기 카테고리로 간주
    if (category != '동네소식' && category != '전체' && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ItemModel.fromJson(data);
      }).toList();
    });
  }


  // 5. 사용자별 게시글 실시간 스트림 조회 (기존 버전 - 필터 없음)
  static Stream<List<ItemModel>> streamItemsByUserId(String userId) {
    if (kDebugMode) {
      print('🔥 사용자 ID 기반 실시간 조회 요청 (필터 없음): $userId');
    }

    return _firestore
        .collection(_itemsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots() // Stream 반환
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ItemModel.fromJson(data);
      }).toList();
    });
  }

  // ⭐️ [추가] 5.1. 사용자 작성 모든 게시글 실시간 스트림 조회 (MyPostsScreen에서 사용하기 위해 추가)
  static Stream<List<ItemModel>> streamAllItemsByUserId(String userId) {
    if (kDebugMode) {
      print('🔥 사용자 ID 기반 모든 게시글 조회 요청 (MyPostsScreen용): $userId');
    }

    return _firestore
        .collection(_itemsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots() // Stream 반환
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ItemModel.fromJson(data);
      }).toList();
    });
  }

  // ⭐️ 9. 사용자별 게시글 및 상태 필터링 실시간 스트림 조회 (MyPostsScreen 필터링용)
  static Stream<List<ItemModel>> streamItemsByUserIdAndStatus(String userId, {String? statusFilter}) {
    if (kDebugMode) {
      print('🔥 사용자 ID & 상태 기반 실시간 조회 요청: $userId, 상태: ${statusFilter ?? '전체'}');
    }

    Query query = _firestore
        .collection(_itemsCollection)
        .where('userId', isEqualTo: userId);

    // 상태 필터가 제공된 경우 (예: '거래 완료'), 쿼리 조건에 추가합니다.
    // '전체' 등의 값은 무시하고 필터링을 하지 않습니다.
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != '전체') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots() // Stream 반환
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ItemModel.fromJson(data);
      }).toList();
    });
  }


  // 6. 게시글 삭제
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

  // ⭐️ 7. 통합 검색 로직 (SearchScreen에서 사용)
  static Future<List<ItemModel>> searchItems(String query) async {
    final queryLower = query.toLowerCase();

    // 1. 카테고리 일치 검색
    final categorySnapshot = await _firestore.collection(_itemsCollection)
        .where('category', isEqualTo: query)
        .get();

    final List<ItemModel> categoryResults = categorySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return ItemModel.fromJson(data);
    }).toList();

    // 2. 제목 기반 검색 (클라이언트 필터링 - Firestore FTS 부재로 인한 임시 조치)
    // 🚨 대규모 데이터에서는 성능 문제가 발생하므로, 실제 서비스에서는 Algolia 등이 필요합니다.
    final allItemsSnapshot = await _firestore.collection(_itemsCollection).get();

    final List<ItemModel> titleResults = allItemsSnapshot.docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return ItemModel.fromJson(data);
    })
        .where((item) => item.title.toLowerCase().contains(queryLower))
        .toList();

    // 3. 결과 병합 및 중복 제거
    final allResultsMap = { for (var item in categoryResults) item.id: item };
    for (var item in titleResults) {
      allResultsMap[item.id] = item;
    }

    return allResultsMap.values.toList();
  }

  // ⭐️ 8. 게시글 수 기준 상위 N개 카테고리 조회 (HomeScreen 탭용)
  static Future<List<String>> getTopCategories(int limit) async {
    try {
      // 🚨 Firebase는 GROUP BY를 지원하지 않아 모든 문서를 가져와 클라이언트에서 처리합니다.
      final snapshot = await _firestore.collection(_itemsCollection).get();

      Map<String, int> categoryCounts = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String?;
        if (category != null && category.isNotEmpty && category != '동네소식' && category != '기타') {
          categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        }
      }

      final sortedCategories = categoryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 상위 limit개만 추출
      return sortedCategories.take(limit).map((e) => e.key).toList();

    } catch (e) {
      if (kDebugMode) {
        print('❌ 상위 카테고리 조회 실패: $e');
      }
      // 오류 시 기본 카테고리 목록 반환
      return ['가구/홈 물품', '생활/공산품', '디지털기기'];
    }
  }

  // ==========================================
  // ❤️ 찜하기 (좋아요) 관련 메서드 (기존 코드 유지)
  // ==========================================

  // 1. 찜하기 추가 (Like)
  static Future<void> addLike(String itemId, String userId) async {
    // 문서 ID를 itemId와 userId 조합으로 설정하여 고유성을 보장합니다.
    final likeId = '${itemId}_$userId';
    try {
      await _firestore.collection(_likesCollection).doc(likeId).set({
        'itemId': itemId,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        print('✅ 찜하기 추가 성공: $itemId by $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 찜하기 추가 실패: $e');
      }
      rethrow;
    }
  }

  // 2. 찜하기 제거 (Unlike)
  static Future<void> removeLike(String itemId, String userId) async {
    final likeId = '${itemId}_$userId';
    try {
      await _firestore.collection(_likesCollection).doc(likeId).delete();
      if (kDebugMode) {
        print('✅ 찜하기 제거 성공: $itemId by $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 찜하기 제거 실패: $e');
      }
      rethrow;
    }
  }

  // 3. 찜 상태 확인 (Check If Liked)
  static Future<bool> isPostLiked(String itemId, String userId) async {
    final likeId = '${itemId}_$userId';
    try {
      final doc = await _firestore.collection(_likesCollection).doc(likeId).get();
      return doc.exists;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 찜 상태 확인 실패: $e');
      }
      // 오류 발생 시 false 반환
      return false;
    }
  }

  // 4. 사용자가 찜한 모든 게시글 ID 목록 가져오기 (Get Liked Posts for Profile Screen)
  static Future<List<String>> getLikedPostIds(String userId) async {
    try {
      // 'userId' 필드를 기준으로 쿼리하여 해당 사용자가 찜한 모든 기록을 가져옵니다.
      final snapshot = await _firestore
          .collection(_likesCollection)
          .where('userId', isEqualTo: userId)
          .get();

      // 조회된 문서에서 'itemId' 필드만 추출하여 List<String> 형태로 반환합니다.
      final likedItemIds = snapshot.docs
          .map((doc) => doc.data()['itemId'] as String)
          .toList();

      if (kDebugMode) {
        print('✅ 찜한 게시글 ID 목록 조회 성공: ${likedItemIds.length}개');
      }
      return likedItemIds;

    } catch (e) {
      if (kDebugMode) {
        print('❌ 찜한 게시글 ID 목록 조회 실패: $e');
      }
      return [];
    }
  }
}