// lib/screens/post_detail_screen.dart (최종 수정)

import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../services/chat_service.dart';
import 'chatroom_screen.dart';
import '../models/chat_room_models.dart';
import 'package:flutter/foundation.dart'; // 💡 디버깅을 위해 추가

class PostDetailScreen extends StatelessWidget {
  final ItemModel post;
  final String currentUserId; // 현재 로그인된 사용자 ID

  final ChatService _chatService = ChatService();

  PostDetailScreen({
    super.key,
    required this.post,
    required this.currentUserId,
  }) {
    // ⭐️ [디버깅 추가]: ID 값과 비교 결과를 콘솔에 출력
    if (kDebugMode) {
      print('--- PostDetailScreen Debug ---');
      print('Post User ID (판매글): "${post.userId}"');
      print('Current User ID (로그인): "${currentUserId}"');
      print('Trimmed Compare Result: ${post.userId.trim() == currentUserId.trim()}');
      print('-----------------------------');
    }
  }

  // ⭐️ [핵심 함수] 채팅방 생성/이동 로직 수정
  void _startChat(BuildContext context) async {
    // ⭐️ [수정]: trim()을 사용하여 문자열 비교 강제
    if (post.userId.trim() == currentUserId.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자신의 게시글과는 채팅할 수 없습니다.')),
      );
      return;
    }
    // ... (채팅방 생성 로직 유지)
    try {
      final chatRoom = await _chatService.getOrCreateChatRoom(
        itemId: post.id,
        opponentUserId: post.userId,
        currentUserId: currentUserId,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              chatRoom: chatRoom,
              currentUserId: currentUserId,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅방 생성 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (build 함수 내용 유지)
    final String priceText = post.price == 0
        ? post.status == '나눔' ? '나눔' : '가격 미정'
        : '${post.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';

    return Scaffold(
      appBar: AppBar(
        title: Text(post.title, style: const TextStyle(color: Colors.black)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.imageUrls.isNotEmpty)
                  Image.network(
                    post.imageUrls.first,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text('판매자 ID: ${post.userId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(post.location),
                  trailing: const Icon(Icons.more_vert),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('${post.category} · ${post.status}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      Text(post.content, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildBottomBar(context, priceText),
        ],
      ),
    );
  }

  // 하단 '가격 및 채팅' 바 위젯 (수정됨)
  Widget _buildBottomBar(BuildContext context, String priceText) {
    // ⭐️ [수정]: isMyPost 계산 시 trim()을 사용하여 문자열 비교 강제
    final bool isMyPost = post.userId.trim() == currentUserId.trim();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
        ),
        child: Row(
          children: [
            // 좋아요 버튼
            IconButton(
              icon: const Icon(Icons.favorite_border, color: Colors.black),
              onPressed: () {},
            ),
            const VerticalDivider(thickness: 1, color: Colors.grey),
            const SizedBox(width: 8),
            // 가격 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(priceText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('가격 제안 불가', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            // ⭐️ [핵심 수정] 채팅하기 버튼 비활성화 로직
            ElevatedButton(
              // 내 게시글이면 onPressed: null로 비활성화
              onPressed: isMyPost ? null : () => _startChat(context),
              style: ElevatedButton.styleFrom(
                // 내 게시글이면 회색으로, 아니면 주황색으로 표시
                backgroundColor: isMyPost ? Colors.grey : Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              child: Text(
                // 내 게시글이면 텍스트 변경
                  isMyPost ? '나의 게시글' : '채팅하기',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
      ),
    );
  }
}
