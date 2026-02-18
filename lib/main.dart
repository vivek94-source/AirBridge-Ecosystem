import 'package:airbridge/app/airbridge_app.dart';
import 'package:airbridge/utils/cli_animation.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CliAnimation.playStartupIfEnabled();
  runApp(const AirBridgeApp());
}

