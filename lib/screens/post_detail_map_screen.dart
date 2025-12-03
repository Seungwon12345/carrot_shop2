import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'; // 이 import는 대부분 불필요하므로 제거해도 됩니다.

class PostDetailMapWidget extends StatelessWidget {
  final Map<String, dynamic> tradeLocationDetail;

  const PostDetailMapWidget({super.key, required this.tradeLocationDetail});

  @override
  Widget build(BuildContext context) {
    // 1. 데이터 추출 및 유효성 검사
    final double? lat = tradeLocationDetail['latitude'] as double?;
    final double? lng = tradeLocationDetail['longitude'] as double?;
    final String address = tradeLocationDetail['address'] as String? ?? '거래 장소';

    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      // 데이터가 유효하지 않으면 아무것도 표시하지 않거나 오류 메시지를 표시합니다.
      return const SizedBox.shrink();
    }

    final LatLng location = LatLng(lat, lng);
    final CameraPosition initialPosition = CameraPosition(target: location, zoom: 16.0);
    // 2. 마커 정의
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('tradeLocation'),
        position: location,
        infoWindow: InfoWindow(title: address),
      ),
    };

    // 🚨 [수정]: PostDetailScreen에서 주소와 제목을 이미 표시하므로, 이 위젯에서는 지도만 렌더링합니다.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // 하단에 패딩을 주어 지도와 다음 요소 구분
      child: Container(
        // 🚨 [필수]: 지도가 렌더링되려면 명시적인 높이가 필요합니다.
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GoogleMap(
            // 🚨 [핵심]: GoogleMap 위젯 추가
            initialCameraPosition: initialPosition,
            markers: markers,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              // 필요하다면 컨트롤러 로직을 여기에 추가할 수 있습니다.
            },
          ),
        ),
      ),
    );
  }
}