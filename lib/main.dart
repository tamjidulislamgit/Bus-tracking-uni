import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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

class _DriverScreenState extends State<DriverScreen> {
  final String firebaseUrl = "https://uni-bus-tracking-f0535-default-rtdb.firebaseio.com";

  String busId = "bus_01";
  bool isTripActive = false;
  String info = "ট্রিপ শুরু করতে বাটনে চাপুন";
  StreamSubscription<Position>? gpsListener;

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
        setState(() => info = "লাইভ লোকেশন পাঠানো হচ্ছে...\nগতি: ${(pos.speed * 3.6).round()} কিমি/ঘণ্টা");
      }
    } catch (e) {
      if (mounted) {
        setState(() => info = "ইন্টারনেট সংযোগ সমস্যা!");
      }
    }
  }

  void startTrip() async {
    bool ok = await getPermission();
    if (!ok) return;

    WakelockPlus.enable();

    // অ্যান্ড্রয়েড ব্যাকগ্রাউন্ড সার্ভিস ও পার্মানেন্ট নোটিফিকেশন কনফিগারেশন
    final AndroidSettings androidSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // প্রতি ১০ মিটার পর পর আপডেট
      forceLocationManager: true,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "ইউনিভার্সিটি বাস ট্র্যাকার",
        notificationText: "বাসের লাইভ লোকেশন ব্যাকগ্রাউন্ডে শেয়ার হচ্ছে...",
        enableWakeLock: true,
        setOngoing: true, // নোটিফিকেশন সোয়াইপ করে ডিলিট করা যাবে না
      ),
    );

    gpsListener = Geolocator.getPositionStream(locationSettings: androidSettings).listen((pos) {
      updateFirebase(pos);
    });

    setState(() {
      isTripActive = true;
      info = "সিগন্যাল কানেক্ট হচ্ছে...";
    });
  }

  void stopTrip() async {
    await gpsListener?.cancel();
    WakelockPlus.disable();

    final url = Uri.parse("$firebaseUrl/buses/$busId.json");
    await http.patch(url, body: jsonEncode({"status": "INACTIVE"}));

    setState(() {
      isTripActive = false;
      info = "ট্রিপ সম্পন্ন হয়েছে (বাস অফলাইন)";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isTripActive ? "ট্রিপ চলছে..." : "ইউনিভার্সিটি বাস",
                style: TextStyle(
                  color: isTripActive ? Colors.greenAccent : Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 90,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTripActive ? Colors.redAccent : Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isTripActive ? stopTrip : startTrip,
                  child: Text(
                    isTripActive ? "END TRIP" : "START TRIP",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                info,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
