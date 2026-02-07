  import 'package:flutter/material.dart';
  import 'package:flutter_map/flutter_map.dart';
  import 'package:latlong2/latlong.dart';
  import 'package:geolocator/geolocator.dart';

  void main() => runApp(const MyApp());

  class MyApp extends StatelessWidget {
    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'OSM Location Tracker',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: const MapScreen(),
      );
    }
  }

  class MapScreen extends StatefulWidget {
    const MapScreen({super.key});

    @override
    State<MapScreen> createState() => _MapScreenState();
  }

  class _MapScreenState extends State<MapScreen> {
    // ตัวควบคุมแผนที่ OSM
    late MapController _mapController;
    
    // พิกัดเริ่มต้น (กรุงเทพฯ)
    LatLng _currentPosition = const LatLng(13.7563, 100.5018);
    String? _errorMessage;
    bool _isLoading = true;
    double _accuracy = 0.0; // ความแม่นยำของตำแหน่ง
    
    // ตัวเลือกชั้นแผนที่
    String _currentMapLayer = 'openstreetmap'; // openstreetmap, satellite, dark
    
    // URL templates สำหรับแต่ละชั้นแผนที่
    final Map<String, String> _mapLayers = {
      'openstreetmap': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'satellite': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      'dark': 'https://tiles.stadiamaps.com/tiles/stamen_toner/{z}/{x}/{y}{r}.png',
    };

    @override
    void initState() {
      super.initState();
      _mapController = MapController();
      Future.delayed(const Duration(milliseconds: 500), () {
        _determinePosition();
      });
    }

    /// ฟังก์ชันสำหรับแปลงชื่อชั้นแผนที่เป็นตัวอักษรที่อ่านได้
    String _getMapLayerLabel(String layer) {
      switch (layer) {
        case 'openstreetmap':
          return 'OpenStreetMap';
        case 'satellite':
          return 'Satellite';
        case 'dark':
          return 'Dark Map';
        default:
          return 'Map';
      }
    }
    Future<void> _determinePosition() async {
      try {
        bool serviceEnabled;
        LocationPermission permission;

        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          setState(() {
            _errorMessage = 'Location services are disabled.';
            _isLoading = false;
          });
          return;
        }

        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            setState(() {
              _errorMessage = 'Location permissions are denied.';
              _isLoading = false;
            });
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          setState(() {
            _errorMessage = 'Location permissions are permanently denied.';
            _isLoading = false;
          });
          return;
        }

        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
            ),
        );


        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _accuracy = position.accuracy; // บันทึกค่าความแม่นยำ
            _isLoading = false;
            _errorMessage = null;
          });

          // เลื่อนแผนที่ไปยังตำแหน่งปัจจุบัน
          _mapController.move(_currentPosition, 15.0);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to get location: ${e.toString()}';
            _isLoading = false;
          });
        }
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('📍 OSM Location Tracker'),
          elevation: 4,
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // แผนที่
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition,
                initialZoom: 13.0,
              ),
              children: [
                // ชั้นของแผนที่ (ดึงจาก OSM หรือชั้นแผนที่อื่น)
                TileLayer(
                  urlTemplate: _mapLayers[_currentMapLayer]!,
                  userAgentPackageName: 'com.example.app',
                ),
                // ชั้นของวงกลมความแม่นยำ (Accuracy Circle)
                CircleLayer(
                  circles: [
                    if (_accuracy > 0)
                      CircleMarker(
                        point: _currentPosition,
                        radius: _accuracy, // รัศมีความแม่นยำจากตำแหน่ง (เมตร)
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 2.0,
                      ),
                  ],
                ),
                // ชั้นของหมุด (Markers)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition,
                      width: 80,
                      height: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Loading Indicator
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(strokeWidth: 4),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Getting your location...',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Error Message
            if (_errorMessage != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Card(
                  color: Colors.red.shade100,
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Location Info Card
            if (!_isLoading && _errorMessage == null)
              Positioned(
                bottom: 80,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Latitude: ${_currentPosition.latitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Longitude: ${_currentPosition.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Accuracy: ${_accuracy.toStringAsFixed(2)} m',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Map Layer Selector (ปุ่มเปลี่ยนชั้นแผนที่)
            Positioned(
              top: 16,
              right: 16,
              child: PopupMenuButton<String>(
                initialValue: _currentMapLayer,
                onSelected: (String value) {
                  setState(() {
                    _currentMapLayer = value;
                  });
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'openstreetmap',
                    child: Text('🗺️ OpenStreetMap'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'satellite',
                    child: Text('🛰️ Satellite'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'dark',
                    child: Text('🌙 Dark Map'),
                  ),
                ],
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _getMapLayerLabel(_currentMapLayer),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isLoading ? null : _determinePosition,
          icon: const Icon(Icons.my_location),
          label: const Text('Update Location'),
          elevation: 4,
        ),
      );
    }
  }
