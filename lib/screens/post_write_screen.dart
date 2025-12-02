import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ 필수 서비스 및 모델 임포트
import '../models/item_model.dart';
import '../services/firebase_storage_service.dart';
import '../services/firestore_service.dart';

class PostWriteScreen extends StatefulWidget {
  final String userLocation; // 현재 사용자 동네 (예: 충남 천안시 서북구 두정동)
  final String userId;       // 💡 현재 로그인된 사용자 ID (판매자 등록용)
  final ItemModel? editingPost; // ⭐️ [추가] 수정할 기존 게시글 데이터

  const PostWriteScreen({
    super.key,
    required this.userLocation,
    required this.userId,
    this.editingPost, // ⭐️ [추가] 생성자 매개변수로 받도록 정의
  });

  @override
  State<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends State<PostWriteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();

  List<File> _selectedImages = [];
  List<String> _existingImageUrls = []; // 기존 이미지 URL 저장
  bool _isSelling = true; // 판매하기(true) vs 나누기(false)
  String _selectedCategory = '디지털기기'; // 기본 카테고리
  bool _isPriceSuggestionAllowed = false;

  bool _isLoading = false;

  final List<String> _categories = [
    '디지털기기', '생활가전', '가구/인테리어', '생활/가공식품', '유아동', '스포츠/레저', '의류', '도서', '기타'
  ];

  @override
  void initState() {
    super.initState();
    _initializeFieldsForEditing(); // ⭐️ [추가] 수정 모드 초기화 함수 호출
  }

  // ⭐️ [새 함수]: 수정 모드일 때 필드를 기존 데이터로 채웁니다.
  void _initializeFieldsForEditing() {
    if (widget.editingPost != null) {
      final post = widget.editingPost!;
      _titleController.text = post.title;
      _contentController.text = post.content;
      _priceController.text = post.price > 0 ? post.price.toString() : '';

      _isSelling = post.status == '판매중' || post.price > 0;
      _selectedCategory = post.category;
      _existingImageUrls = List.from(post.imageUrls);
    }
  }

  // 1. 이미지 선택 함수
  Future<void> _pickImage() async {
    // ⭐️ [수정]: 기존 이미지와 새 이미지를 합쳐서 최대 개수를 체크합니다.
    if (_selectedImages.length + _existingImageUrls.length >= 10) {
      _showSnackbar('사진은 최대 10장까지 등록할 수 있습니다.', success: false);
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }

  // 2. 게시글 작성/수정 완료 처리 (Firebase 연동 핵심 로직)
  Future<void> _handleSubmit() async {
    // 1차 입력 검증
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      _showSnackbar('제목과 내용을 입력해주세요.', success: false);
      return;
    }
    if (_isSelling && _priceController.text.isEmpty) {
      _showSnackbar('가격을 입력해주세요.', success: false);
      return;
    }
    // ⭐️ [수정]: 기존 이미지 또는 새로 선택된 이미지가 하나라도 있어야 합니다.
    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      _showSnackbar('최소 한 장의 사진을 등록해주세요.', success: false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ⭐️ [수정]: 수정 모드면 기존 ID 사용, 아니면 새 ID 생성
      final String itemId = widget.editingPost?.id ?? FirebaseFirestore.instance.collection('items').doc().id;

      // 2. 이미지 업로드 (Firebase Storage)
      final List<String> newImageUrls = await FirebaseStorageService.uploadMultipleImages(
        _selectedImages,
        itemId,
      );
      // ⭐️ [수정]: 기존 이미지 URL과 새로 업로드된 URL을 합칩니다.
      final List<String> finalImageUrls = List.from(_existingImageUrls)..addAll(newImageUrls);

      // 3. ItemModel 생성
      final priceInt = int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
      final locationParts = widget.userLocation.split(' ');
      final townName = locationParts.isNotEmpty ? locationParts.last : '미지정';
      final isEditing = widget.editingPost != null;

      final newItem = ItemModel(
        id: itemId,
        userId: widget.userId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        price: priceInt,
        category: _selectedCategory,
        imageUrls: finalImageUrls,
        location: townName,
        status: _isSelling && priceInt > 0 ? '판매중' : '나눔',
        // ⭐️ [수정]: 수정 시 기존 시간 유지, 새 작성 시 Timestamp.now()
        createdAt: isEditing ? widget.editingPost!.createdAt : Timestamp.now(),
      );

      // 4. Firestore에 데이터 저장/업데이트
      await FirestoreService.saveItemToFirestore(newItem);

      final message = isEditing ? '게시글 수정이 완료되었습니다!' : '게시글 등록이 완료되었습니다!';
      _showSnackbar(message, success: true);

      if (mounted) {
        // ⭐️ [수정]: 수정 완료 시 true를 반환하여 이전 화면(MyPostsScreen)에 성공을 알립니다.
        Navigator.pop(context, true);
      }

    } catch (e) {
      print('게시글 처리 오류: $e');
      _showSnackbar('게시글 처리 중 오류가 발생했습니다: $e', success: false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ⭐️ [새 함수]: 기존 이미지 삭제 처리
  void _removeExistingImage(String url) {
    setState(() {
      _existingImageUrls.remove(url);
      // Note: Firebase Storage에서 파일 자체를 삭제하는 로직은 여기서는 생략합니다.
      // (게시글 ID와 함께 나중에 일괄적으로 정리하는 것이 일반적입니다.)
    });
  }

  void _showSnackbar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _showCategoryPickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('카테고리 선택'),
          contentPadding: const EdgeInsets.only(top: 12.0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _categories.map((category) {
                return ListTile(
                  title: Text(category),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingPost != null;

    return Scaffold(
      appBar: AppBar(
        // ⭐️ [수정]: AppBar 제목 변경
        title: Text(isEditing ? '게시글 수정' : '내 물건 팔기', style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: () { /* 임시 저장 로직 */ },
            child: const Text('임시저장', style: TextStyle(color: Colors.black)),
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 1. 이미지 선택 위젯
                _buildImagePicker(),
                const Divider(),

                // 2. 제목 입력
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: '제목을 입력하세요',
                    border: InputBorder.none,
                  ),
                  maxLength: 50,
                ),
                const Divider(),

                // 3. 카테고리 선택
                _buildCategorySelector(),
                const Divider(),

                // 4. 내용 입력
                TextField(
                  controller: _contentController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: '게시글 내용을 작성해주세요.',
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),

                // 5. 가격 입력 섹션
                _buildPriceSection(),
                const Divider(),

                // 6. 거래 정보
                _buildTradeInfoSection(),

                const SizedBox(height: 100),
              ],
            ),
          ),
          // 7. 하단 "작성 완료" 버튼
          _buildFloatingSubmitButton(isEditing), // ⭐️ [수정]: isEditing 상태 전달
          // 로딩 오버레이
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // UI 헬퍼 함수들 -------------------------------------

  Widget _buildImagePicker() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // '사진 추가' 버튼
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, color: Colors.grey),
                  // ⭐️ [수정]: 기존 이미지 개수 포함하여 표시
                  Text('${_selectedImages.length + _existingImageUrls.length}/10',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ⭐️ [추가]: 기존 이미지 미리보기 (수정 모드)
          ..._existingImageUrls.map((url) => Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _removeExistingImage(url), // ⭐️ [수정]: 기존 이미지 삭제 함수 호출
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                )
              ],
            ),
          )).toList(),

          // 선택된 새 이미지 미리보기
          ..._selectedImages.map((file) => Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    file,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImages.remove(file);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                )
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }


  Widget _buildCategorySelector() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_selectedCategory, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: _showCategoryPickerDialog,
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 판매하기 / 나누기 버튼
            ChoiceChip(
              label: const Text('판매하기'),
              selected: _isSelling,
              onSelected: (selected) {
                setState(() => _isSelling = selected);
              },
              selectedColor: Colors.grey.shade900,
              labelStyle: TextStyle(color: _isSelling ? Colors.white : Colors.black),
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('나눔하기'),
              selected: !_isSelling,
              onSelected: (selected) {
                setState(() {
                  _isSelling = !selected;
                  if (!_isSelling) _priceController.clear();
                });
              },
              selectedColor: Colors.grey.shade900,
              labelStyle: TextStyle(color: !_isSelling ? Colors.white : Colors.black),
              backgroundColor: Colors.grey.shade200,
            ),
          ],
        ),

        // 가격 입력 필드
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            enabled: _isSelling,
            decoration: InputDecoration(
              hintText: _isSelling ? '₩ 가격을 입력해주세요.' : '나눔 물품',
              border: InputBorder.none,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () {},
        ),

        // 가격 제안 받기 체크박스
        if (_isSelling)
          Row(
            children: [
              Checkbox(
                value: _isPriceSuggestionAllowed,
                onChanged: (val) {
                  setState(() => _isPriceSuggestionAllowed = val ?? false);
                },
              ),
              const Text('가격 제안 받기'),
            ],
          ),
      ],
    );
  }

  Widget _buildTradeInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('거래 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('거래 희망 장소'),
          subtitle: Text(widget.userLocation), // 현재 사용자 위치 표시
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () {
            // TODO: 위치 추가/변경 화면으로 이동하는 로직 추가
          },
        ),
      ],
    );
  }

  // ⭐️ [수정]: isEditing 매개변수 추가
  Widget _buildFloatingSubmitButton(bool isEditing) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0),
              ),
            ),
            child: Text(
              // ⭐️ [수정]: 버튼 텍스트 변경
              _isLoading ? (isEditing ? '수정 중...' : '등록 중...') : (isEditing ? '수정 완료' : '작성 완료'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );
  }
}