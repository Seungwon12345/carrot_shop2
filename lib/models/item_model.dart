import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String id;
  final String userId;       // 작성자 ID
  final String title;        // 제목
  final String content;      // 내용
  final int price;           // 가격
  final String category;     // 카테고리
  final List<String> imageUrls; // 이미지 URL 목록
  final String location;     // 거래 희망 장소/동네
  final String status;       // 거래 상태
  final Timestamp createdAt; // 작성 시간

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
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      // price를 안전하게 int로 변환
      price: (json['price'] ?? 0) is int ? json['price'] : int.tryParse(json['price'].toString().replaceAll(',', '')) ?? 0,
      category: json['category'] ?? '기타',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      location: json['location'] ?? '위치 미지정',
      status: json['status'] ?? '판매중',
      createdAt: json['createdAt'] ?? Timestamp.now(),
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
    };
  }
}