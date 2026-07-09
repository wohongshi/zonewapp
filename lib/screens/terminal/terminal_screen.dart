import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../../services/terminal_service.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  StreamSubscription<String>? _outputSub;
  bool _isStarted = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 5000,
      platform: PlatformBehaviors.android,
    );
    _controller = TerminalController();

    _terminal.onOutput = (data) {
      TerminalService.instance.write(data);
    };

    _terminal.onResize = (w, h, pw, ph) {
      TerminalService.instance.resize(w, h);
    };
  }

  @override
  void dispose() {
    _outputSub?.cancel();
    TerminalService.instance.kill();
    super.dispose();
  }

  Future<void> _startTerminal() async {
    if (_isStarted) return;

    await TerminalService.instance.start();
    _isStarted = true;

    _outputSub = TerminalService.instance.output.listen((data) {
      _terminal.write(data);
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('终端'),
        actions: [
          if (!_isStarted)
            TextButton.icon(
              onPressed: _startTerminal,
              icon: const Icon(Icons.play_arrow),
              label: const Text('启动'),
            ),
          if (_isStarted) ...[
            IconButton(
              onPressed: () {
                _terminal.buffer.clear();
              },
              icon: const Icon(Icons.clear_all),
              tooltip: '清屏',
            ),
            IconButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: _terminal.buffer.getText()),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
              icon: const Icon(Icons.copy),
              tooltip: '复制',
            ),
          ],
        ],
      ),
      body: _isStarted
          ? TerminalView(
              _terminal,
              controller: _controller,
              autofocus: true,
              backgroundOpacity: 0.95,
              theme: TerminalTheme(
                cursor: Colors.white,
                selection: Colors.blue.withOpacity(0.3),
                foreground: Colors.white,
                background: const Color(0xFF1E1E1E),
                black: Colors.black,
                red: Colors.red,
                green: Colors.green,
                yellow: Colors.yellow,
                blue: Colors.blue,
                magenta: Colors.magenta,
                cyan: Colors.cyan,
                white: Colors.white,
                brightBlack: Colors.grey,
                brightRed: Colors.redAccent,
                brightGreen: Colors.greenAccent,
                brightYellow: Colors.yellowAccent,
                brightBlue: Colors.lightBlueAccent,
                brightMagenta: Colors.pinkAccent,
                brightCyan: Colors.cyanAccent,
                brightWhite: Colors.white,
                searchHitBackground: Colors.yellow,
                searchHitBackgroundCurrent: Colors.orange,
                searchHitForeground: Colors.black,
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.terminal,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '内置终端',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '用于管理 WebAI2API 服务和执行命令',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _startTerminal,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('启动终端'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(200, 48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
