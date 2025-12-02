import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'dart:convert';

class StorageService {
  static const _storage = FlutterSecureStorage();

  // Keys
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserInfo = 'user_info';
  static const String _keyLocation = 'user_location'; // 위치 정보 추가

  // 토큰 저장
  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
  }

  // 토큰 가져오기
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  // 사용자 정보 저장
  static Future<void> saveUser(UserModel user) async {
    final userJson = json.encode(user.toJson());
    await _storage.write(key: _keyUserInfo, value: userJson);
  }

  // 사용자 정보 가져오기
  static Future<UserModel?> getUser() async {
    final userJson = await _storage.read(key: _keyUserInfo);
    if (userJson != null) {
      final userMap = json.decode(userJson);
      return UserModel.fromJson(userMap);
    }
    return null;
  }

  // 위치 정보 저장
  static Future<void> saveLocation(String location) async {
    await _storage.write(key: _keyLocation, value: location);
    print('✅ 위치 정보 저장: $location');
  }

  // 위치 정보 가져오기
  static Future<String?> getLocation() async {
    return await _storage.read(key: _keyLocation);
  }

  // 로그인 여부 확인
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  // 모든 데이터 삭제 (로그아웃)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // 특정 키 삭제
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}