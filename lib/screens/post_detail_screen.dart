// lib/screens/post_detail_screen.dart (최종 수정 - 지도 및 주소 통합)

import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import 'chatroom_screen.dart';
import '../models/chat_room_models.dart';
import 'package:flutter/foundation.dart';
// 🚀 [추가]: 지도 표시 위젯 import
import 'post_detail_map_screen.dart';

// 1. ⭐️ StatefulWidget 유지 ⭐️
class PostDetailScreen extends StatefulWidget {
  final ItemModel post;
  final String currentUserId; // 현재 로그인된 사용자 ID

  const PostDetailScreen({
    super.key,
    required this.post,
    required String currentUserId,
  }) : currentUserId = currentUserId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final ChatService _chatService = ChatService();
  bool _isLiked = false;
  late String _currentStatus;
  late final bool _isMyPost;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.post.status;
    _isMyPost = widget.post.userId.trim() == widget.currentUserId.trim();
    _checkIfLiked();

    if (kDebugMode) {
      print('--- PostDetailScreen Debug ---');
      print('Post User ID (판매글): "${widget.post.userId}"');
      print('Current User ID (로그인): "${widget.currentUserId}"');
      print('Is My Post: $_isMyPost');
      print('-----------------------------');
    }
  }

  void _checkIfLiked() async {
    final liked = await FirestoreService.isPostLiked(
      widget.post.id,
      widget.currentUserId,
    );

    if (mounted) {
      setState(() {
        _isLiked = liked;
      });
    }
  }

  void _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
    });

    try {
      if (_isLiked) {
        await FirestoreService.addLike(widget.post.id, widget.currentUserId);
      } else {
        await FirestoreService.removeLike(widget.post.id, widget.currentUserId);
      }

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isLiked ? '관심 목록에 추가되었습니다.' : '관심 목록에서 제거되었습니다.')),
        );
      }
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('찜 상태 변경 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _updateStatus(String newStatus) async {
    if (!_isMyPost) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirestoreService.updateItemStatus(widget.post.id, newStatus);

      setState(() {
        _currentStatus = newStatus;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('거래 상태가 "$newStatus"(으)로 변경되었습니다!')),
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상태 변경 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _startChat(BuildContext context) async {
    if (_isMyPost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자신의 게시글과는 채팅할 수 없습니다.')),
      );
      return;
    }

    try {
      final chatRoom = await _chatService.getOrCreateChatRoom(
        itemId: widget.post.id,
        opponentUserId: widget.post.userId,
        currentUserId: widget.currentUserId,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              chatRoom: chatRoom,
              currentUserId: widget.currentUserId,
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

  Widget _buildStatusMenu() {
    return PopupMenuButton<String>(
      onSelected: (String result) {
        if (result == '거래 완료') {
          _updateStatus('거래 완료');
        } else if (result == '예약중') {
          _updateStatus('예약중');
        } else if (result == '판매중') {
          _updateStatus('판매중');
        }
      },
      icon: const Icon(Icons.more_vert),
      itemBuilder: (BuildContext context) {
        final List<PopupMenuEntry<String>> items = [];

        if (_currentStatus != '거래 완료') {
          items.add(const PopupMenuItem<String>(
            value: '거래 완료',
            child: Text('거래 완료로 변경', style: TextStyle(color: Colors.red)),
          ));
        }

        if (_currentStatus != '예약중' && _currentStatus != '거래 완료') {
          items.add(const PopupMenuItem<String>(
            value: '예약중',
            child: Text('예약중으로 변경'),
          ));
        }

        if (_currentStatus == '예약중' || _currentStatus == '거래 완료') {
          items.add(const PopupMenuItem<String>(
            value: '판매중',
            child: Text('판매중으로 변경'),
          ));
        }

        return items;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    // 🚀 [추가]: 지도 위젯을 표시할지 결정하는 플래그
    final bool hasTradeLocationDetail = post.tradeLocationDetail != null &&
        post.tradeLocationDetail!.containsKey('latitude');

    // 🚨 [추가]: 상세 주소 텍스트 추출
    final String tradeAddress = post.tradeLocationDetail?['address'] as String? ?? '거래 장소 정보 없음';

    // 🚨 [수정]: 나눔 기능을 제거했으므로, post.status 확인 대신 가격 유무만 확인
    final String priceText = post.price == 0
        ? '가격 미정'
        : '${post.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';


    return Scaffold(
      appBar: AppBar(
        title: Text(post.title, style: const TextStyle(color: Colors.black)),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_isMyPost) _buildStatusMenu(),
        ],
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
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('${post.category} · ', style: const TextStyle(color: Colors.grey)),
                          // ⭐️ 거래 상태 칩
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _currentStatus == '거래 완료' ? Colors.grey : Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _currentStatus,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(post.content, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),

                // ----------------------------------------------------
                // 🚀 [핵심 수정]: 지도 위젯과 주소 텍스트를 함께 표시합니다.
                if (hasTradeLocationDetail)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 거래 희망 장소 제목
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '거래 희망 상세 장소',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      // 상세 주소 텍스트
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                        child: Text(
                          tradeAddress, // 주소 텍스트 표시
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),

                      // 지도 위젯 호출
                      PostDetailMapWidget(
                        tradeLocationDetail: post.tradeLocationDetail!,
                      ),
                    ],
                  ),
                // ----------------------------------------------------

                // ⚠️ 지도 위젯과 하단 바 사이에 Divider 추가 (선택 사항)
                if (hasTradeLocationDetail)
                  const Divider(thickness: 8, color: Color(0xFFF0F0F0)),
              ],
            ),
          ),
          _buildBottomBar(context, priceText),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, String priceText) {
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
            IconButton(
              icon: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : Colors.black,
              ),
              onPressed: _toggleLike,
            ),
            const VerticalDivider(thickness: 1, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(priceText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('가격 제안 불가', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isMyPost ? null : () => _startChat(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMyPost ? Colors.grey : Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              child: Text(
                  _isMyPost ? '나의 게시글' : '채팅하기',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
      ),
    );
  }
}