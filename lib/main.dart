import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'services/call_manager.dart';
import 'services/group_call_manager.dart';
import 'services/server_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.load();
  GroupCallManager.instance.ensureInitialized();
  runApp(const GlobalVillageApp());
}

class GlobalVillageApp extends StatelessWidget {
  const GlobalVillageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Village',
      locale: const Locale('en'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: CallManager.instance.navigatorKey,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _sessionCheck;
  bool _callServiceStarted = false;

  @override
  void initState() {
    super.initState();
    _sessionCheck = _hasSession();
  }

  Future<bool> _hasSession() async {
    final token = await AuthService.getAuthToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final loggedIn = snapshot.data ?? false;
        if (loggedIn && !_callServiceStarted) {
          _callServiceStarted = true;
          CallManager.instance.ensureInitialized();
        }
        return loggedIn ? const HomePage() : const LoginPage();
      },
    );
  }
}
