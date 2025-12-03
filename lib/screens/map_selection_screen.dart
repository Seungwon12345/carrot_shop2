// lib/screens/map_selection_screen.dart (오류 우회 버전)

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class MapSelectionScreen extends StatefulWidget {
  const MapSelectionScreen({super.key});

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780), // 서울 시청 기준
    zoom: 15.0,
  );

  GoogleMapController? _mapController;
  Marker? _selectedMarker;
  String _selectedAddress = "지도를 움직여 위치를 선택하세요.";
  // 🚀 [추가]: 카메라가 움직이는 동안의 최종 위치를 저장할 변수
  LatLng? _lastCameraTarget;

  @override
  void initState() {
    super.initState();

    _selectedMarker = Marker(
      markerId: const MarkerId('selected_location'),
      position: _initialCameraPosition.target,
      draggable: false,
    );
    _lastCameraTarget = _initialCameraPosition.target; // 초기 위치 저장
    _updateLocation(_initialCameraPosition.target);
  }

  // 좌표를 주소로 변환하고 상태를 업데이트하는 함수
  Future<void> _updateLocation(LatLng newPosition) async {
    setState(() {
      _selectedMarker = _selectedMarker!.copyWith(
        positionParam: newPosition,
      );
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        newPosition.latitude,
        newPosition.longitude,
        localeIdentifier: 'ko_KR',
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [place.street, place.subLocality, place.locality]
            .where((e) => e != null && e.isNotEmpty)
            .join(' ');

        setState(() {
          _selectedAddress = address.isEmpty ? '주소를 찾을 수 없습니다.' : address;
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = '주소 변환 실패';
      });
      print('Geocoding Error: $e');
    }
  }

  // 🚀 [수정]: 카메라가 움직일 때마다 위치를 _lastCameraTarget에 저장합니다.
  void _onCameraMove(CameraPosition position) {
    _lastCameraTarget = position.target;
  }

  // 🚀 [대체]: _mapController.getCameraPosition() 호출 없이, 저장된 위치 사용
  void _onCameraIdle() {
    if (_lastCameraTarget != null) {
      _updateLocation(_lastCameraTarget!);
    }
  }

  void _confirmSelection() {
    if (_selectedMarker != null && _selectedAddress != '주소 변환 실패') {
      final resultData = {
        'latitude': _selectedMarker!.position.latitude,
        'longitude': _selectedMarker!.position.longitude,
        'address': _selectedAddress,
      };
      Navigator.pop(context, resultData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 희망 장소 설정'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            markers: _selectedMarker != null ? {_selectedMarker!} : {},
            // 🚀 [추가]: 카메라 이동 감지
            onCameraMove: _onCameraMove,
            // 🚀 [변경]: 대체 함수 사용
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('선택된 위치', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_selectedAddress, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),

          const Center(
            child: Icon(Icons.location_on, color: Colors.orange, size: 40),
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedMarker != null && _selectedAddress != '주소 변환 실패'
                ? _confirmSelection
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('선택 완료', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}