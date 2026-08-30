import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme/app_theme.dart';
import 'flavors.dart';
import 'presentation/screens/chat_screen.dart';

Future<void> runSnapeApp(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  F.appFlavor = flavor;

  // Load flavor-specific environment configuration
  try {
    await dotenv.load(
      fileName: F.envFileName,
      isOptional: true,
    );
  } catch (e) {
    debugPrint('Note: Environment file (${F.envFileName}) not loaded, falling back to defaults: $e');
  }

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
          title: F.title,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: child,
        );
      },
      child: const ChatScreen(),
    );
  }
}
