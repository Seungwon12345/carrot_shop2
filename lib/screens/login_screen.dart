import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'location_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // 이메일 로그인
  Future<void> _handleEmailLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService.loginWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.isSuccess && result.user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LocationScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '로그인 실패')),
        );
      }
    }
  }

  // 소셜 로그인
  Future<void> _handleSocialLogin(Future<AuthResult> Function() loginMethod) async {
    setState(() => _isLoading = true);
    final result = await loginMethod();
    if (mounted) {
      setState(() => _isLoading = false);
      if (result.isSuccess && result.user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LocationScreen()),
        );
      } else if (!result.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '로그인 실패')),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '천안마켓과 함께하는',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.normal, color: Colors.black),
            ),
            const Text(
              '안전한 중고거래',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 8),
            const Text(
              '우리 동네에서 따뜻한 거래를 시작해보세요',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // 이메일 입력
            const Text('이메일', style: TextStyle(fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: '이메일 입력',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 20),

            // 비밀번호 입력
            const Text('비밀번호', style: TextStyle(fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '비밀번호 입력',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              ),
              enabled: !_isLoading,
              onSubmitted: (_) => _handleEmailLogin(),
            ),
            const SizedBox(height: 40),

            // 로그인 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleEmailLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE3F2FD),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.blue,
                  ),
                )
                    : const Text(
                  '로그인',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 회원가입 / 비밀번호 찾기
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignUpScreen()),
                    );
                  },
                  child: const Text('회원가입', style: TextStyle(color: Colors.black54)),
                ),
                const Text('|', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('비밀번호 찾기 기능은 준비 중입니다')),
                    );
                  },
                  child: const Text('비밀번호 찾기', style: TextStyle(color: Colors.black54)),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 구분선
            const Center(
              child: Text(
                '또는',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),

            const SizedBox(height: 20),

            // 소셜 로그인 아이콘
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialIcon(
                  'assets/img/kakao_logo.png',
                  const Color(0xFFFEE500),
                      () => _handleSocialLogin(AuthService.kakaoLogin),
                  padding: 8.0,
                  fallbackIcon: Icons.chat_bubble,
                  fallbackIconColor: Colors.black87,
                ),
                const SizedBox(width: 20),
                _buildSocialIcon(
                  'assets/img/naver_logo.png',
                  Colors.white,
                      () => _handleSocialLogin(AuthService.naverLogin),
                  padding: 10.0,
                  borderColor: Colors.grey.shade300,
                  fallbackIcon: Icons.notifications,
                  fallbackIconColor: const Color(0xFF03C75A),
                ),
                const SizedBox(width: 20),
                _buildSocialIcon(
                  'assets/img/google_logo.png',
                  Colors.white,
                      () => _handleSocialLogin(AuthService.googleLogin),
                  borderColor: Colors.grey.shade300,
                  padding: 8.0,
                  fallbackIcon: Icons.g_mobiledata,
                  fallbackIconColor: Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon(
      String imagePath,
      Color color,
      VoidCallback onTap, {
        Color? borderColor,
        double padding = 8.0,
        required IconData fallbackIcon,
        required Color fallbackIconColor,
      }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(fallbackIcon, color: fallbackIconColor, size: 24);
            },
          ),
        ),
      ),
    );
  }
}