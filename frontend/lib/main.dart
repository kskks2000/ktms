import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = await AuthService.bootstrap().timeout(
    const Duration(seconds: 4),
    onTimeout: () => AuthService.disabled('Firebase initialization timed out.'),
  );
  runApp(KtmsApp(authService: authService));
}
