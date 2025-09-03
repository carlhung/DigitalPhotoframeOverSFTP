import 'package:flutter/material.dart';
import 'package:photoframe/connection_view_controller.dart';
import 'package:photoframe/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photoframe',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 32, 21, 184),
        ),
      ),
      home: ConnectionFormWidget(navigatorKey: navigatorKey),
    );
  }
}
