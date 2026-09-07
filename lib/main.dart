import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  runApp(const MaterialApp(
    home: DriverScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> with SingleTickerProviderStateMixin {
  final String firebaseUrl = "https://uni-bus-tracking-f0535-default-rtdb.firebaseio.com";
  String busId = "bus_01";
  bool isTripActive = false;
  String info = "বাসে বা বাটনে ট্যাপ করে ট্রিপ শুরু করুন";
  StreamSubscription<Position>? gpsListener;

  late AnimationController _engineController;

  @override
  void initState() {
    super.initState();
    // ইঞ্জিন চালু থাকলে বাসের মৃদু কাঁপুনির অ্যানিমেশন
    _engineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _engineController.dispose();
    gpsListener?.cancel();
    super.dispose();
  }

  // ইঞ্জিন স্টার্টের হ্যাপটিক ফিডব্যাক (শব্দ ও ভাইব্রেশন সিমুলেশন)
  void _playEngineStartVibe() async {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    HapticFeedback.vibrate();
  }

  void _playEngineStopVibe() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
  }

  Future<bool> getPermission() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => info = "ফোনের GPS/Location চালু করুন");
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => info = "লোকেশন পারমিশন ছাড়া অ্যাপ চলবে না");
        return false;
      }
    }
    return true;
  }

  void updateFirebase(Position pos) async {
    final url = Uri.parse("$firebaseUrl/buses/$busId.json");
    try {
      await http.patch(
        url,
        body: jsonEncode({
          "lat": pos.latitude,
          "lng": pos.longitude,
          "status": "ACTIVE",
          "updatedAt": DateTime.now().millisecondsSinceEpoch,
        }),
      );
      if (mounted) {
        setState(() => info = "লাইভ ট্র্যাকিং সক্রিয়\nগতি: ${(pos.speed * 3.6).round()} কিমি/ঘণ্টা");
      }
    } catch (e) {
      if (mounted) {
        setState(() => info = "ইন্টারনেট সমস্যা!");
      }
    }
  }

  void startTrip() async {
    bool ok = await getPermission();
    if (!ok) return;

    _playEngineStartVibe();
    _engineController.repeat(reverse: true);
    WakelockPlus.enable();

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

    gpsListener = Geolocator.getPositionStream(locationSettings: androidSettings).listen((pos) {
      updateFirebase(pos);
    });

    setState(() {
      isTripActive = true;
      info = "বাস চলমান... লাইট অন";
    });
  }

  void stopTrip() async {
    _playEngineStopVibe();
    _engineController.stop();
    await gpsListener?.cancel();
    WakelockPlus.disable();

    final url = Uri.parse("$firebaseUrl/buses/$busId.json");
    await http.patch(url, body: jsonEncode({"status": "INACTIVE"}));

    setState(() {
      isTripActive = false;
      info = "ট্রিপ শেষ (ইঞ্জিন ও লাইট বন্ধ)";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isTripActive ? "বাস চালু আছে" : "ইউনিভার্সিটি বাস",
                style: TextStyle(
                  color: isTripActive ? Colors.greenAccent : Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 30),

              // বাসের বডি এবং হেডলাইট সেকশন (পিওর ফ্ল্যাটার কোড)
              AnimatedBuilder(
                animation: _engineController,
                builder: (context, child) {
                  // ইঞ্জিন ভাইব্রেশন এফেক্ট
                  double offset = isTripActive ? sin(_engineController.value * pi * 2) * 1.5 : 0;
                  return Transform.translate(
                    offset: Offset(0, offset),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: isTripActive ? stopTrip : startTrip,
                  child: Column(
                    children: [
                      // বাসের বডি
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
                            color: isTripActive ? Colors.greenAccent.withOpacity(0.5) : Colors.white24,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            // রুট বোর্ড
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: isTripActive ? Colors.green.shade900 : Colors.black45,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "CAMPUS SPECIAL",
                                style: TextStyle(
                                  color: isTripActive ? Colors.greenAccent : Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // উইন্ডশিল্ড (সামনের বড় গ্লাস)
                            Container(
                              width: 140,
                              height: 65,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A364F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person, color: Colors.white24, size: 28),
                            ),
                            const Spacer(),
                            // গ্রিল ও নাম্বার প্লেট
                            Container(
                              width: 60,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // দুটি হেডলাইট
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildHeadlight(isTripActive),
                                  _buildHeadlight(isTripActive),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),

                      // হেডলাইট থেকে বের হওয়া আলোর বিম (Light Beam)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isTripActive ? 1.0 : 0.0,
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

              const SizedBox(height: 25),

              // স্টার্ট / এন্ড বাটন
              SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTripActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                  ),
                  onPressed: isTripActive ? stopTrip : startTrip,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isTripActive ? Icons.power_settings_new : Icons.play_arrow, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        isTripActive ? "END TRIP" : "START TRIP",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                info,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // বাসের গোল হেডলাইট উইজেট
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

  // সামনের দিকে ছড়ানো আলোর বিম
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
