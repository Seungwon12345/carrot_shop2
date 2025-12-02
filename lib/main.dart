import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'screens/start_screen.dart';
import 'constants/colors.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';

// [1] 추가: 알림 서비스 파일 임포트
import 'services/notification_service.dart';

// ⭐️ [핵심 추가 1] 날짜/시간 로케일 처리를 위한 임포트
import 'package:intl/date_symbol_data_local.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐️ [핵심 추가 2] 로케일 데이터 초기화 (LocaleDataException 해결)
  // 'ko'는 한국어 로케일을 의미합니다. ChatRoomScreen의 시간 표시 오류를 해결합니다.
  await initializeDateFormatting('ko', null);

  // 1. Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: '57c198cdb5784eb2f9645b9f0ef92c1d');

  // 3. 네이버 등 기타 서비스 초기화
  await AuthService.initializeSdk();

  // -----------------------------------------------------------
  // [2] 추가: 알림 기능 초기화 (앱 실행 시 필수!)
  // -----------------------------------------------------------
  await NotificationService().init();
  // -----------------------------------------------------------

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '당근마켓',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const StartScreen(),
    );
  }
}