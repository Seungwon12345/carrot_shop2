// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chatroom_screen.dart';
// ⚠️ 수정: 모델 파일명을 확인하고 필요시 변경하세요. (예시: chat_room_model.dart)
import '../models/chat_room_models.dart';
import '../services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;

  const ChatScreen({super.key, required this.currentUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();

  // 1. ✅ 선택 모드 관련 상태 변수
  Set<String> _selectedChatIds = {};
  bool _isSelectionMode = false; // 선택 모드 상태 유지

  // 채팅방 탭 목록
  final List<String> _tabs = const ['전체', '판매', '구매'];

  @override
  void initState() {
    super.initState();
    // 한국어 날짜 형식 사용을 위해 초기화
    // 💡 참고: Intl.defaultLocale 대신 앱 전체에서 설정하는 것이 좋습니다.
    Intl.defaultLocale = 'ko_KR';
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ⭐️ [수정된 함수] 탭별로 채팅 목록 필터링 로직 구현
  List<ChatRoom> _filterChats(List<ChatRoom> allChats, String tab) {
    if (tab == '전체') {
      return allChats;
    }

    // '판매' 탭: 내가 판매자인 채팅방
    if (tab == '판매') {
      return allChats.where((chat) => chat.sellerId == widget.currentUserId).toList();
    }

    // '구매' 탭: 내가 구매자인 채팅방
    if (tab == '구매') {
      return allChats.where((chat) => chat.buyerId == widget.currentUserId).toList();
    }

    return allChats;
  }

  // Timestamp를 'X분 전' 또는 '날짜' 문자열로 변환하는 함수
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return DateFormat('a h:mm', 'ko_KR').format(dateTime);
    } else if (difference.inDays < 7) {
      return DateFormat('E', 'ko_KR').format(dateTime);
    } else {
      return DateFormat('yy.MM.dd').format(dateTime);
    }
  }

  // ⭐️ [로직 추가] 개별 채팅방 삭제 로직
  void _deleteChatRoom(String chatRoomId) async {
    try {
      await _chatService.deleteChatRoom(chatRoomId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('채팅방이 삭제되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅방 삭제 실패: $e')),
      );
    }
  }

  // ⭐️ [로직 추가] 선택된 채팅방 일괄 삭제 로직
  void _deleteSelectedChats() async {
    if (_selectedChatIds.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('선택한 채팅방 삭제'),
        content: Text('${_selectedChatIds.length}개의 채팅방을 정말 삭제하시겠습니까? (메시지 포함 영구 삭제)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (result == true) {
      try {
        final List<String> idsToDelete = _selectedChatIds.toList();

        for (final id in idsToDelete) {
          await _chatService.deleteChatRoom(id);
        }

        setState(() {
          _selectedChatIds.clear(); // 선택 목록 초기화
          _isSelectionMode = false; // 선택 모드 해제
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${idsToDelete.length}개의 채팅방이 삭제되었습니다.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅방 일괄 삭제 중 오류 발생: $e')),
        );
      }
    }
  }

  // 삭제 드롭다운 메뉴 위젯 (로직 연결 유지)
  Widget _buildDeleteDropdown() {
    return PopupMenuButton<String>(
      onSelected: (String result) {
        switch (result) {
          case 'start_selection':
            setState(() {
              _isSelectionMode = true;
            });
            break;
          case 'delete_all':
            _confirmDeleteAllChats();
            break;
        }
      },
      icon: const Icon(Icons.more_vert, color: Colors.black),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'start_selection',
          child: Text('선택한 채팅방 삭제',
              style: TextStyle(color: _isSelectionMode ? Colors.grey : Colors.black)),
          enabled: !_isSelectionMode,
        ),
        const PopupMenuItem<String>(
          value: 'delete_all',
          child: Text('모든 채팅방 삭제', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  // ⭐️ [로직 추가] 전체 채팅방 삭제 확인 대화상자
  void _confirmDeleteAllChats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('경고: 모든 채팅방 삭제'),
        content: const Text('현재 사용자님과 관련된 모든 채팅방(메시지 포함)을 영구적으로 삭제합니다. 계속하시겠습니까?', style: TextStyle(color: Colors.red)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 대화상자 닫기
              try {
                await _chatService.deleteAllUserChatRooms(widget.currentUserId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('모든 채팅방이 성공적으로 삭제되었습니다.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('모든 채팅방 삭제 실패: $e')),
                );
              }
            },
            child: const Text('모두 삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ⭐️ [수정된 함수] 상대방 ID를 가져오는 헬퍼 함수 (로직 유지)
  String _getOpponentId(ChatRoom chat) {
    // 내가 판매자(Seller)이면 상대방은 구매자(Buyer)
    if (chat.sellerId == widget.currentUserId) {
      return chat.buyerId;
    }
    // 내가 구매자(Buyer)이면 상대방은 판매자(Seller)
    else if (chat.buyerId == widget.currentUserId) {
      return chat.sellerId;
    }
    // 예외 상황
    return '알 수 없음';
  }

  // ⭐️ [최종 수정] 채팅방 아이템 위젯 (안 읽은 카운트 로직 제거 및 롱프레스 추가)
  Widget _buildChatListItem(ChatRoom chat) {
    final String opponentId = _getOpponentId(chat);
    final String senderName = '상대방 ID: $opponentId'; // ⚠️ 실제로는 사용자 닉네임을 가져와야 함
    final String timeAgo = _formatTimeAgo(chat.updatedAt.toDate());
    final isSelected = _selectedChatIds.contains(chat.chatId);

    // 헬퍼 함수: 선택 토글 (onTap에서 사용)
    void toggleSelection() {
      setState(() {
        if (_selectedChatIds.contains(chat.chatId)) {
          _selectedChatIds.remove(chat.chatId);
        } else {
          _selectedChatIds.add(chat.chatId);
        }
        // 모든 선택이 해제되면, 자동적으로 선택 모드를 해제합니다.
        if (_selectedChatIds.isEmpty && _isSelectionMode) {
          _isSelectionMode = false;
        }
      });
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

      leading: _isSelectionMode
          ? Checkbox(
        value: isSelected,
        onChanged: (val) {
          toggleSelection();
        },
      )
          : const CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      ),

      tileColor: isSelected ? Colors.blue.shade50 : null,

      title: Text(
        senderName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        chat.lastMessageText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
      ),

      // ⭐️ [수정] 안 읽은 카운트 로직 제거, timeAgo만 표시
      trailing: _isSelectionMode
          ? null
          : Text(
        timeAgo,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),

      onTap: () {
        if (_isSelectionMode) {
          toggleSelection();
        } else {
          // 일반 모드면 채팅방 이동
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatRoomScreen(
                chatRoom: chat,
                currentUserId: widget.currentUserId,
              ),
            ),
          );
        }
      },
      // ⭐️ [추가] 롱프레스 로직
      onLongPress: _isSelectionMode ? null : () {
        setState(() {
          _isSelectionMode = true;
          _selectedChatIds.add(chat.chatId);
        });
      },
    );
  }

  // 탭 뷰 콘텐츠 위젯 (로직 유지)
  Widget _buildTabViewContent(String tab) {
    return StreamBuilder<List<ChatRoom>>(
      // ChatService는 'participants' 필드를 사용하여 채팅방을 가져와야 효율적입니다.
      stream: _chatService.getChatRooms(widget.currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('채팅 목록을 불러오는 중 오류 발생: ${snapshot.error}'));
        }

        final allChats = snapshot.data ?? [];
        // ⭐️ [변경] 필터링 함수 호출
        final filteredChats = _filterChats(allChats, tab);

        if (filteredChats.isEmpty) {
          return Center(
            child: Text(
              '${tab} 채팅이 없습니다.',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredChats.length,
          itemBuilder: (context, index) {
            return _buildChatListItem(filteredChats[index]);
          },
        );
      },
    );
  }

  // ⭐️ [로직 추가] 새로운 채팅방을 생성하고 이동하는 함수 (테스트용)
  void _startNewChat() async {
    // ⚠️ 실제 앱에서는 판매글 상세 화면에서 호출되어야 합니다.
    const String testSellerId = 'seller_id_001';
    const String testBuyerId = 'buyer_id_002';
    const String testItemId = 'item_id_ABC';

    // 현재 사용자가 이미 구매자(buyer)라고 가정하고, 상대방을 판매자(seller)로 설정합니다.
    final String current = widget.currentUserId;
    // 두 사용자 ID가 모두 테스트 ID와 일치할 경우를 방지
    final String opponent = (current == testBuyerId) ? testSellerId : testBuyerId;

    try {
      final chatRoom = await _chatService.getOrCreateChatRoom(
        currentUserId: current,
        opponentUserId: opponent,
        itemId: testItemId,
      );

      // 채팅방 생성/조회 성공 후 이동
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              chatRoom: chatRoom,
              currentUserId: current,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('테스트 채팅방 생성 실패: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        // 🚀 [수정] 선택 모드에 따른 앱바 UI 변경
        title: _isSelectionMode
            ? Text(
          '채팅방 선택 (${_selectedChatIds.length}개)',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        )
            : TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 2,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
        actions: [
          // 🚀 [핵심 변경] 선택 모드일 때 삭제 버튼과 취소 버튼만 표시
          if (_isSelectionMode) ...[
            // 🗑️ 삭제 버튼 (선택된 항목이 1개 이상일 때만 활성화)
            IconButton(
              icon: Icon(Icons.delete_outline,
                color: _selectedChatIds.isNotEmpty ? Colors.red : Colors.grey,
              ),
              onPressed: _selectedChatIds.isNotEmpty ? _deleteSelectedChats : null,
            ),
            // 취소 버튼
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedChatIds.clear();
                });
              },
              child: const Text('취소', style: TextStyle(color: Colors.blue, fontSize: 16)),
            ),
          ]
          else
          // 일반 모드 액션
            ...[
              IconButton(
                icon: const Icon(Icons.search, color: Colors.black),
                onPressed: () { /* 검색 */ },
              ),
              _buildDeleteDropdown(), // 삭제 드롭다운
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.black),
                onPressed: () { /* 알림 */ },
              ),
              const SizedBox(width: 8),
            ],
        ],
      ),

      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _buildTabViewContent(tab)).toList(),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _startNewChat,
        backgroundColor: _isSelectionMode ? Colors.grey : Colors.orange,
        child: const Icon(Icons.add_comment_outlined, color: Colors.white),
        tooltip: '새로운 채팅 시작 (테스트용)',
      ),
    );
  }
}