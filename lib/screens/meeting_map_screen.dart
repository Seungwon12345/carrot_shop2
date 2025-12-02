import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/notification_service.dart';
import '../services/location_firebase_service.dart';

class MeetingMapScreen extends StatefulWidget {
  final String chatRoomId;    // 팀원 DB의 문서 ID (예: "mock_user_id_A_mock_user_id_B")
  final String myUserId;      // 내 ID (예: "mock_user_id_A")
  final String otherUserId;   // 상대방 ID (예: "mock_user_id_B")
  final String otherUserName; // 상대방 이름

  const MeetingMapScreen({
    super.key,
    required this.chatRoomId,
    required this.myUserId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<MeetingMapScreen> createState() => _MeetingMapScreenState();
}

class _MeetingMapScreenState extends State<MeetingMapScreen> {
  late GoogleMapController _mapController;
  final LocationFirebaseService _firebaseService = LocationFirebaseService();

  StreamSubscription<Position>? _positionStreamSubscription;
  Set<Marker> _markers = {};

  bool _hasAlerted = false; // 알림 중복 방지
  final double _alertDistance = 30.0; // 알림 거리 기준 (30m)

  // 상대방 위치 저장용
  LatLng? _otherUserLocation;

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 알림 서비스 초기화 (혹시 메인에서 안 됐을 경우 대비)
    NotificationService().init();
    _startMyPositionTracking();
  }

  @override
  void dispose() {
    // 화면 나가면 위치 추적 중단
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // 1. 내 위치 추적 및 DB 업로드 로직
  void _startMyPositionTracking() async {
    // 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10m 이동 시마다 업데이트 (배터리/데이터 절약)
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {

      LatLng myLatLng = LatLng(position.latitude, position.longitude);

      // A. 내 위치를 팀원 DB(chat_start)에 업로드
      _firebaseService.updateMyLocation(
          widget.chatRoomId,
          widget.myUserId,
          myLatLng
      );

      // B. 상대방 위치가 있다면 거리 계산
      if (_otherUserLocation != null) {
        _checkProximity(myLatLng, _otherUserLocation!);
      }
    });
  }

  // 2. 거리 계산 및 알림 로직
  void _checkProximity(LatLng myPos, LatLng otherPos) {
    double distanceInMeters = Geolocator.distanceBetween(
      myPos.latitude, myPos.longitude,
      otherPos.latitude, otherPos.longitude,
    );

    // 디버깅용 로그 (Run 탭에서 확인 가능)
    print('📍 상대방과의 거리: ${distanceInMeters.toStringAsFixed(1)}m');

    if (distanceInMeters <= _alertDistance && !_hasAlerted) {
      // 30m 이내 진입 시 알림 발송
      NotificationService().showNotification(
        title: '거래 장소 근처입니다!',
        body: '${widget.otherUserName}님이 ${_alertDistance.toInt()}m 이내에 있습니다.',
      );

      // 앱 내 스낵바 메시지도 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.otherUserName}님과 가까워졌어요!')),
        );
      }

      setState(() => _hasAlerted = true); // 알림 중복 방지 락 걸기
    } else if (distanceInMeters > _alertDistance) {
      // 다시 멀어지면 알림 락 풀기 (재진입 시 다시 알림)
      setState(() => _hasAlerted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.otherUserName}님 위치'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      // StreamBuilder: DB의 chat_start/{id} 문서를 실시간 감시
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firebaseService.getChatRoomStream(widget.chatRoomId),
        builder: (context, snapshot) {

          if (snapshot.hasError) {
            return const Center(child: Text('데이터 로드 오류'));
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            // DB 데이터 가져오기
            var data = snapshot.data!.data() as Map<String, dynamic>;

            // 'locations' 필드 확인 (팀원 DB에 우리가 추가한 필드)
            if (data.containsKey('locations')) {
              var locations = data['locations'] as Map<String, dynamic>;

              // 상대방 ID로 된 위치 데이터가 있는지 확인
              if (locations.containsKey(widget.otherUserId)) {
                var otherLocData = locations[widget.otherUserId];

                // 좌표 파싱
                LatLng otherLatLng = LatLng(
                    otherLocData['lat'],
                    otherLocData['lng']
                );

                _otherUserLocation = otherLatLng; // 거리 계산용 변수 업데이트

                // 지도에 마커 찍기
                _markers = {
                  Marker(
                    markerId: MarkerId(widget.otherUserId),
                    position: otherLatLng,
                    // 파란색 마커 (기본값 red와 구분)
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    infoWindow: InfoWindow(title: widget.otherUserName),
                  ),
                };
              }
            }
          }

          return GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(37.5665, 126.9780), // 초기 위치 (내 위치 잡히면 이동함)
              zoom: 15,
            ),
            markers: _markers,
            myLocationEnabled: true, // 내 위치 파란 점 표시
            myLocationButtonEnabled: true, // 내 위치로 이동 버튼
            onMapCreated: (controller) => _mapController = controller,
          );
        },
      ),
    );
  }
}