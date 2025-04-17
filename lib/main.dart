import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:to_do_list/form/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:to_do_list/config/supabase_config.dart';
import 'package:intl/intl.dart';
import 'package:to_do_list/page/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.SUPABASE_URL,
    anonKey: SupabaseConfig.SUPABASE_ANON_KEY,
  );

  await initializeDateFormatting('id_ID', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To Do List',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashPage(),
    );
  }
}
