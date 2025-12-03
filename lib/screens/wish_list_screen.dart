// lib/screens/wish_list_screen.dart

import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/item_model.dart';
// 💡 ItemListTile 위젯 임포트를 가정합니다. (경로 확인 필요)
// import '../widgets/item_list_tile.dart';

class WishListScreen extends StatefulWidget {
  final String currentUserId;

  const WishListScreen({super.key, required this.currentUserId});

  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  Future<List<ItemModel>>? _likedPostsFuture;

  @override
  void initState() {
    super.initState();
    // ⭐️ 화면 로드 시 찜한 게시글 목록을 가져오는 함수 호출
    _likedPostsFuture = _fetchLikedPosts();
  }

  // ⭐️ 찜한 게시글 ID 목록을 조회하고 실제 ItemModel 리스트로 변환하는 함수
  Future<List<ItemModel>> _fetchLikedPosts() async {
    // 1. 찜한 게시글 ID 목록을 가져옵니다.
    final likedIds = await FirestoreService.getLikedPostIds(widget.currentUserId);

    if (likedIds.isEmpty) {
      return [];
    }

    // 2. (TODO: 효율적인 방법 필요) 각 ID에 해당하는 게시글 정보를 가져옵니다.
    // 💡 FirestoreService에 ID 목록으로 여러 게시글을 한 번에 가져오는
    //    getItemByIds(List<String> itemIds) 메서드가 구현되어 있어야 효율적입니다.

    // ⚠️ 경고: 현재 FirestoreService에 ItemModel을 ID 목록으로 가져오는 메서드(getItemByIds)가 없으므로,
    //    이 부분은 개발자가 추가 구현해야 합니다.

    // ⭐️ 임시 코드: 실제 DB 로직을 연결할 때까지 빈 리스트 반환
    // return await FirestoreService.getItemsByIds(likedIds); // 👈 실제 구현 시 이렇게 사용
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관심 목록', style: TextStyle(color: Colors.black)),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<List<ItemModel>>(
        future: _likedPostsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다: ${snapshot.error}'));
          }

          final likedPosts = snapshot.data ?? [];

          if (likedPosts.isEmpty) {
            return const Center(
              child: Text('찜한 게시글이 없습니다. 마음이 가는 매물을 찜해보세요!', style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          // ⭐️ 게시글 목록 표시
          return ListView.separated(
            itemCount: likedPosts.length,
            separatorBuilder: (context, index) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final item = likedPosts[index];

              // 💡 프로젝트의 ItemListTile 위젯을 사용하여 게시글 목록을 표시해야 합니다.
              // return ItemListTile(item: item);
              return ListTile(
                title: Text(item.title),
                subtitle: Text('${item.price}원'),
                leading: const Icon(Icons.favorite, color: Colors.red),
              );
            },
          );
        },
      ),
    );
  }
}