import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/item_model.dart';
import 'post_detail_screen.dart';
import 'post_write_screen.dart';

// ⭐️ [추가] 목록 유형을 정의하는 Enum
enum PostListType { myPosts, salesHistory }

class MyPostsScreen extends StatefulWidget {
  final String userId;
  final String nickname;
  // 🚨 [수정] listType을 필수로 받도록 변경했습니다.
  final PostListType listType;
  final String? initialFilterStatus; // 이제 이 필드는 거의 사용되지 않습니다.

  const MyPostsScreen({
    super.key,
    required this.userId,
    required this.nickname,
    required this.listType, // ⭐️ 필수 매개변수
    this.initialFilterStatus,
  });

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  // ⭐️ [추가] 제목과 Stream을 동적으로 저장할 변수
  late String _screenTitle;
  late Stream<List<ItemModel>> _postStream;

  @override
  void initState() {
    super.initState();
    // ⭐️ 초기화 로직 분리
    _initializeScreen();
  }

  // ⭐️ [핵심] listType에 따라 제목과 Stream을 설정하는 함수
  void _initializeScreen() {
    if (widget.listType == PostListType.salesHistory) {
      // 1. 판매 내역 (제목: 판매 내역, 데이터: '거래 완료' 상태만)
      _screenTitle = '판매 내역';

      // 🚨 FirestoreService에 status 필터링 함수가 있어야 합니다.
      // FirestoreService.streamItemsByUserIdAndStatus(userId, statusFilter: '거래 완료') 가정
      _postStream = FirestoreService.streamItemsByUserIdAndStatus(
        widget.userId,
        statusFilter: '거래 완료',
      );

    } else { // PostListType.myPosts
      // 2. 내 게시글 (제목: 내 게시글, 데이터: 모든 게시글)
      _screenTitle = '내 게시글';

      // 모든 게시글을 가져오는 함수 사용
      _postStream = FirestoreService.streamAllItemsByUserId(
        widget.userId,
      );
    }
  }


  // ⭐️ [State 함수]: 게시글 수정/삭제 옵션 다이얼로그 (로직 동일)
  Future<void> _showPostOptionsDialog(BuildContext context, ItemModel post) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 게시글이 성공적으로 수정되었습니다.'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ 게시글이 성공적으로 삭제되었습니다.'), duration: Duration(seconds: 2)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ 게시글 삭제 실패: $e')),
          );
        }
      }
    }
  }

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
          _screenTitle, // ⭐️ 동적으로 설정된 제목 사용
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<ItemModel>>(
        stream: _postStream, // ⭐️ 동적으로 설정된 Stream 사용

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (snapshot.hasError) {
            return Center(child: Text('게시글을 불러오는 중 오류가 발생했습니다: ${snapshot.error}'));
          }

          final posts = snapshot.data;

          if (posts == null || posts.isEmpty) {
            // ⭐️ 목록 유형에 따라 메시지 분리
            final String message = widget.listType == PostListType.salesHistory
                ? '거래 완료된 판매 내역이 없습니다.'
                : '작성한 게시글이 없습니다.';

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sentiment_dissatisfied, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
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

  Widget _buildPostItem(BuildContext context, ItemModel post) {
    final DateTime dateTime = post.createdAt.toDate();

    final String timeAgo = '${dateTime.month}/${dateTime.day}';

    final String priceText = post.price == 0
        ? post.status == '나눔' ? '나눔' : '가격 미정'
        : '${post.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';

    // 상태에 따른 색상 적용
    Color statusColor;
    switch (post.status) {
      case '거래 완료':
        statusColor = Colors.grey;
        break;
      case '예약중':
        statusColor = Colors.blue.shade700;
        break;
    // '판매중'/'나눔' 등 기본 상태
      case '판매중':
      default:
        statusColor = Colors.orange.shade700;
        break;
    }


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
              child: Stack(
                children: [
                  post.imageUrls.isNotEmpty
                      ? Image.network(
                    post.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red),
                  )
                      : const Icon(Icons.photo_outlined, color: Colors.grey),

                  // 이미지 위에 상태 칩 오버레이
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        post.status,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
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