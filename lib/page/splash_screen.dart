import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:to_do_list/form/login.dart';
import 'package:to_do_list/navbar/bottom_nav.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Delay selama 2 detik untuk menampilkan splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Cek status login
    final Session? session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // User sudah login, navigasi ke BottomNav
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const BottomNav()),
      );
    } else {
      // User belum login, navigasi ke LoginPage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo atau gambar splash screen
            Image.asset(
              'assets/images/amico.png',
              height: 200,
            ),
            const SizedBox(height: 24),
            // Loading indicator
            const CircularProgressIndicator(
              color: Color(0xFF69D1F7),
            ),
          ],
        ),
      ),
    );
  }
}
