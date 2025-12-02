// lib/screens/chat_room_screen.dart (수정된 전체 코드)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // ⭐️ [추가] 지도 앱 실행용
import '../models/chat_room_models.dart';
import '../models/message_models.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import 'location_picker_screen.dart'; // ⭐️ 장소 선택 화면 임포트

class ChatRoomScreen extends StatefulWidget {
  final ChatRoom chatRoom;
  final String currentUserId;

  const ChatRoomScreen({
    super.key,
    required this.chatRoom,
    required this.currentUserId,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();

  String? _opponentNickname;
  late final String _opponentId;

  String get _chatId => widget.chatRoom.chatId;

  @override
  void initState() {
    super.initState();
    _opponentId = widget.chatRoom.sellerId == widget.currentUserId
        ? widget.chatRoom.buyerId
        : widget.chatRoom.sellerId;
    _fetchOpponentNickname();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _fetchOpponentNickname() async {
    try {
      final nickname = await FirestoreService.getUserNickname(_opponentId);
      if (mounted) {
        setState(() {
          _opponentNickname = nickname;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _opponentNickname = '닉네임 로드 실패';
        });
      }
    }
  }

  // ⭐️ [수정]: 텍스트 메시지 전송 로직
  void _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      _messageController.clear();
      try {
        await _chatService.sendMessage(
          chatId: _chatId,
          senderId: widget.currentUserId,
          content: text,
          type: 'text',
        );
      } catch (e) {
        print('❌ 텍스트 메시지 전송 실패: $e');
        _showErrorSnackbar(e);
      }
    }
  }

  // ⭐️ [새 함수]: 장소 메시지 전송 로직
  void _sendLocationMessage(Map<String, dynamic> locationData) async {
    try {
      final String address = locationData['address'] as String? ?? '지도 장소';
      final double lat = locationData['latitude'] as double;
      final double lng = locationData['longitude'] as double;

      await _chatService.sendMessage(
        chatId: _chatId,
        senderId: widget.currentUserId,
        content: address,
        type: 'location', // ⭐️ 메시지 타입을 'location'으로 지정
        locationLat: lat,
        locationLng: lng,
      );
    } catch (e) {
      print('❌ 장소 메시지 전송 실패: $e');
      _showErrorSnackbar(e);
    }
  }

  // ⭐️ [새 함수]: 지도 앱 실행 로직
  void _launchMap(double lat, double lng) async {
    // Google Maps URL Scheme (iOS) 또는 Intent (Android) 사용
    final String url = 'https://maps.google.com/?q=$lat,$lng';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지도 앱을 열 수 없습니다.')),
        );
      }
    }
  }

  void _showErrorSnackbar(Object e) {
    String errorMessage = '메시지 전송에 실패했습니다.';
    if (e is FirebaseException) {
      errorMessage = '전송 실패: ${e.code}';
    }

    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String opponentDisplayName = _opponentNickname ?? '닉네임 로딩 중...';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          opponentDisplayName,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () { /* 메뉴 */ },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildItemInfo(context),

          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getChatMessages(_chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('대화 내용을 불러오는 중 오류 발생: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('아직 대화가 없습니다. 메시지를 보내서 대화를 시작해 보세요!', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),

          _buildMessageInput(),
        ],
      ),
    );
  }

  // ⭐️ [수정된 함수] 메시지 버블 위젯 (장소 메시지 처리 추가)
  Widget _buildMessageBubble(Message message) {
    final bool isMe = message.senderId == widget.currentUserId;
    final timeString = DateFormat('a h:mm', 'ko').format(message.timestamp.toDate());
    final String nickname = _opponentNickname ?? '사용자';

    final mainAxisAlignment = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    final crossAxisAlignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;


    Widget messageContent;

    // ⭐️ [핵심]: 메시지 타입에 따라 내용 위젯 변경
    if (message.type == 'location' && message.locationLat != null && message.locationLng != null) {
      // 장소 메시지 위젯
      messageContent = GestureDetector(
        onTap: () => _launchMap(message.locationLat!, message.locationLng!),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: Colors.blue, size: 20),
            const SizedBox(height: 4),
            Text(
              '거래 장소: ${message.text}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.black : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            const Text(
              '눌러서 지도 앱 확인',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      );
    } else {
      // 기본 텍스트 메시지 위젯
      messageContent = Text(
        message.text,
        style: TextStyle(color: isMe ? Colors.black : Colors.black87),
      );
    }

    // ... (이후 버블 레이아웃 로직은 기존과 동일) ...

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
              child: Text(
                nickname,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),

          Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 2.0),
                  child: Text(
                    timeString,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),

              // 메시지 버블
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                    color: isMe ? Colors.orange.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(15),
                      topRight: const Radius.circular(15),
                      bottomLeft: isMe ? const Radius.circular(15) : const Radius.circular(5),
                      bottomRight: isMe ? const Radius.circular(5) : const Radius.circular(15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      )
                    ]
                ),
                child: messageContent, // ⭐️ [수정]: 준비된 messageContent 위젯 사용
              ),

              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                  child: Text(
                    timeString,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Icon(Icons.image, size: 24, color: Colors.white), // 상품 이미지
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '판매 상품 ID: ${widget.chatRoom.itemId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  '가격 정보 (조회 필요)',
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () { /* 거래 완료, 또는 상품 보기 */ },
            child: const Text('거래 완료', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  // ⭐️ [수정된 함수] 메시지 입력창 위젯
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.add, color: Colors.grey),
            onPressed: () async {
              // ⭐️ [핵심 수정]: 장소 선택 화면 호출 로직의 주석을 해제합니다.
              final selectedLocation = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocationPickerScreen(),
                ),
              );

              // ⭐️ 장소 선택 결과가 있으면 전송
              if (selectedLocation != null && selectedLocation is Map<String, dynamic>) {
                _sendLocationMessage(selectedLocation);
              }

              // 🚨 임시 안내 스낵바 코드를 제거했습니다.
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              minLines: 1,
              maxLines: 5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.orange),
            onPressed: _handleSendMessage,
          ),
        ],
      ),
    );
  }
}