import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/chat_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SnapeApp(),
    ),
  );
}

class SnapeApp extends StatelessWidget {
  const SnapeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Snape AI Companion',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: child,
        );
      },
      child: const ChatScreen(),
    );
  }
}
