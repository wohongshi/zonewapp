import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:path_provider/path_provider.dart';

/// Manages terminal sessions and PTY processes for the embedded terminal.
class TerminalService {
  static final TerminalService instance = TerminalService._();
  TerminalService._();

  Pty? _pty;
  final StreamController<String> _outputController = StreamController.broadcast();
  bool _isRunning = false;

  Stream<String> get output => _outputController.stream;
  bool get isRunning => _isRunning;

  /// Start a new terminal session.
  Future<void> start() async {
    if (_isRunning) return;

    try {
      // Try to start a shell
      final shell = _findShell();
      _pty = Pty.start(
        shell,
        workingDirectory: '/data/data/com.hongshi.zonewapp',
        environment: {
          'HOME': '/data/data/com.hongshi.zonewapp',
          'PATH': '/data/data/com.hongshi.zonewapp/usr/bin:/usr/bin:/bin',
          'TERM': 'xterm-256color',
          'LANG': 'en_US.UTF-8',
        },
        columns: 80,
        rows: 24,
      );

      _isRunning = true;

      _pty!.output.cast<List<int>>().transform(utf8.decoder).listen(
        (data) {
          _outputController.add(data);
        },
        onDone: () {
          _isRunning = false;
          _outputController.add('\r\n[终端已退出]\r\n');
        },
        onError: (e) {
          _isRunning = false;
          _outputController.add('\r\n[终端错误: $e]\r\n');
        },
      );

      _pty!.exitCode.then((code) {
        _isRunning = false;
        _outputController.add('\r\n[终端退出，代码: $code]\r\n');
      });

      debugPrint('Terminal started with shell: $shell');
    } catch (e) {
      _isRunning = false;
      _outputController.add('启动终端失败: $e\r\n');
      debugPrint('Failed to start terminal: $e');
    }
  }

  /// Find an available shell on the device.
  String _findShell() {
    // Common shell paths on Android
    final shells = [
      '/data/data/com.termux/files/usr/bin/bash',
      '/system/bin/sh',
      '/system/bin/bash',
      '/bin/sh',
      '/bin/bash',
    ];

    for (final shell in shells) {
      if (File(shell).existsSync()) {
        return shell;
      }
    }

    // Default fallback
    return '/system/bin/sh';
  }

  /// Write data to the terminal (user input).
  void write(String data) {
    if (_pty != null && _isRunning) {
      _pty!.write(utf8.encode(data));
    }
  }

  /// Resize the terminal.
  void resize(int cols, int rows) {
    if (_pty != null) {
      _pty!.resize(cols, rows);
    }
  }

  /// Kill the current terminal session.
  void kill() {
    _pty?.kill();
    _isRunning = false;
  }

  /// Dispose resources.
  void dispose() {
    kill();
    _outputController.close();
  }

  /// Get the app's working directory.
  Future<String> getAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Check if proot is available.
  Future<bool> hasProot() async {
    final appDir = await getAppDir();
    return File('$appDir/proot').existsSync() ||
        File('/data/data/com.termux/files/usr/bin/proot').existsSync();
  }

  /// Check if a Linux distro is installed.
  Future<bool> hasDistro() async {
    final appDir = await getAppDir();
    final distroDir = Directory('$appDir/debian');
    return distroDir.existsSync();
  }

  /// Check if Node.js is installed in the distro.
  Future<bool> hasNodeJs() async {
    final appDir = await getAppDir();
    return File('$appDir/debian/usr/bin/node').existsSync();
  }

  /// Check if WebAI2API is installed.
  Future<bool> hasWebAI2API() async {
    final appDir = await getAppDir();
    return File('$appDir/debian/root/WebAI2API/package.json').existsSync();
  }
}
