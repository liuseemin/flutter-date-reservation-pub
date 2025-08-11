import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'pages/form_page.dart';
import 'pages/admin_login_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/submission_success_page.dart';
import 'pages/admin_json_export.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/roster_json_builder_page.dart';
import 'pages/prefilled_editor_page.dart';

void main() async {
  // Firebase 初始化前先確保 Flutter 綁定
  WidgetsFlutterBinding.ensureInitialized();

  // 依據 flutterfire configure 產生的設定檔
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const DateReservationApp());
}

class DateReservationApp extends StatelessWidget {
  const DateReservationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Date reservation', // ← App 標題
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      routes: {
        '/': (_) => const FormPage(), // 使用者輸入表單
        '/adminLogin': (_) => const AdminLoginPage(), // 管理者登入
        '/admin': (_) => const AdminDashboard(), // 管理者後台
        '/submitted': (_) => const SubmissionSuccessPage(), // 預約成功
        '/jsonExport': (_) => const AdminJsonExportPage(),
        '/rosterBuilder': (_) => const RosterJsonBuilderPage(),
        '/prefilledEditor': (_) => const PrefilledEditorPage(),
      },
    );
  }
}
