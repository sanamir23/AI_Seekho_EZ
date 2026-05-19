import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/ez_theme.dart';
import 'core/services/api_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const EzApp());
}

class EzApp extends StatelessWidget {
  const EzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EZ — Life Made EZ',
      debugShowCheckedModeBanner: false,
      theme: EzTheme.light,
      home: const _AuthGate(),
    );
  }
}

/// Shows splash, then checks stored token, then routes to Home or Auth.
///
/// The timer only starts AFTER the first frame is painted so the splash
/// is always visible — even on slow devices or cold starts.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _navigating = false;
  bool _authCheckDone = false;
  bool _splashDone = false;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    // Start auth check immediately after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final user = await ApiService.instance.me().timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );
    if (!mounted) return;
    
    _destination = user != null ? const HomeScreen() : const AuthScreen();
    _authCheckDone = true;
    _tryNavigate();
  }

  void _onSplashComplete() {
    _splashDone = true;
    _tryNavigate();
  }

  void _tryNavigate() {
    if (_authCheckDone && _splashDone && !_navigating) {
      _navigating = true;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => _destination!,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen(onComplete: _onSplashComplete);
  }
}
