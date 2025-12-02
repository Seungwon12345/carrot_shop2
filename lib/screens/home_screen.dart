// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'post_write_screen.dart';
import '../models/item_model.dart';
import '../services/firestore_service.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

//==================================================
// 0. 천안시 동 이름 매핑 유틸리티 클래스
//==================================================

class CheonanLocationMapper {
  static final Map<String, String> _dongMap = {
    // 서북구
    'ssangyong-dong': '쌍용동',
    'ssangyongdong': '쌍용동',
    'bongmyeong-dong': '봉명동',
    'bongmyeongdong': '봉명동',
    'seongjeong-dong': '성정동',
    'seongjeongdong': '성정동',
    'dujeong-dong': '두정동',
    'dujeongdong': '두정동',
    'baekseok-dong': '백석동',
    'baekseokdong': '백석동',
    'cheonghwa-dong': '청화동',
    'cheonghwadong': '청화동',
    'sinbang-dong': '신방동',
    'sinbangdong': '신방동',
    'sinbu-dong': '신부동',
    'sinbudong': '신부동',
    'yongam-dong': '용암동',
    'yongamdong': '용암동',

    // 동남구
    'anseo-dong': '안서동',
    'anseodong': '안서동',
    'dongnam-gu': '동남구',
    'dongnamgu': '동남구',
    'seongnam-dong': '성남동',
    'seongnamdong': '성남동',
    'cheongdang-dong': '청당동',
    'cheongdangdong': '청당동',
    'daeheung-dong': '대흥동',
    'daeheungdong': '대흥동',
    'munhwa-dong': '문화동',
    'munhwadong': '문화동',
    'jungang-dong': '중앙동',
    'jungangdong': '중앙동',
    'munseong-dong': '문성동',
    'munseongdong': '문성동',
    'olyong-dong': '오룡동',
    'olyongdong': '오룡동',
    'yongok-dong': '용곡동',
    'yongokdong': '용곡동',
    'mokcheon': '목천읍',
    'mokcheonup': '목천읍',
  };

  static String convertToKorean(String location) {
    // 공백으로 구분된 경우 마지막 부분만 추출
    final parts = location.split(' ');
    final lastPart = parts.isNotEmpty ? parts.last : location;

    // 소문자로 변환하고 공백, 하이픈 제거
    String normalized = lastPart.toLowerCase().replaceAll(' ', '').replaceAll('-', '');

    // 매핑된 한글 이름 반환
    if (_dongMap.containsKey(normalized)) {
      return _dongMap[normalized]!;
    }

    // 매핑되지 않은 경우 원본 반환
    return lastPart;
  }
}

//==================================================
// 1. PostListWidget (Firebase 연동된 게시글 목록 UI)
//==================================================

class PostListWidget extends StatelessWidget {
  final String selectedLocation;
  final String currentUserId;

  const PostListWidget({
    super.key,
    required this.selectedLocation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    // ⭐️ 영문 동 이름을 한글로 변환
    final String koreanLocation = CheonanLocationMapper.convertToKorean(selectedLocation);

    // '동' 이름만 추출 (예: '충남 천안시 서북구 성정동' -> '성정동')
    final String locationName = koreanLocation.split(' ').last;

    return StreamBuilder<List<ItemModel>>(
      stream: FirestoreService.getItemsByLocation(locationName),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }

        if (snapshot.hasError) {
          return Center(child: Text('게시글을 불러오는 중 오류가 발생했습니다: ${snapshot.error}'));
        }

        final posts = snapshot.data;

        if (posts == null || posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.layers_clear, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text('게시글이 없습니다.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                Text('첫 게시글을 작성해보세요!', style: TextStyle(fontSize: 16, color: Colors.grey)),
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

  // 게시글 리스트 아이템 위젯 (ItemModel 사용)
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

    // 가격 포맷 (세 자리마다 콤마 추가)
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
// 2. 더미 화면 위젯 유지
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

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(screenName: '검색');
  }
}

//==================================================
// 3. HomeScreen (메인 화면)
//==================================================

class HomeScreen extends StatefulWidget {
  final String selectedLocation; // ⭐️ String (nullable 아님, 기본값 없음)
  final String userId;

  const HomeScreen({
    super.key,
    required this.selectedLocation, // ⭐️ required로 변경
    required this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  String _getCurrentUserId() {
    return widget.userId;
  }

  @override
  void initState() {
    super.initState();

    final currentUserId = _getCurrentUserId();

    _widgetOptions = <Widget>[
      // 0. 홈 (PostListWidget)
      PostListWidget(
        selectedLocation: widget.selectedLocation,
        currentUserId: currentUserId,
      ),
      // 1. 동네 지도
      const Center(child: Text('동네 지도 화면')),
      // 2. 채팅
      ChatScreen(currentUserId: currentUserId),
      // 3. 나의 마켓/프로필 화면 연결
      const ProfileScreen(),
    ];
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildCategoryButton(String text) {
    bool isSelected = text == '동네소식';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(text),
        selected: isSelected,
        selectedColor: Colors.grey.shade200,
        backgroundColor: Colors.transparent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: isSelected ? Colors.grey.shade400 : Colors.grey.shade300),
        ),
        onSelected: (selected) {
          // TODO: 카테고리 필터링 로직 구현
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 홈 화면이 아닌 다른 탭을 선택했을 경우, 앱바를 간소화
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

    // ⭐️ 영문 동 이름을 한글로 변환
    final String displayLocation = CheonanLocationMapper.convertToKorean(widget.selectedLocation);

    // 홈 화면 (첫 번째 탭)
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayLocation, // ⭐️ 한글로 변환된 동 이름 표시
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
                      MaterialPageRoute(builder: (context) => const SearchScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () { /* 메뉴 */ },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.black),
                  onPressed: () { /* 알림 */ },
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildCategoryButton('동네소식'),
                _buildCategoryButton('가구/홈 물품'),
                _buildCategoryButton('부동산'),
                _buildCategoryButton('생활/공산품'),
                _buildCategoryButton('디지털기기'),
                _buildCategoryButton('기타'),
              ],
            ),
          ),
        ),
      ),

      body: _widgetOptions[0],

      bottomNavigationBar: _buildBottomNavigationBar(),

      // 플로팅 액션 버튼: PostWriteScreen으로 연결
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