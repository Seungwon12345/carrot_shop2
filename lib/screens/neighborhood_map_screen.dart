import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class NeighborhoodMapScreen extends StatefulWidget {
  const NeighborhoodMapScreen({super.key});

  @override
  State<NeighborhoodMapScreen> createState() => _NeighborhoodMapScreenState();
}

class _NeighborhoodMapScreenState extends State<NeighborhoodMapScreen> {
  // 지도 제어를 위한 컨트롤러
  final Completer<GoogleMapController> _controller = Completer();

  // 초기 카메라 위치 (천안시청 기준, 로딩 전 보여줄 위치)
  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(36.8151, 127.1139),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    // 화면이 시작되면 내 위치 권한을 확인하고 지도를 이동
    _checkPermissionAndMove();
  }

  Future<void> _checkPermissionAndMove() async {
    // 1. 위치 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // 권한 거부 시 처리 (스낵바 등)
        return;
      }
    }

    // 2. 현재 위치 가져오기
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      Position position = await Geolocator.getCurrentPosition();
      _moveCameraToPosition(position);
    }
  }

  // 지도를 특정 좌표로 이동시키는 함수
  Future<void> _moveCameraToPosition(Position position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 16, // 줌 레벨 (클수록 확대됨)
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '동네 지도',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kInitialPosition,

            // ✅ 핵심: 내 위치 파란 점 표시 기능
            myLocationEnabled: true,
            // 내 위치로 가는 기본 버튼 활성화 (우측 상단)
            myLocationButtonEnabled: false,
            // 줌 컨트롤 끄기 (깔끔하게)
            zoomControlsEnabled: false,

            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),

          // (선택 사항) 커스텀 '내 위치' 버튼 (하단 중앙 배치)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                onPressed: () async {
                  try {
                    Position position = await Geolocator.getCurrentPosition();
                    _moveCameraToPosition(position);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("위치를 찾을 수 없습니다.")),
                    );
                  }
                },
                backgroundColor: Colors.orange, // 당근마켓 색상
                label: const Text("내 위치 찾기"),
                icon: const Icon(Icons.my_location),
              ),
            ),
          ),
        ],
      ),
    );
  }
}