import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  runApp(const DriverTrackingApp());
}

class DriverTrackingApp extends StatelessWidget {
  const DriverTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DriverDashboardScreen(),
    );
  }
}

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const String _firebaseBaseUrl =
      "https://uni-bus-tracking-f0535-default-rtdb.firebaseio.com";
  static const String _busId = "bus_01";

  bool _isTripActive = false;
  StreamSubscription<Position>? _positionStreamSub;
  late final AnimationController _vibrationController;

  @override
  void initState() {
    super.initState();
    _vibrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _vibrationController.dispose();
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _triggerEngineFeedback() async {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    HapticFeedback.vibrate();
  }

  void _triggerStopFeedback() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
  }

  Future<bool> _handleLocationPermissions() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    return permission != LocationPermission.deniedForever;
  }

  Future<void> _pushCoordinates(Position pos) async {
    final endpoint = Uri.parse("$_firebaseBaseUrl/buses/$_busId.json");
    try {
      await http.patch(
        endpoint,
        body: jsonEncode({
          "lat": pos.latitude,
          "lng": pos.longitude,
          "status": "ACTIVE",
          "updatedAt": DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {
      // Network drops are ignored; stream handles subsequent coordinates
    }
  }

  Future<void> _startTracking() async {
    final hasPermission = await _handleLocationPermissions();
    if (!hasPermission) return;

    _triggerEngineFeedback();
    _vibrationController.repeat(reverse: true);
    await WakelockPlus.enable();

    final AndroidSettings androidSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      forceLocationManager: true,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "ইউনিভার্সিটি বাস ট্র্যাকার",
        notificationText: "বাসের লাইভ লোকেশন ব্যাকগ্রাউন্ডে শেয়ার হচ্ছে...",
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: androidSettings,
    ).listen(_pushCoordinates);

    setState(() => _isTripActive = true);
  }

  Future<void> _stopTracking() async {
    _triggerStopFeedback();
    _vibrationController.stop();
    await _positionStreamSub?.cancel();
    await WakelockPlus.disable();

    final endpoint = Uri.parse("$_firebaseBaseUrl/buses/$_busId.json");
    try {
      await http.patch(
        endpoint,
        body: jsonEncode({"status": "INACTIVE"}),
      );
    } catch (_) {}

    setState(() => _isTripActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isTripActive ? "বাস চালু আছে" : "ইউনিভার্সিটি বাস",
                style: TextStyle(
                  color: _isTripActive ? Colors.greenAccent : Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),

              // Bus illustration with engine jitter
              AnimatedBuilder(
                animation: _vibrationController,
                builder: (context, child) {
                  final double jitter = _isTripActive
                      ? sin(_vibrationController.value * pi * 2) * 1.5
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(0, jitter),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: _isTripActive ? _stopTracking : _startTracking,
                  child: Column(
                    children: [
                      Container(
                        width: 170,
                        height: 190,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2430),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(35),
                            topRight: Radius.circular(35),
                            bottomLeft: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                          border: Border.all(
                            color: _isTripActive
                                ? Colors.greenAccent.withOpacity(0.5)
                                : Colors.white24,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isTripActive
                                    ? Colors.green.shade900
                                    : Colors.black45,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "CAMPUS SPECIAL",
                                style: TextStyle(
                                  color: _isTripActive
                                      ? Colors.greenAccent
                                      : Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: 140,
                              height: 65,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A364F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white24,
                                size: 28,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 60,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildHeadlight(_isTripActive),
                                  _buildHeadlight(_isTripActive),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),

                      // Headlight beams
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _isTripActive ? 1.0 : 0.0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLightBeam(),
                            const SizedBox(width: 50),
                            _buildLightBeam(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 35),

              // Action Trigger Button
              SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTripActive
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                  ),
                  onPressed: _isTripActive ? _stopTracking : _startTracking,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isTripActive ? Icons.power_settings_new : Icons.play_arrow,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isTripActive ? "END TRIP" : "START TRIP",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeadlight(bool active) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFFFFEA79) : const Color(0xFF333E52),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.9),
                  blurRadius: 20,
                  spreadRadius: 6,
                ),
              ]
            : [],
      ),
    );
  }

  Widget _buildLightBeam() {
    return Container(
      width: 38,
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.amber.withOpacity(0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
