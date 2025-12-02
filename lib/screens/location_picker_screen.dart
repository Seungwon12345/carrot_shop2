import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/notification_service.dart';
import '../services/location_firebase_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final String chatRoomId;
  final String myUserId;
  final String otherUserId;
  final String otherUserName;

  const LocationPickerScreen({
    super.key,
    required this.chatRoomId,
    required this.myUserId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late GoogleMapController _mapController;
  final LocationFirebaseService _firebaseService = LocationFirebaseService();

  StreamSubscription<Position>? _positionStreamSubscription;

  Set<Marker> _markers = {};
  LatLng? _myLocation;
  LatLng? _otherLocation;

  bool _hasAlerted = false;
  final double _alertDistance = 30.0; // 실제 테스트 시 30~50m 권장

  // ⭐️ [수정 1] 파란 점 표시 여부를 제어할 변수 추가 (기본값 false)
  bool _isMyLocationEnabled = false;

  @override
  void initState() {
    super.initState();
    NotificationService().init();
    _startMyPositionTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

// lib/screens/location_picker_screen.dart 내부 함수 수정

  void _startMyPositionTracking() async {
    // 1. [수정] 권한 확인을 가장 먼저 합니다.
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 거부되었습니다.')),
          );
        }
        return;
      }
    }

    // 2. [핵심 수정] 권한이 있으면 무조건 파란 점을 켭니다! (GPS 켜짐 여부와 상관없이)
    if (mounted) {
      setState(() {
        _isMyLocationEnabled = true;
      });
    }

    // 3. 그 다음 GPS 서비스(스위치)가 켜져있는지 확인합니다.
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 꺼져 있으면 켜달라고 요청 (파란 점은 이미 켜진 상태임)
      await Geolocator.openLocationSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 공유를 위해 GPS를 켜주세요!')),
        );
      }
      // 여기서 리턴해도 파란 점은 살아있음
      return;
    }

    // 4. 위치 추적 스트림 시작
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {

      LatLng myLatLng = LatLng(position.latitude, position.longitude);
      _myLocation = myLatLng;

      _firebaseService.updateMyLocation(
          widget.chatRoomId,
          widget.myUserId,
          myLatLng
      );

      if (_otherLocation != null) {
        _checkProximity(_otherLocation!);
      }
    });
  }

  void _checkProximity(LatLng otherPos) {
    if (_myLocation == null) return;

    double distanceInMeters = Geolocator.distanceBetween(
      _myLocation!.latitude, _myLocation!.longitude,
      otherPos.latitude, otherPos.longitude,
    );

    if (distanceInMeters <= _alertDistance && !_hasAlerted) {
      NotificationService().showNotification(
        title: '만남 장소 도착 알림! 👋',
        body: '${widget.otherUserName}님이 가까이 계십니다! (약 ${distanceInMeters.toInt()}m)',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.otherUserName}님과 만남 가능 거리입니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() => _hasAlerted = true);

    } else if (distanceInMeters > _alertDistance + 50) {
      setState(() => _hasAlerted = false);
    }
  }

  void _updateOtherUserMarker(Map<String, dynamic> data) {
    if (data.containsKey('locations')) {
      var locations = data['locations'] as Map<String, dynamic>;

      if (locations.containsKey(widget.otherUserId)) {
        var otherLocData = locations[widget.otherUserId];

        double lat = (otherLocData['lat'] as num).toDouble();
        double lng = (otherLocData['lng'] as num).toDouble();
        LatLng otherLatLng = LatLng(lat, lng);

        _otherLocation = otherLatLng;
        _checkProximity(otherLatLng);

        setState(() {
          _markers = {
            Marker(
              markerId: MarkerId(widget.otherUserId),
              position: otherLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: InfoWindow(title: widget.otherUserName),
            ),
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.otherUserName}님과 위치 공유'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(36.8332, 127.1793),
              zoom: 15,
            ),
            markers: _markers,

            // ⭐️ [수정 3] 변수를 사용하여 권한 확인 후에만 true가 되도록 설정
            myLocationEnabled: _isMyLocationEnabled,

            myLocationButtonEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
          ),

          StreamBuilder<DocumentSnapshot>(
            stream: _firebaseService.getChatRoomStream(widget.chatRoomId),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateOtherUserMarker(snapshot.data!.data() as Map<String, dynamic>);
                });
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}