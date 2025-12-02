import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import '../models/user_model.dart';
import 'storage_service.dart';
import 'firestore_service.dart';

class AuthService {
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static Future<void> initializeSdk() async {
    // 필요 시 초기화 코드
  }

  // ==========================================
  // 1. 이메일 회원가입
  // ==========================================
  static Future<AuthResult> signUpWithEmail(String email, String password, String nickname) async {
    try {
      UserCredential credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(nickname);

      final user = UserModel(
        id: credential.user!.uid,
        name: nickname,
        email: email,
        nickname: nickname,
        profileImage: '',
      );

      print('✅ Firebase Auth 회원가입 성공: ${user.id}');

      await FirestoreService.saveUserToFirestore(user);
      print('✅ Firestore에 사용자 정보 저장 완료');

      await _saveUserSession(user);

      return AuthResult.success(user: user);
    } on FirebaseAuthException catch (e) {
      String message = '회원가입 실패';
      if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 이메일입니다.';
      } else if (e.code == 'weak-password') {
        message = '비밀번호는 6자 이상이어야 합니다.';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다.';
      }
      print('❌ Firebase Auth 오류: ${e.code} - ${e.message}');
      return AuthResult.failure(message: message);
    } catch (e) {
      print('❌ 회원가입 오류: $e');
      return AuthResult.failure(message: '오류가 발생했습니다: $e');
    }
  }

  // ==========================================
  // 2. 이메일 로그인
  // ==========================================
  static Future<AuthResult> loginWithEmail(String email, String password) async {
    try {
      print('🔵 이메일 로그인 시도: $email');

      UserCredential credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Firebase Auth 로그인 성공: ${credential.user!.uid}');

      UserModel? user = await FirestoreService.getUserFromFirestore(credential.user!.uid);

      if (user == null) {
        print('⚠️ Firestore에 사용자 정보 없음. 새로 생성합니다.');
        user = UserModel(
          id: credential.user!.uid,
          name: credential.user!.displayName ?? '사용자',
          email: email,
          nickname: credential.user!.displayName ?? '사용자',
          profileImage: credential.user!.photoURL ?? '',
        );
        await FirestoreService.saveUserToFirestore(user);
      } else {
        print('✅ Firestore에서 사용자 정보 로드 완료');
      }

      await _saveUserSession(user);

      return AuthResult.success(user: user);
    } on FirebaseAuthException catch (e) {
      String message = '로그인 실패';
      if (e.code == 'user-not-found') {
        message = '존재하지 않는 계정입니다.';
      } else if (e.code == 'wrong-password') {
        message = '비밀번호가 올바르지 않습니다.';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다.';
      } else if (e.code == 'user-disabled') {
        message = '비활성화된 계정입니다.';
      } else {
        message = '이메일 또는 비밀번호를 확인해주세요.';
      }
      print('❌ Firebase Auth 로그인 오류: ${e.code} - ${e.message}');
      return AuthResult.failure(message: message);
    } catch (e) {
      print('❌ 로그인 오류: $e');
      return AuthResult.failure(message: '로그인 오류: $e');
    }
  }

  // ==========================================
  // 3. 구글 로그인
  // ==========================================
  static Future<AuthResult> googleLogin() async {
    try {
      print('🔵 구글 로그인 시작');

      await _googleSignIn.signOut();
      print('🔵 기존 구글 세션 정리 완료');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('⚠️ 구글 로그인 취소됨');
        return AuthResult.cancelled();
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        print('❌ Firebase 인증 실패');
        return AuthResult.failure(message: 'Firebase 인증 실패');
      }

      print('✅ 구글 로그인 성공: ${firebaseUser.uid}');

      final user = UserModel(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'Google User',
        email: firebaseUser.email ?? '',
        nickname: firebaseUser.displayName ?? 'Google User',
        profileImage: firebaseUser.photoURL ?? '',
      );

      await FirestoreService.saveUserToFirestore(user);
      print('✅ Firestore 저장 완료');

      await _saveUserSession(user);
      return AuthResult.success(user: user);
    } catch (e) {
      print('❌ 구글 로그인 실패: $e');
      return AuthResult.failure(message: '구글 로그인 실패: $e');
    }
  }

  // ==========================================
  // 4. 카카오 로그인
  // ==========================================
  static Future<AuthResult> kakaoLogin() async {
    try {
      print('🔵 카카오 로그인 시작');

      try {
        await kakao.UserApi.instance.logout();
        print('🔵 기존 카카오 세션 정리 완료');
      } catch (e) {
        print('⚠️ 카카오 세션 정리 실패 (기존 세션 없음): $e');
      }

      kakao.OAuthToken token;
      if (await kakao.isKakaoTalkInstalled()) {
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          if (error is PlatformException && error.code == 'CANCELED') {
            print('⚠️ 카카오 로그인 취소됨');
            return AuthResult.cancelled();
          }
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      kakao.User kakaoUser = await kakao.UserApi.instance.me();
      print('✅ 카카오 로그인 성공: ${kakaoUser.id}');

      final user = UserModel(
        id: 'kakao_${kakaoUser.id}',
        name: kakaoUser.kakaoAccount?.profile?.nickname ?? 'Kakao User',
        email: kakaoUser.kakaoAccount?.email ?? '',
        nickname: kakaoUser.kakaoAccount?.profile?.nickname ?? 'Kakao User',
        profileImage: kakaoUser.kakaoAccount?.profile?.profileImageUrl ?? '',
      );

      await FirestoreService.saveUserToFirestore(user);
      print('✅ Firestore 저장 완료');

      await _saveUserSession(user);
      return AuthResult.success(user: user);

    } catch (e) {
      if (e is PlatformException && e.code == 'CANCELED') {
        print('⚠️ 카카오 로그인 취소됨');
        return AuthResult.cancelled();
      }
      print('❌ 카카오 로그인 실패: $e');
      return AuthResult.failure(message: '카카오 로그인 실패: $e');
    }
  }

  // ==========================================
  // 5. 네이버 로그인 (v2.1.1 실제 API) ⭐️
  // ==========================================
  static Future<AuthResult> naverLogin() async {
    try {
      print('🔵 [Naver v2.1.1] 로그인 시작');

      // 1. 기존 세션 완전 정리
      try {
        await FlutterNaverLogin.logOutAndDeleteToken();
        print('🔵 [Naver] 기존 세션 삭제 완료');
      } catch (e) {
        print('⚠️ [Naver] 세션 정리 실패 (무시): $e');
      }

      // 2. 추가 대기 시간
      await Future.delayed(const Duration(milliseconds: 500));
      print('🔵 [Naver] 세션 정리 대기 완료');

      // 3. ⭐️ v2.1.1 실제 API 호출
      print('🔵 [Naver] logIn() 호출');
      final result = await FlutterNaverLogin.logIn();

      print('🔵 [Naver] 응답 받음');
      print('   - result.account: ${result.account}');
      print('   - result.errorMessage: ${result.errorMessage}');

      // 4. ⭐️ v2.1.1에서는 result.account 방식 유지됨
      if (result.account != null) {
        final account = result.account!;

        print('✅ [Naver] 로그인 성공');
        print('   - ID: ${account.id}');
        print('   - Email: ${account.email}');
        print('   - Nickname: ${account.nickname}');
        print('   - Name: ${account.name}');

        final user = UserModel(
          id: 'naver_${account.id}',
          name: account.name ?? account.nickname ?? 'Naver User',
          email: account.email ?? '',
          nickname: account.nickname ?? 'Naver User',
          profileImage: account.profileImage ?? '',
        );

        print('🔵 [Naver] Firestore 저장 시작');
        await FirestoreService.saveUserToFirestore(user);
        print('✅ [Naver] Firestore 저장 완료');

        await _saveUserSession(user);
        return AuthResult.success(user: user);

      } else {
        print('❌ [Naver] 로그인 실패: account is null');
        print('   errorMessage: ${result.errorMessage}');

        // 취소 여부 확인
        if (result.errorMessage != null &&
            (result.errorMessage!.contains('cancel') ||
                result.errorMessage!.contains('취소') ||
                result.errorMessage!.toLowerCase().contains('user cancel'))) {
          return AuthResult.cancelled();
        }

        return AuthResult.failure(message: result.errorMessage ?? '네이버 로그인 실패');
      }

    } on PlatformException catch (e) {
      print('❌ [Naver] PlatformException: ${e.code}');
      print('   message: ${e.message}');
      print('   details: ${e.details}');

      if (e.code == 'CANCELED' || e.code == 'USER_CANCEL') {
        return AuthResult.cancelled();
      }

      return AuthResult.failure(message: '네이버 로그인 오류: ${e.message}');

    } catch (e, stackTrace) {
      print('❌ [Naver] Exception: $e');
      print('❌ [Naver] StackTrace: $stackTrace');
      return AuthResult.failure(message: '네이버 로그인 오류: $e');
    }
  }

  // ==========================================
  // 공통: 세션 저장 및 로그아웃
  // ==========================================
  static Future<void> _saveUserSession(UserModel user) async {
    await StorageService.saveUser(user);
    await StorageService.saveTokens(accessToken: 'dummy_token');
    print('✅ 로컬 세션 저장 완료');
  }

  static Future<void> logout() async {
    try {
      print('🔵 로그아웃 시작');

      await _firebaseAuth.signOut();

      try { await _googleSignIn.signOut(); } catch (e) { print('구글 로그아웃 실패: $e'); }
      try { await kakao.UserApi.instance.logout(); } catch (e) { print('카카오 로그아웃 실패: $e'); }
      try { await FlutterNaverLogin.logOutAndDeleteToken(); } catch (e) { print('네이버 로그아웃 실패: $e'); }

      await StorageService.clearAll();

      print('✅ 로그아웃 완료');
    } catch (e) {
      print('❌ 로그아웃 오류: $e');
    }
  }

  static Future<bool> isLoggedIn() => StorageService.isLoggedIn();
  static Future<UserModel?> getCurrentUser() => StorageService.getUser();
}

class AuthResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? message;
  final UserModel? user;

  AuthResult._({required this.isSuccess, required this.isCancelled, this.message, this.user});

  factory AuthResult.success({required UserModel user}) => AuthResult._(isSuccess: true, isCancelled: false, user: user);
  factory AuthResult.failure({required String message}) => AuthResult._(isSuccess: false, isCancelled: false, message: message);
  factory AuthResult.cancelled() => AuthResult._(isSuccess: false, isCancelled: true, message: '취소됨');
}