// lib/screens/post_write_screen.dart (지도 기능 통합, 나눔하기 제거 최종 버전)

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ 필수 서비스 및 모델 임포트
import '../models/item_model.dart';
import '../services/firebase_storage_service.dart';
import '../services/firestore_service.dart';
// 🚀 [추가] 지도 선택 화면 import
import 'map_selection_screen.dart';

class PostWriteScreen extends StatefulWidget {
  final String userLocation; // 현재 사용자 동네 (예: 충남 천안시 서북구 두정동)
  final String userId;
  final ItemModel? editingPost;

  const PostWriteScreen({
    super.key,
    required this.userLocation,
    required this.userId,
    this.editingPost,
  });

  @override
  State<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends State<PostWriteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();

  List<File> _selectedImages = [];
  List<String> _existingImageUrls = [];
  // 🚨 [수정]: 나눔 기능을 제거하므로, _isSelling 변수는 더 이상 필요 없습니다.
  // bool _isSelling = true;
  String _selectedCategory = '디지털기기';
  bool _isPriceSuggestionAllowed = false;

  bool _isLoading = false;

  // 🚀 [추가]: 사용자가 지도에서 직접 설정한 상세 거래 장소 정보 저장 변수
  Map<String, dynamic>? _selectedTradeLocation;

  final List<String> _categories = [
    '디지털기기', '생활가전', '가구/인테리어', '생활/가공식품', '유아동', '스포츠/레저', '의류', '도서', '기타'
  ];

  @override
  void initState() {
    super.initState();
    _initializeFieldsForEditing();
  }

  // 수정 모드일 때 필드를 기존 데이터로 채웁니다.
  void _initializeFieldsForEditing() {
    if (widget.editingPost != null) {
      final post = widget.editingPost!;
      _titleController.text = post.title;
      _contentController.text = post.content;
      _priceController.text = post.price > 0 ? post.price.toString() : '';

      // 🚨 [수정]: 나눔 로직 제거. 가격이 0 이상이면 그대로 표시.
      // _isSelling = post.status == '판매중' || post.price > 0;
      _selectedCategory = post.category;
      _existingImageUrls = List.from(post.imageUrls);

      // 🚀 [추가]: 수정 모드 시 기존 상세 위치 정보 로드
      _selectedTradeLocation = post.tradeLocationDetail;
    }
  }

  // 1. 이미지 선택 함수
  Future<void> _pickImage() async {
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

  // 🚀 [새 함수]: 지도 기반 위치 선택 처리 및 결과 저장
  Future<void> _handleLocationSelection() async {
    final Map<String, dynamic>? selectedData = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapSelectionScreen()),
    );

    if (selectedData != null) {
      setState(() {
        _selectedTradeLocation = selectedData;
      });
      _showSnackbar('거래 희망 장소가 설정되었습니다.', success: true);
    }
  }


  // 2. 게시글 작성/수정 완료 처리 (Firebase 연동 핵심 로직)
  Future<void> _handleSubmit() async {
    // 1차 입력 검증
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      _showSnackbar('제목과 내용을 입력해주세요.', success: false);
      return;
    }
    // 🚨 [수정]: 가격 입력은 판매에서 필수가 됩니다. (나눔 제거)
    if (_priceController.text.isEmpty) {
      _showSnackbar('가격을 입력해주세요.', success: false);
      return;
    }
    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      _showSnackbar('최소 한 장의 사진을 등록해주세요.', success: false);
      return;
    }
    // 🚀 [추가]: 거래 희망 장소 설정 여부 검증
    if (_selectedTradeLocation == null) {
      _showSnackbar('거래 희망 장소를 지도에서 설정해주세요.', success: false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String itemId = widget.editingPost?.id ?? FirebaseFirestore.instance.collection('items').doc().id;

      // 2. 이미지 업로드 (Firebase Storage)
      final List<String> newImageUrls = await FirebaseStorageService.uploadMultipleImages(
        _selectedImages,
        itemId,
      );
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
        // 🚨 [수정]: status를 무조건 '판매중'으로 설정합니다.
        status: '판매중',
        createdAt: isEditing ? widget.editingPost!.createdAt : Timestamp.now(),
        // 🚀 [추가]: 상세 거래 위치 정보 저장
        tradeLocationDetail: _selectedTradeLocation,
      );

      // 4. Firestore에 데이터 저장/업데이트
      await FirestoreService.saveItemToFirestore(newItem);

      final message = isEditing ? '게시글 수정이 완료되었습니다!' : '게시글 등록이 완료되었습니다!';
      _showSnackbar(message, success: true);

      if (mounted) {
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

  // 기존 이미지 삭제 처리
  void _removeExistingImage(String url) {
    setState(() {
      _existingImageUrls.remove(url);
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
          _buildFloatingSubmitButton(isEditing),
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
                  Text('${_selectedImages.length + _existingImageUrls.length}/10',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 기존 이미지 미리보기 (수정 모드)
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
                    onTap: () => _removeExistingImage(url),
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
        // 🚨 [수정]: 판매하기/나눔하기 ChoiceChip 제거 (항상 판매 모드)
        // 가격 입력 필드
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            // 🚨 [수정]: 항상 활성화
            enabled: true,
            decoration: const InputDecoration(
              // 🚨 [수정]: 나눔 문구 제거
              hintText: '₩ 가격을 입력해주세요.',
              border: InputBorder.none,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () {},
        ),

        // 🚨 [수정]: 항상 표시
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
    // 🚀 [추가]: 상세 주소를 표시하기 위한 텍스트
    final String displayLocation = _selectedTradeLocation != null
        ? _selectedTradeLocation!['address'] as String
        : widget.userLocation;

    // 🚀 [추가]: 사용자에게 장소를 설정하라는 힌트
    final String hintText = _selectedTradeLocation != null
        ? '거래 희망 상세 장소'
        : '거래 희망 장소를 지도에서 설정해 주세요.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('거래 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(hintText),
          // 🚀 [수정]: 상세 위치 또는 사용자 동네 표시
          subtitle: Text(
            displayLocation,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          // 🚀 [수정]: 클릭 시 지도 선택 함수 호출
          onTap: _handleLocationSelection,
        ),
      ],
    );
  }

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