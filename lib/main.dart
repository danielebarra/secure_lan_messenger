import 'package:flutter/material.dart';
import 'package:secure_lan_messenger/app_services.dart';
import 'package:window_manager/window_manager.dart';
import 'app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await AppServices.init();

  WindowManager.instance.setMaximumSize(const Size(1100, 825));
  WindowManager.instance.setMinimumSize(const Size(1100, 825));
  WindowManager.instance.setResizable(false);
  WindowManager.instance.setMaximizable(false);

  WindowOptions windowOptions = WindowOptions(
    size: Size(1100, 825),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Secure LAN Messenger",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B63CE)),
      ),
      home: const AppShell(),
    );
  }
}
