// lib/screens/location_picker_screen.dart (locale 매개변수 제거 버전)

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;

  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(36.8329, 127.1856), // 천호지 주변
    zoom: 16,
  );

  LatLng? _currentPickedLocation;
  String _currentAddress = '위치 정보를 가져오는 중...';
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _determinePositionAndSetInitialLocation();
  }

  // 현재 위치 권한 요청 및 위치 가져오기 (생략)
  Future<void> _determinePositionAndSetInitialLocation() async {
    // ... (이전 코드 유지) ...
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('위치 서비스가 비활성화되어 있습니다. 활성화해주세요.', isError: true);
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('위치 권한이 거부되었습니다. 앱 설정에서 허용해주세요.', isError: true);
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 허용해주세요.', isError: true);
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final newCameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 16,
      );

      if (mounted) {
        setState(() {
          _initialCameraPosition = newCameraPosition;
          _currentPickedLocation = _initialCameraPosition.target;
        });
      }

      _updateAddress(_initialCameraPosition.target);

      if (_mapController != null) {
        _mapController?.animateCamera(CameraUpdate.newCameraPosition(_initialCameraPosition));
      }

    } catch (e) {
      _showSnackBar('현재 위치를 가져올 수 없습니다.', isError: true);

      _currentPickedLocation = _initialCameraPosition.target;
      _updateAddress(_initialCameraPosition.target);
    }
  }


  // 지도의 중앙 좌표로 주소 업데이트
  void _updateAddress(LatLng position) async {
    if (!mounted) return;
    setState(() {
      _isLoadingAddress = true;
      _currentPickedLocation = position;
    });

    try {
      List<geocoding.Placemark> placemarks =
      await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        // ❌ [최종 수정]: 'locale' 매개변수를 완전히 제거합니다.
      );

      if (mounted) {
        setState(() {
          _currentAddress = placemarks.isNotEmpty
              ? '${placemarks.first.street ?? ''} ${placemarks.first.name ?? ''}'
              : '주소를 찾을 수 없음';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = '주소 조회 실패';
          _isLoadingAddress = false;
        });
      }
      print('주소 조회 실패: $e');
    }
  }

  // 스낵바 표시 헬퍼 (생략)
  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.grey[800],
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장소 공유', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          // 1. Google 지도 위젯
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _updateAddress(_initialCameraPosition.target);
            },
            onCameraMove: (CameraPosition position) {
              _currentPickedLocation = position.target;
            },
            onCameraIdle: () {
              if (_currentPickedLocation != null) {
                _updateAddress(_currentPickedLocation!);
              }
            },
            mapType: MapType.normal,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
          ),

          // 2. 중앙에 고정된 마커 아이콘
          const Center(
            child: Icon(Icons.location_on, color: Colors.orange, size: 48),
          ),

          // 3. 현재 위치로 이동 버튼
          Positioned(
            bottom: 120,
            right: 16,
            child: FloatingActionButton(
              onPressed: _determinePositionAndSetInitialLocation,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              mini: true,
              child: const Icon(Icons.my_location),
            ),
          ),

          // 4. 하단 주소 표시 및 '이 장소 공유하기' 버튼
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 주소 표시
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isLoadingAddress
                            ? const LinearProgressIndicator(color: Colors.orange)
                            : Text(
                          _currentAddress,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // '이 장소 공유하기' 버튼
                  ElevatedButton(
                    onPressed: _currentPickedLocation == null || _isLoadingAddress
                        ? null
                        : () {
                      Navigator.pop(context, {
                        'latitude': _currentPickedLocation!.latitude,
                        'longitude': _currentPickedLocation!.longitude,
                        'address': _currentAddress,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '이 장소 공유하기',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}