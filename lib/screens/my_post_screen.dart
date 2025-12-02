// lib/screens/my_posts_screen.dart

import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/item_model.dart';
import 'post_detail_screen.dart';
import 'post_write_screen.dart';

// ⭐️ [수정]: StatelessWidget에서 StatefulWidget으로 변경
class MyPostsScreen extends StatefulWidget {
  final String userId;
  final String nickname;

  const MyPostsScreen({
    super.key,
    required this.userId,
    required this.nickname,
  });

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

// ⭐️ [추가]: State 클래스 정의
class _MyPostsScreenState extends State<MyPostsScreen> {

  // ⭐️ [State 함수]: 게시글 수정/삭제 옵션 다이얼로그
  Future<void> _showPostOptionsDialog(BuildContext context, ItemModel post) async {
    // context를 State의 context 대신, buildContext를 사용합니다.
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('게시글 수정'),
              onTap: () {
                Navigator.pop(context, 'edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('게시글 삭제'),
              onTap: () {
                Navigator.pop(context, 'delete');
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('상세 보기'),
              onTap: () {
                Navigator.pop(context, 'view');
              },
            ),
          ],
        );
      },
    );

    if (result == 'edit') {
      _handleEditPost(context, post);
    } else if (result == 'delete') {
      _handleDeletePost(context, post.id);
    } else if (result == 'view') {
      _handleViewPost(context, post, widget.userId);
    }
  }

  // ⭐️ [State 함수]: 게시글 수정 처리
  void _handleEditPost(BuildContext context, ItemModel post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostWriteScreen(
          userLocation: post.location,
          userId: post.userId,
          editingPost: post,
        ),
      ),
    );

    if (result == true) {
      if (mounted) { // ⭐️ mounted 체크
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 게시글이 성공적으로 수정되었습니다.'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  // ⭐️ [State 함수]: 게시글 삭제 처리
  void _handleDeletePost(BuildContext context, String postId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('게시글 삭제 확인'),
          content: const Text('정말로 이 게시글을 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirestoreService.deleteItemFromFirestore(postId);

        // ⭐️ [핵심 수정]: context 사용 전에 mounted 체크
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ 게시글이 성공적으로 삭제되었습니다.'), duration: Duration(seconds: 2)),
          );
        }
      } catch (e) {
        // ⭐️ [핵심 수정]: context 사용 전에 mounted 체크
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ 게시글 삭제 실패: $e')),
          );
        }
      }
    }
  }

  // ⭐️ [State 함수]: 상세 보기 처리
  void _handleViewPost(BuildContext context, ItemModel post, String currentUserId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          post: post,
          currentUserId: currentUserId,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          // ⭐️ widget.nickname 접근
          '${widget.nickname} 님의 게시글',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<ItemModel>>(
        // ⭐️ widget.userId 접근
        stream: FirestoreService.streamItemsByUserId(widget.userId),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (snapshot.hasError) {
            return Center(child: Text('게시글을 불러오는 중 오류가 발생했습니다: ${snapshot.error}'));
          }

          final posts = snapshot.data;

          if (posts == null || posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sentiment_dissatisfied, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('${widget.nickname} 님이 작성한 게시글이 없습니다.', style: const TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _buildPostItem(context, post);
            },
          );
        },
      ),
    );
  }

  // ⭐️ [State 함수]: 간단한 게시글 리스트 아이템 위젯
  Widget _buildPostItem(BuildContext context, ItemModel post) {
    final DateTime dateTime = post.createdAt.toDate();

    final String timeAgo = '${dateTime.month}/${dateTime.day}';

    final String priceText = post.price == 0
        ? post.status == '나눔' ? '나눔' : '가격 미정'
        : '${post.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';

    return InkWell(
      onTap: () {
        _showPostOptionsDialog(context, post);
      },
      child: Column(
        children: [
          ListTile(
            leading: SizedBox(
              width: 60,
              height: 60,
              child: post.imageUrls.isNotEmpty
                  ? Image.network(
                post.imageUrls.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red),
              )
                  : const Icon(Icons.photo_outlined, color: Colors.grey),
            ),
            title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${post.location} · $timeAgo'),
            trailing: Text(priceText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1, thickness: 0.5, color: Colors.grey),
        ],
      ),
    );
  }
}