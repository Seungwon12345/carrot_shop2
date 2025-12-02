import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_room_models.dart'; // ✅ ChatRoom 모델 (팀원 파일명 확인 필요)
import '../services/chat_service.dart';   // ✅ ChatService
import 'location_picker_screen.dart';     // ✅ 위치 공유 화면

class ChatRoomScreen extends StatefulWidget {
  final ChatRoom chatRoom; // ✅ 팀원 모델 클래스 이름 (ChatRoomModel -> ChatRoom)
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

  late String otherUserId; // 상대방 ID

  @override
  void initState() {
    super.initState();
    // ⭐️ 상대방 ID 계산 (팀원 모델 필드명: sellerId, buyerId 사용)
    otherUserId = (widget.chatRoom.sellerId == widget.currentUserId)
        ? widget.chatRoom.buyerId
        : widget.chatRoom.sellerId;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // ⭐️ [핵심 기능] + 버튼: 위치 공유 화면 이동
  void _onPlusButtonPressed() {
    final myId = widget.currentUserId;

    if (myId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 없습니다.')),
      );
      return;
    }

    // 위치 공유 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          chatRoomId: widget.chatRoom.chatId, // ✅ 팀원 모델 필드명 (id -> chatId)
          myUserId: myId,
          otherUserId: otherUserId,
          otherUserName: '상대방', // (필요시 DB에서 닉네임 조회 추가)
        ),
      ),
    );
  }

  // 메시지 전송 함수
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear(); // 미리 지움 (빠른 반응성)

    try {
      // ✅ 팀원 서비스 함수에 맞춰 'Named Parameter' 방식으로 호출
      await _chatService.sendMessage(
        chatId: widget.chatRoom.chatId,      // roomId -> chatId
        senderId: widget.currentUserId,      // userId -> senderId
        content: text,                       // text -> content
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅방', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // 1. 메시지 리스트
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // ✅ 팀원 서비스 코드의 컬렉션 구조 반영 (chat_start/{chatId}/messages)
              stream: FirebaseFirestore.instance
                  .collection('chat_start')
                  .doc(widget.chatRoom.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('오류 발생: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('대화를 시작해보세요!'));
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == widget.currentUserId;
                    final content = data['text'] ?? ''; // 팀원 DB 필드명 확인 필요 (보통 'text' 또는 'content')

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.orange : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          content,
                          style: TextStyle(color: isMe ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 2. 입력창 영역
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  // + 버튼 (위치 공유)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 28),
                    color: Colors.grey,
                    onPressed: _onPlusButtonPressed,
                  ),

                  // 텍스트 필드
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: '메시지 보내기',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),

                  // 전송 버튼
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.orange),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}