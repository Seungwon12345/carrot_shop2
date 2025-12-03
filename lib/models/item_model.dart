// lib/models/item_model.dart (최종 수정)

import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String id;
  final String userId;
  final String title;
  final String content;
  final int price;
  final String category;
  final List<String> imageUrls;
  final String location;
  final String status;
  final Timestamp createdAt;
  // 🚀 [추가]: 상세 거래 위치 정보 필드 정의 (Map<String, dynamic> 타입)
  final Map<String, dynamic>? tradeLocationDetail;

  ItemModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.price,
    required this.category,
    required this.imageUrls,
    required this.location,
    this.status = '판매중',
    required this.createdAt,
    // 🚀 [추가]: 생성자에 필드 추가 (선택적 매개변수)
    this.tradeLocationDetail,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      price: (json['price'] ?? 0) is int
          ? json['price']
          : int.tryParse(json['price'].toString().replaceAll(',', '')) ?? 0,
      category: json['category'] ?? '기타',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      location: json['location'] ?? '위치 미지정',
      status: json['status'] ?? '판매중',
      createdAt: json['createdAt'] ?? Timestamp.now(),

      // 🚀 [추가]: Firestore에서 읽어오는 로직 추가
      // 해당 필드가 없을 경우(null)를 대비하여 안전하게 처리
      tradeLocationDetail: json['tradeLocationDetail'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'price': price,
      'category': category,
      'imageUrls': imageUrls,
      'location': location,
      'status': status,
      'createdAt': createdAt,

      // 🚀 [추가]: Firestore에 저장하는 로직 추가
      // null 값도 저장할 수 있도록 합니다.
      'tradeLocationDetail': tradeLocationDetail,
    };
  }
}