import 'dart:async';
import 'dart:io';

class CliAnimation {
  static bool get _enabled =>
      const bool.fromEnvironment('AIRBRIDGE_CLI', defaultValue: false);

  static Future<void> playStartupIfEnabled() async {
    if (!_enabled) {
      return;
    }
    final lines = <String>[
      '  █████╗ ██╗██████╗ ██████╗ ██████╗ ██╗██████╗  ██████╗ ███████╗',
      ' ██╔══██╗██║██╔══██╗██╔══██╗██╔══██╗██║██╔══██╗██╔════╝ ██╔════╝',
      ' ███████║██║██████╔╝██████╔╝██████╔╝██║██████╔╝██║  ███╗█████╗  ',
      ' ██╔══██║██║██╔══██╗██╔══██╗██╔══██╗██║██╔══██╗██║   ██║██╔══╝  ',
      ' ██║  ██║██║██║  ██║██║  ██║██║  ██║██║██║  ██║╚██████╔╝███████╗',
      ' ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝',
      '',
      'Initializing Spatial Transfer Engine...',
      'Scanning for nearby devices...',
      'Establishing encrypted channel...',
      'Gesture system ready.',
      'System Status: IDLE',
      '',
    ];

    for (final line in lines) {
      stdout.writeln(line);
      await Future<void>.delayed(const Duration(milliseconds: 85));
    }
  }

  static Future<void> playSelectionIfEnabled(String fileName) async {
    if (!_enabled) {
      return;
    }
    stdout.writeln('[ PINCH DETECTED ]');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    stdout.writeln('File Selected: $fileName');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    stdout.writeln('Awaiting directional input...');
    stdout.writeln('');
  }

  static Future<void> playSendIfEnabled() async {
    if (!_enabled) {
      return;
    }

    stdout.writeln('>>> SWIPE RIGHT DETECTED');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    stdout.writeln('>>> Initiating Secure Transfer...');
    await _animateBar('Encrypting', 10, const Duration(milliseconds: 30));
    await _animateBar('Connecting', 7, const Duration(milliseconds: 50),
        completeAt: 0.7);
    await _animateBar('Sending', 10, const Duration(milliseconds: 35));
    stdout.writeln('');
    stdout.writeln('✓ Transfer Complete');
    stdout.writeln('');
  }

  static Future<void> playReceiveIfEnabled() async {
    if (!_enabled) {
      return;
    }
    stdout.writeln('Incoming Secure Transfer...');
    await _animateBar('Decrypting', 10, const Duration(milliseconds: 35));
    stdout.writeln('File Saved Successfully.');
    stdout.writeln('');
  }

  static Future<void> _animateBar(
    String label,
    int totalBlocks,
    Duration frameDuration, {
    double completeAt = 1.0,
  }) async {
    final target = (totalBlocks * completeAt).round();
    for (var i = 0; i <= target; i++) {
      final filled = List<String>.filled(i, '█').join();
      final rest = List<String>.filled(totalBlocks - i, '░').join();
      final percent = ((i / totalBlocks) * 100).round();
      stdout.write('\r$label ${filled + rest} $percent%');
      await Future<void>.delayed(frameDuration);
    }
    stdout.writeln();
  }
}
