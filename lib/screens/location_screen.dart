// lib/screens/location_screen.dart (천안시 전체 행정동 포함)

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../services/storage_service.dart';
import '../models/user_model.dart';
import 'home_screen.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String _currentLocation = '';
  bool _isLoadingLocation = false;
  final TextEditingController _searchController = TextEditingController();

  // ⭐️ 천안시 전체 행정동 리스트 (28개)
  final List<Map<String, String>> _cheonanDongList = [
    // 서북구 (14개)
    {'name': '성환읍', 'gu': '서북구'},
    {'name': '성거읍', 'gu': '서북구'},
    {'name': '직산읍', 'gu': '서북구'},
    {'name': '입장면', 'gu': '서북구'},
    {'name': '성정1동', 'gu': '서북구'},
    {'name': '성정2동', 'gu': '서북구'},
    {'name': '쌍용1동', 'gu': '서북구'},
    {'name': '쌍용2동', 'gu': '서북구'},
    {'name': '쌍용3동', 'gu': '서북구'},
    {'name': '백석동', 'gu': '서북구'},
    {'name': '불당1동', 'gu': '서북구'},
    {'name': '불당2동', 'gu': '서북구'},
    {'name': '부성1동', 'gu': '서북구'},
    {'name': '부성2동', 'gu': '서북구'},

    // 동남구 (17개)
    {'name': '목천읍', 'gu': '동남구'},
    {'name': '풍세면', 'gu': '동남구'},
    {'name': '광덕면', 'gu': '동남구'},
    {'name': '북면', 'gu': '동남구'},
    {'name': '성남면', 'gu': '동남구'},
    {'name': '수신면', 'gu': '동남구'},
    {'name': '병천면', 'gu': '동남구'},
    {'name': '동면', 'gu': '동남구'},
    {'name': '중앙동', 'gu': '동남구'},
    {'name': '문성동', 'gu': '동남구'},
    {'name': '원성1동', 'gu': '동남구'},
    {'name': '원성2동', 'gu': '동남구'},
    {'name': '봉명동', 'gu': '동남구'},
    {'name': '일봉동', 'gu': '동남구'},
    {'name': '신방동', 'gu': '동남구'},
    {'name': '청룡동', 'gu': '동남구'},
    {'name': '신부동', 'gu': '동남구'},
    {'name': '안서동', 'gu': '동남구'},
  ];

  List<Map<String, String>> _filteredDongList = [];

  @override
  void initState() {
    super.initState();
    _filteredDongList = _cheonanDongList;
    _searchController.addListener(_filterDongList);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterDongList);
    _searchController.dispose();
    super.dispose();
  }

  void _filterDongList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDongList = _cheonanDongList;
      } else {
        _filteredDongList = _cheonanDongList.where((dong) {
          return dong['name']!.contains(query) ||
              dong['gu']!.contains(query);
        }).toList();
      }
    });
  }

  void _selectDong(String dongName, String gu) {
    final fullAddress = '충청남도 천안시 $gu $dongName';
    setState(() {
      _currentLocation = fullAddress;
    });

    StorageService.saveLocation(fullAddress);
    _showSnackBar('$dongName이(가) 선택되었습니다.');
    _searchController.clear();
  }

  // ⭐️ GPS 좌표로 가장 가까운 동을 찾는 함수 (전체 동 좌표 포함)
  String _findNearestDong(double latitude, double longitude) {
    final Map<String, Map<String, dynamic>> dongCoordinates = {
      // [서북구]
      '성환읍': {'lat': 36.9160, 'lng': 127.1310, 'gu': '서북구'},
      '성거읍': {'lat': 36.8830, 'lng': 127.1630, 'gu': '서북구'},
      '직산읍': {'lat': 36.8910, 'lng': 127.1260, 'gu': '서북구'},
      '입장면': {'lat': 36.9200, 'lng': 127.2180, 'gu': '서북구'},
      '성정1동': {'lat': 36.8150, 'lng': 127.1450, 'gu': '서북구'},
      '성정2동': {'lat': 36.8250, 'lng': 127.1420, 'gu': '서북구'},
      '쌍용1동': {'lat': 36.8000, 'lng': 127.1250, 'gu': '서북구'},
      '쌍용2동': {'lat': 36.7950, 'lng': 127.1200, 'gu': '서북구'},
      '쌍용3동': {'lat': 36.7900, 'lng': 127.1150, 'gu': '서북구'},
      '백석동': {'lat': 36.8300, 'lng': 127.1250, 'gu': '서북구'},
      '불당1동': {'lat': 36.8050, 'lng': 127.1100, 'gu': '서북구'},
      '불당2동': {'lat': 36.8150, 'lng': 127.1050, 'gu': '서북구'},
      '부성1동': {'lat': 36.8450, 'lng': 127.1350, 'gu': '서북구'},
      '부성2동': {'lat': 36.8500, 'lng': 127.1250, 'gu': '서북구'},

      // [동남구]
      '목천읍': {'lat': 36.7620, 'lng': 127.2110, 'gu': '동남구'},
      '풍세면': {'lat': 36.7200, 'lng': 127.1100, 'gu': '동남구'},
      '광덕면': {'lat': 36.6700, 'lng': 127.0600, 'gu': '동남구'},
      '북면': {'lat': 36.8300, 'lng': 127.2400, 'gu': '동남구'},
      '성남면': {'lat': 36.7600, 'lng': 127.2400, 'gu': '동남구'},
      '수신면': {'lat': 36.7500, 'lng': 127.3000, 'gu': '동남구'},
      '병천면': {'lat': 36.7630, 'lng': 127.3320, 'gu': '동남구'},
      '동면': {'lat': 36.7800, 'lng': 127.3800, 'gu': '동남구'},
      '중앙동': {'lat': 36.8040, 'lng': 127.1550, 'gu': '동남구'},
      '문성동': {'lat': 36.8100, 'lng': 127.1580, 'gu': '동남구'},
      '원성1동': {'lat': 36.8080, 'lng': 127.1650, 'gu': '동남구'},
      '원성2동': {'lat': 36.8050, 'lng': 127.1600, 'gu': '동남구'},
      '봉명동': {'lat': 36.8050, 'lng': 127.1400, 'gu': '동남구'},
      '일봉동': {'lat': 36.7950, 'lng': 127.1400, 'gu': '동남구'},
      '신방동': {'lat': 36.7850, 'lng': 127.1300, 'gu': '동남구'},
      '청룡동': {'lat': 36.7900, 'lng': 127.1650, 'gu': '동남구'},
      '신부동': {'lat': 36.8185, 'lng': 127.1565, 'gu': '동남구'},
      '안서동': {'lat': 36.8330, 'lng': 127.1800, 'gu': '동남구'},

    };

    String nearestDong = '안서동';
    String nearestGu = '동남구';
    double minDistance = double.infinity;

    dongCoordinates.forEach((dongName, coords) {
      double distance = _calculateDistance(
          latitude, longitude,
          coords['lat']!, coords['lng']!
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestDong = dongName;
        nearestGu = coords['gu']!;
      }
    });

    print('📍 가장 가까운 동: $nearestDong ($nearestGu) - ${minDistance.toStringAsFixed(2)}km');
    return '충청남도 천안시 $nearestGu $nearestDong';
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('위치 서비스가 비활성화되어 있습니다.', isError: true);
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('위치 권한이 거부되었습니다.', isError: true);
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('위치 권한이 영구적으로 거부되었습니다.', isError: true);
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('📍 GPS 좌표: ${position.latitude}, ${position.longitude}');

      String fullAddress = _findNearestDong(position.latitude, position.longitude);

      setState(() {
        _currentLocation = fullAddress;
        _isLoadingLocation = false;
      });

      await StorageService.saveLocation(fullAddress);

      final dongName = fullAddress.split(' ').last;
      _showSnackBar('현재 위치: $dongName');

    } catch (e) {
      print('❌ 위치 가져오기 실패: $e');
      _showSnackBar('위치를 가져올 수 없습니다', isError: true);
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _completeLocationSetup() async {
    if (_currentLocation.isEmpty) {
      _showSnackBar('위치를 먼저 설정해주세요.', isError: true);
      return;
    }

    final UserModel? user = await StorageService.getUser();
    if (user == null) {
      _showSnackBar('사용자 정보를 불러올 수 없습니다.', isError: true);
      return;
    }

    if (!mounted) return;

    final dongName = _currentLocation.split(' ').last;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          selectedLocation: dongName,
          userId: user.id,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: isError ? 3 : 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('우리 동네를', style: TextStyle(fontSize: 24, color: Colors.black)),
            const Text('선택해주세요', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('지역을 설정하면 내 근처의 이웃과 거래할 수 있어요', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 40),

            if (_currentLocation.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_currentLocation, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '동명으로 검색 (ex. 안서동, 쌍용1동)',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () => _searchController.clear(),
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              ),
            ),

            const SizedBox(height: 10),

            if (_searchController.text.isNotEmpty && _filteredDongList.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredDongList.length,
                  itemBuilder: (context, index) {
                    final dong = _filteredDongList[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on, color: Colors.blue, size: 20),
                      title: Text(dong['name']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text('천안시 ${dong['gu']}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      onTap: () => _selectDong(dong['name']!, dong['gu']!),
                    );
                  },
                ),
              ),

            const SizedBox(height: 10),

            ListTile(
              leading: _isLoadingLocation
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.blue),
              title: Text(
                _isLoadingLocation ? '위치 정보 가져오는 중...' : '현재 위치로 설정',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              onTap: _isLoadingLocation ? null : _getCurrentLocation,
            ),

            const Divider(),
            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _currentLocation.isNotEmpty ? _completeLocationSetup : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
                  elevation: 0,
                ),
                child: Text(
                  _currentLocation.isNotEmpty ? '다음' : '위치를 먼저 설정해주세요',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _currentLocation.isNotEmpty ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}