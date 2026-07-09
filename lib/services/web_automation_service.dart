import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebAutomationService {
  static final WebAutomationService instance = WebAutomationService._();
  WebAutomationService._();

  WebViewController? _controller;

  void setController(WebViewController controller) {
    _controller = controller;
  }

  /// Escape a string for safe embedding in JavaScript source code.
  /// Uses JSON encoding to produce a properly quoted JS string literal.
  String _escapeJs(String value) {
    return jsonEncode(value);
  }

  Future<void> navigateTo(String url) async {
    await _controller?.loadRequest(Uri.parse(url));
  }

  Future<void> waitForPageLoad() async {
    await Future.delayed(const Duration(seconds: 2));
  }

  Future<void> fillInputById(String id, String value) async {
    final safeId = _escapeJs(id);
    final safeValue = _escapeJs(value);
    await _runJs('''
      var element = document.getElementById($safeId);
      if (element) {
        element.value = $safeValue;
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
      }
    ''');
  }

  Future<void> fillInputByName(String name, String value) async {
    final safeName = _escapeJs(name);
    final safeValue = _escapeJs(value);
    await _runJs('''
      var elements = document.getElementsByName($safeName);
      if (elements.length > 0) {
        elements[0].value = $safeValue;
        elements[0].dispatchEvent(new Event('input', { bubbles: true }));
        elements[0].dispatchEvent(new Event('change', { bubbles: true }));
      }
    ''');
  }

  Future<void> clickById(String id) async {
    final safeId = _escapeJs(id);
    await _runJs('''
      var element = document.getElementById($safeId);
      if (element) {
        element.click();
      }
    ''');
  }

  Future<void> clickBySelector(String selector) async {
    final safeSelector = _escapeJs(selector);
    await _runJs('''
      var element = document.querySelector($safeSelector);
      if (element) {
        element.click();
      }
    ''');
  }

  Future<void> selectOptionById(String id, String value) async {
    final safeId = _escapeJs(id);
    final safeValue = _escapeJs(value);
    await _runJs('''
      var element = document.getElementById($safeId);
      if (element) {
        element.value = $safeValue;
        element.dispatchEvent(new Event('change', { bubbles: true }));
      }
    ''');
  }

  Future<String> getTextById(String id) async {
    final safeId = _escapeJs(id);
    final result = await _runJsReturning('''
      var element = document.getElementById($safeId);
      element ? element.innerText : '';
    ''');
    return result;
  }

  Future<String> getInputValueById(String id) async {
    final safeId = _escapeJs(id);
    final result = await _runJsReturning('''
      var element = document.getElementById($safeId);
      element ? element.value : '';
    ''');
    return result;
  }

  Future<void> submitFormById(String id) async {
    final safeId = _escapeJs(id);
    await _runJs('''
      var form = document.getElementById($safeId);
      if (form) {
        form.submit();
      }
    ''');
  }

  Future<void> login(String username, String password) async {
    await fillInputByName('username', username);
    await Future.delayed(const Duration(milliseconds: 500));
    await fillInputByName('password', password);
    await Future.delayed(const Duration(milliseconds: 500));
    await clickBySelector('button[type="submit"], input[type="submit"], .login-btn');
  }

  Future<void> waitForElement(String selector, {int timeoutSeconds = 10}) async {
    final safeSelector = _escapeJs(selector);
    for (int i = 0; i < timeoutSeconds * 2; i++) {
      final exists = await _runJsReturning('''
        document.querySelector($safeSelector) ? 'true' : 'false';
      ''');
      if (exists == 'true') return;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _runJs(String js) async {
    try {
      await _controller?.runJavaScript(js);
    } catch (e) {
      debugPrint('JS Error: $e');
    }
  }

  Future<String> _runJsReturning(String js) async {
    try {
      final result = await _controller?.runJavaScriptReturningResult(js);
      return result?.toString().replaceAll('"', '') ?? '';
    } catch (e) {
      debugPrint('JS Error: $e');
      return '';
    }
  }
}
