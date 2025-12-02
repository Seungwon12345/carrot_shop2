// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// 화면 및 모델 임포트
import 'post_write_screen.dart';
import '../models/item_model.dart';
import '../services/firestore_service.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart'; // 실제 검색 화면 파일이 존재해야 합니다.

//==================================================
// 0. 천안시 동 이름 매핑 유틸리티 클래스 (Snippet 1 유지)
//==================================================

class CheonanLocationMapper {
  static final Map<String, String> _dongMap = {
    // 서북구
    'ssangyong-dong': '쌍용동', 'ssangyongdong': '쌍용동',
    'bongmyeong-dong': '봉명동', 'bongmyeongdong': '봉명동',
    'seongjeong-dong': '성정동', 'seongjeongdong': '성정동',
    'dujeong-dong': '두정동', 'dujeongdong': '두정동',
    'baekseok-dong': '백석동', 'baekseokdong': '백석동',
    'cheonghwa-dong': '청화동', 'cheonghwadong': '청화동',
    'sinbang-dong': '신방동', 'sinbangdong': '신방동',
    'sinbu-dong': '신부동', 'sinbudong': '신부동',
    'yongam-dong': '용암동', 'yongamdong': '용암동',
    // 동남구
    'anseo-dong': '안서동', 'anseodong': '안서동',
    'dongnam-gu': '동남구', 'dongnamgu': '동남구',
    'seongnam-dong': '성남동', 'seongnamdong': '성남동',
    'cheongdang-dong': '청당동', 'cheongdangdong': '청당동',
    'daeheung-dong': '대흥동', 'daeheungdong': '대흥동',
    'munhwa-dong': '문화동', 'munhwadong': '문화동',
    'jungang-dong': '중앙동', 'jungangdong': '중앙동',
    'munseong-dong': '문성동', 'munseongdong': '문성동',
    'olyong-dong': '오룡동', 'olyongdong': '오룡동',
    'yongok-dong': '용곡동', 'yongokdong': '용곡동',
    'mokcheon': '목천읍', 'mokcheonup': '목천읍',
  };

  static String convertToKorean(String location) {
    final parts = location.split(' ');
    final lastPart = parts.isNotEmpty ? parts.last : location;
    String normalized = lastPart.toLowerCase().replaceAll(' ', '').replaceAll('-', '');

    if (_dongMap.containsKey(normalized)) {
      return _dongMap[normalized]!;
    }
    return lastPart;
  }
}

//==================================================
// 1. PostListWidget (Firebase 연동 + 카테고리 필터링)
//==================================================

class PostListWidget extends StatelessWidget {
  final String selectedLocation;
  final String currentUserId;
  final String selectedCategory; // ⭐️ 카테고리 필터링 추가

  const PostListWidget({
    super.key,
    required this.selectedLocation,
    required this.currentUserId,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    // 1. 영문 동 이름을 한글로 변환 (Snippet 1 로직 적용)
    final String koreanLocation = CheonanLocationMapper.convertToKorean(selectedLocation);

    // 2. '동' 이름만 추출 (예: '충남 천안시 서북구 성정동' -> '성정동')
    final String locationName = koreanLocation.split(' ').last;

    return StreamBuilder<List<ItemModel>>(
      // ⭐️ [핵심]: 위치와 카테고리 필터링을 동시에 적용하여 데이터 요청
      stream: FirestoreService.getItemsByLocationAndCategory(locationName, selectedCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('게시글을 불러오는 중 오류가 발생했습니다.', style: TextStyle(fontSize: 16, color: Colors.red)),
                  const SizedBox(height: 8),
                  const Text('Firestore 인덱스 설정이 필요할 수 있습니다.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        final posts = snapshot.data;

        if (posts == null || posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.layers_clear, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  selectedCategory == '동네소식'
                      ? '게시글이 없습니다.'
                      : '\'$selectedCategory\' 카테고리에\n게시글이 없습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text('첫 게시글을 작성해보세요!', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
    );
  }

  // 게시글 리스트 아이템 위젯
  Widget _buildPostItem(BuildContext context, ItemModel post) {
    final DateTime dateTime = post.createdAt.toDate();

    String formatTimeAgo(DateTime time) {
      final duration = DateTime.now().difference(time);
      if (duration.inMinutes < 60) return '${duration.inMinutes}분 전';
      if (duration.inHours < 24) return '${duration.inHours}시간 전';
      if (duration.inDays < 7) return '${duration.inDays}일 전';
      return '${time.month}/${time.day}';
    }
    final String timeAgo = formatTimeAgo(dateTime);

    final String priceText = post.price == 0
        ? post.status == '나눔' ? '나눔' : '가격 미정'
        : '${post.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              post: post,
              currentUserId: currentUserId,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지 영역
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: post.imageUrls.isEmpty
                      ? const Icon(Icons.photo_outlined, size: 40, color: Colors.grey)
                      : Image.network(
                    post.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                // 텍스트 정보 영역
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            post.location,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const Text(' · ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          Text(
                            timeAgo,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priceText,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Colors.grey),
        ],
      ),
    );
  }
}

//==================================================
// 2. 더미 화면 (SearchScreen은 별도 파일로 분리됨을 가정)
//==================================================

class PlaceholderScreen extends StatelessWidget {
  final String screenName;
  final String? detail;

  const PlaceholderScreen({super.key, required this.screenName, this.detail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(screenName),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$screenName 화면', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (detail != null) Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(detail!, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ),
            const SizedBox(height: 20),
            const Text('💡 이 화면은 아직 구현되지 않았습니다.', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

//==================================================
// 3. HomeScreen (메인 화면)
//==================================================

class HomeScreen extends StatefulWidget {
  final String selectedLocation;
  final String userId;

  const HomeScreen({
    super.key,
    this.selectedLocation = '내 동네', // 기본값 설정
    required this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _selectedCategory = '동네소식'; // 현재 선택된 카테고리
  List<String> _topCategories = []; // 동적으로 불러올 상위 카테고리 목록

  @override
  void initState() {
    super.initState();
    _loadTopCategories(); // 상위 카테고리 로드
  }

  // 상위 카테고리 목록을 Firestore에서 로드
  Future<void> _loadTopCategories() async {
    try {
      final categories = await FirestoreService.getTopCategories(3);
      if (mounted) {
        setState(() {
          _topCategories = categories;
        });
      }
    } catch (e) {
      // 에러 발생 시 빈 리스트 유지 또는 로그 출력
      if (kDebugMode) {
        print("카테고리 로드 실패: $e");
      }
    }
  }

  String _getCurrentUserId() {
    return widget.userId;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 카테고리 칩 버튼 생성
  Widget _buildCategoryButton(String text) {
    bool isSelected = text == _selectedCategory;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(text),
        selected: isSelected,
        selectedColor: Colors.orange.shade100,
        backgroundColor: Colors.transparent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isSelected ? Colors.orange.shade400 : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedCategory = text; // 카테고리 변경 시 화면 갱신
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _getCurrentUserId();

    // ⭐️ 영문 동 이름을 한글로 변환 (AppBar 표시용)
    final String displayLocation = CheonanLocationMapper.convertToKorean(widget.selectedLocation);

    // ⭐️ _widgetOptions 구성
    final List<Widget> _widgetOptions = <Widget>[
      // 0. 홈 (PostListWidget): 위치 정보와 선택된 카테고리 전달
      PostListWidget(
        selectedLocation: widget.selectedLocation,
        currentUserId: currentUserId,
        selectedCategory: _selectedCategory,
      ),
      // 1. 동네 지도
      const PlaceholderScreen(screenName: '동네 지도'),
      // 2. 채팅
      ChatScreen(currentUserId: currentUserId),
      // 3. 나의 마켓/프로필
      const ProfileScreen(),
    ];

    // 홈 탭이 아닐 경우의 Scaffold (간소화된 AppBar)
    if (_selectedIndex != 0) {
      final List<String> appBarTitles = ['중고거래', '동네 지도', '채팅', '나의 마켓'];
      return Scaffold(
        appBar: AppBar(
          title: Text(
            appBarTitles[_selectedIndex],
            style: const TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Center(child: _widgetOptions[_selectedIndex]),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    }

    // 홈 화면 (첫 번째 탭)
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 동 이름 표시 (한글 변환 적용됨)
            Text(
              displayLocation,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.black),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // ⭐️ SearchScreen에 userId 전달
                        builder: (context) => SearchScreen(currentUserId: widget.userId),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () { /* 메뉴 동작 */ },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.black),
                  onPressed: () { /* 알림 동작 */ },
                ),
              ],
            ),
          ],
        ),
        // 상단 카테고리 바
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildCategoryButton('동네소식'),
                // 동적으로 로드된 상위 카테고리들
                ..._topCategories.map((category) => _buildCategoryButton(category)),
                _buildCategoryButton('기타'),
              ],
            ),
          ),
        ),
      ),

      // 선택된 위젯 표시
      body: _widgetOptions[0],

      bottomNavigationBar: _buildBottomNavigationBar(),

      // 글쓰기 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostWriteScreen(
                userLocation: widget.selectedLocation,
                userId: _getCurrentUserId(),
              ),
            ),
          );
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: '홈',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map),
          label: '동네 지도',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: '채팅',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: '나의 마켓',
        ),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      elevation: 5,
    );
  }
}