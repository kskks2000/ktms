import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = await AuthService.bootstrap();
  runApp(KtmsApp(authService: authService));
}
