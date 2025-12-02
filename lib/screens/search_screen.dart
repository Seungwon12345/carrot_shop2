// lib/screens/search_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/item_model.dart';
import 'post_detail_screen.dart'; // 상품 상세 페이지 이동을 위한 임포트

class SearchScreen extends StatefulWidget {
  final String? currentUserId;

  const SearchScreen({super.key, this.currentUserId});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // 상태 관리 변수
  List<String> _recentSearches = [];
  final int maxRecentSearches = 8;

  // 검색 결과 상태
  List<ItemModel> _searchResults = [];
  bool _isLoading = false;

  // UI 상태 변수
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // ⭐️ [카테고리 최종 버전]: 학교/서적 포함 및 UI 색상/아이콘 적용
  final List<Map<String, dynamic>> _categories = const [
    // 보라색 계열 (디지털 기기, 의류)
    {'name': '디지털기기', 'icon': Icons.phone_android_outlined, 'color': Color(0xFFC7B1E4)},
    {'name': '의류', 'icon': Icons.checkroom_outlined, 'color': Color(0xFFD8B1E4)},
    // 연두/초록 계열 (생활가전, 스포츠/레저, 취미/게임)
    {'name': '생활가전', 'icon': Icons.tv_outlined, 'color': Color(0xFFC7E4B1)},
    {'name': '스포츠/레저', 'icon': Icons.sports_baseball, 'color': Color(0xFFB1E4D8)},
    {'name': '취미/게임', 'icon': Icons.gamepad_outlined, 'color': Color(0xFFC7E4B1)}, // 연두색 계열로 통일
    // 파랑/하늘 계열 (가구/인테리어, 학교/서적)
    {'name': '가구/인테리어', 'icon': Icons.chair_alt_outlined, 'color': Color(0xFFB1D8E4)},
    {'name': '학교/서적', 'icon': Icons.school_outlined, 'color': Color(0xFFB1D8E4)}, // 파랑/하늘 계열로 통일
    // 주황/노랑 계열 (생활/가공식품, 도서)
    {'name': '생활/가공식품', 'icon': Icons.local_grocery_store_outlined, 'color': Color(0xFFE4C7B1)},
    {'name': '도서', 'icon': Icons.menu_book_outlined, 'color': Color(0xFFE4D8B1)},
    // 핑크 계열 (유아동)
    {'name': '유아동', 'icon': Icons.child_care_outlined, 'color': Color(0xFFE4B1C7)},
    // 기타
    {'name': '반려동물용품', 'icon': Icons.pets_outlined, 'color': Color(0xFFE4D8B1)}, // 노랑 계열 활용
    {'name': '뷰티/미용', 'icon': Icons.brush_outlined, 'color': Color(0xFFD8B1E4)}, // 보라 계열 활용
    {'name': '기타 중고물품', 'icon': Icons.more_horiz, 'color': Color(0xFFE4E4E4)},
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // --- 데이터 로딩 및 저장 (Shared Preferences 사용) ---
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('search:recentSearches') ?? [];
    });
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search:recentSearches', _recentSearches);
  }

  // --- 로직 함수 ---

  void _addRecentSearch(String term) {
    if (term.isEmpty) return;
    _recentSearches.remove(term);
    _recentSearches.insert(0, term);
    if (_recentSearches.length > maxRecentSearches) {
      _recentSearches.removeLast();
    }
    _saveRecentSearches();
  }

  void _handleSearch([String? initialTerm]) async {
    final term = initialTerm ?? _searchController.text.trim();

    if (term.isEmpty) {
      _showInitialView();
      return;
    }

    _addRecentSearch(term);

    setState(() {
      _searchController.text = term;
      _isSearching = true;
      _isLoading = true;
      _searchFocusNode.unfocus();
    });

    try {
      // ⭐️ [Firestore 연동]: searchItems 호출 (실제 데이터 로드)
      final results = await FirestoreService.searchItems(term);

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
        );
      }
      setState(() {
        _isLoading = false;
        _searchResults = [];
      });
    }
  }

  void _handleCategorySearch(String categoryName) {
    _handleSearch(categoryName);
  }

  void _handleRecentSearchClick(String term) {
    _handleSearch(term);
  }

  void _removeRecentSearch(int index) {
    setState(() {
      _recentSearches.removeAt(index);
      _saveRecentSearches();
    });
  }

  void _clearAllRecentSearches() {
    setState(() {
      _recentSearches.clear();
      _saveRecentSearches();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('최근 검색어 목록이 모두 삭제되었습니다.'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.grey.shade800,
      ),
    );
  }

  void _showInitialView() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchFocusNode.requestFocus();
      _searchResults.clear();
    });
  }

  // --- 위젯 구성 요소 ---

  // 1. 헤더 (검색창) 위젯
  PreferredSizeWidget _buildAppBar() {
    final isTextNotEmpty = _searchController.text.isNotEmpty;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 16.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.grey, size: 20),
              onPressed: _isSearching ? _showInitialView : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100, // 원본 UI 색상 유지
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onSubmitted: (_) => _handleSearch(),
                  cursorColor: const Color(0xffff6e30),
                  decoration: InputDecoration(
                    hintText: '물품명 또는 검색할 내용',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                    border: InputBorder.none,
                    // ⭐️ [UX 수정]: 텍스트 패딩 조정하여 중앙으로 보이게 함
                    contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 검색/취소 버튼
            GestureDetector(
              onTap: () => _handleSearch(),
              child: Visibility(
                visible: isTextNotEmpty || _isSearching,
                replacement: const SizedBox.shrink(),
                child: Text(
                  isTextNotEmpty ? '검색' : '취소',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isTextNotEmpty ? const Color(0xffff6e30) : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. 카테고리 섹션 위젯
  Widget _buildCategoryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '카테고리',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16.0,
            crossAxisSpacing: 8.0,
            childAspectRatio: 0.75,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return GestureDetector(
              onTap: () => _handleCategorySearch(category['name'] as String),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: category['color'],
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Icon(category['icon'] as IconData, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 5), // 텍스트 간격 조정
                  Text(
                    category['name'] as String,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // 3. 최근 검색어 섹션 위젯
  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 검색',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: _clearAllRecentSearches,
              child: const Text(
                '전체 삭제',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 최근 검색어 목록
        ..._recentSearches.asMap().entries.map((entry) {
          final index = entry.key;
          final term = entry.value;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, color: Colors.grey, size: 20),
            title: GestureDetector(
              onTap: () => _handleRecentSearchClick(term),
              child: Text(
                term,
                style: const TextStyle(fontSize: 15, color: Colors.black),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
              onPressed: () => _removeRecentSearch(index),
            ),
            onTap: () => _handleRecentSearchClick(term),
          );
        }).toList(),
      ],
    );
  }

  // 4. 검색 결과 목록 위젯 (실제 데이터 반영)
  Widget _buildSearchResultsContent() {
    if (_searchResults.isEmpty && !_isLoading) {
      // ⭐️ 결과가 없을 때 중앙 정렬을 위한 Column
      // 이 Column이 남은 Expanded 공간을 채우도록 Center로 감쌉니다.
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_dissatisfied_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '\'${_searchController.text}\' 에 대한 검색 결과가 없어요.',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ⭐️ [레이아웃 수정]: 결과가 있을 때만 ListView.builder 사용
    // ListView.builder는 shrinkWrap:true 덕분에 Column 안에 안전하게 들어갑니다.
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return _buildProductCard(context, post);
      },
    );
  }

  // ⭐️ [추가] 실제 상품 모델 기반의 카드 위젯
  Widget _buildProductCard(BuildContext context, ItemModel post) {
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
        // 상세 페이지로 이동 시 currentUserId 전달
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              post: post,
              currentUserId: widget.currentUserId!,
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
                            '${post.category} · ${post.location}',
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


  @override
  Widget build(BuildContext context) {
    // ⭐️ [레이아웃 수정]: 렌더링 오류 방지를 위해 Column과 Expanded를 사용
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _isLoading
                ? const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Color(0xffff6e30)),
            ))
                : Expanded( // ⭐️ [핵심]: Expanded로 나머지 공간을 차지하여 렌더링 오류 해결
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isSearching
                      ? _buildSearchResults() // ⭐️ 검색 결과 로직 호출
                      : SingleChildScrollView( // 초기 검색 화면은 스크롤 가능
                    key: const ValueKey('InitialView'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategoryGrid(),
                        const SizedBox(height: 32),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 20),
                        _buildRecentSearches(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // 플로팅 액션 버튼 (글쓰기)
      floatingActionButton: _isSearching ? FloatingActionButton(
        onPressed: () {
          // 글쓰기 화면으로 이동 로직 추가 가능
        },
        backgroundColor: const Color(0xffff6e30), // daangn-orange
        child: const Icon(Icons.add, color: Colors.white, size: 30),
        shape: const CircleBorder(),
        elevation: 4.0,
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ⭐️ [새 함수]: 결과가 있을 때만 ListView를 반환하고, 없으면 Center를 반환 (Expanded 내부에서 사용)
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && !_isLoading) {
      // ⭐️ [결과 없음]: Center를 반환하여 Expanded 공간의 중앙을 차지하게 함
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_dissatisfied_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '\'${_searchController.text}\' 에 대한 검색 결과가 없어요.',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ⭐️ [결과 있음]: ListView.builder를 반환하여 스크롤 가능하게 함
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return _buildProductCard(context, post);
      },
    );
  }
}