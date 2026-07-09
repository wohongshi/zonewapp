import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Manages the WebAI2API service lifecycle:
/// - Start/stop the npm service
/// - Keep it running in background
/// - Auto-restart if killed
/// - Check if service is alive
class WebAi2ApiService {
  static final WebAi2ApiService instance = WebAi2ApiService._();
  WebAi2ApiService._();

  Process? _process;
  bool _isRunning = false;
  bool _autoRestart = true;
  Timer? _healthCheckTimer;
  final String _homeDir = '/data/data/com.termux/files/home';
  final String _port = '3000';

  bool get isRunning => _isRunning;
  String get serviceUrl => 'http://localhost:$_port';
  Future<String> getLanUrl() async {
    try {
      for (final iface in await NetworkInterface.list()) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return 'http://${addr.address}:$_port';
          }
        }
      }
    } catch (_) {}
    return 'http://<手机IP>:$_port';
  }

  /// Start the WebAI2API service in background.
  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      // Check if WebAI2API is installed
      final pkgFile = File('$_homeDir/WebAI2API/package.json');
      if (!pkgFile.existsSync()) {
        debugPrint('[WebAi2Api] Not installed');
        return false;
      }

      // Start the service using Termux's node
      _process = await Process.start(
        '/data/data/com.termux/files/usr/bin/node',
        ['$_homeDir/WebAI2API/dist/index.js'],
        workingDirectory: '$_homeDir/WebAI2API',
        environment: {
          'HOME': _homeDir,
          'PATH': '/data/data/com.termux/files/usr/bin:/usr/bin:/bin',
          'NODE_ENV': 'production',
        },
        mode: ProcessStartMode.detached,
      );

      _isRunning = true;
      _autoRestart = true;

      // Listen for process exit
      _process!.exitCode.then((code) {
        debugPrint('[WebAi2Api] Process exited with code $code');
        _isRunning = false;
        if (_autoRestart) {
          debugPrint('[WebAi2Api] Auto-restarting in 3s...');
          Future.delayed(const Duration(seconds: 3), () => start());
        }
      });

      // Start health check
      _startHealthCheck();

      debugPrint('[WebAi2Api] Started on port $_port');
      return true;
    } catch (e) {
      debugPrint('[WebAi2Api] Failed to start: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Stop the service.
  Future<void> stop() async {
    _autoRestart = false;
    _healthCheckTimer?.cancel();
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
    _isRunning = false;
  }

  /// Check if the service is responding.
  Future<bool> healthCheck() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(Uri.parse('http://localhost:$_port/v1/models'));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Start periodic health checks.
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        if (!_isRunning || !_autoRestart) {
          timer.cancel();
          return;
        }
        final alive = await healthCheck();
        if (!alive && _isRunning) {
          debugPrint('[WebAi2Api] Health check failed, restarting...');
          _isRunning = false;
          await start();
        }
      },
    );
  }

  /// Get the API token from WebAI2API config.
  Future<String?> getApiToken() async {
    try {
      final configFile = File('$_homeDir/WebAI2API/data/config.yaml');
      if (configFile.existsSync()) {
        final content = configFile.readAsStringSync();
        final match = RegExp(r'auth:\s*(.+)').firstMatch(content);
        return match?.group(1)?.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Dispose resources.
  void dispose() {
    _autoRestart = false;
    _healthCheckTimer?.cancel();
    _process?.kill(ProcessSignal.sigterm);
  }
}
