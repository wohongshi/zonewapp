import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Represents a form field extracted from a web page.
class ScrapedField {
  final String selector;
  final String tagName; // input, textarea, select, button, a
  final String type; // text, number, date, button, submit...
  final String? id;
  final String? name;
  final String? label;
  final String? placeholder;
  final String currentValue;
  final bool isVisible;
  final bool isClickable;
  final List<ScrapedOption>? options;

  ScrapedField({
    required this.selector,
    required this.tagName,
    this.type = 'text',
    this.id,
    this.name,
    this.label,
    this.placeholder,
    this.currentValue = '',
    this.isVisible = true,
    this.isClickable = false,
    this.options,
  });

  String get displayName =>
      label ?? placeholder ?? name ?? id ?? selector;

  Map<String, dynamic> toJson() => {
        'selector': selector,
        'tagName': tagName,
        'type': type,
        'id': id,
        'name': name,
        'label': label,
        'placeholder': placeholder,
        'currentValue': currentValue,
        'isVisible': isVisible,
        'isClickable': isClickable,
        'options': options?.map((o) => o.toJson()).toList(),
      };

  @override
  String toString() =>
      'ScrapedField($displayName, selector=$selector, clickable=$isClickable)';
}

class ScrapedOption {
  final String value;
  final String text;

  ScrapedOption({required this.value, required this.text});

  Map<String, dynamic> toJson() => {'value': value, 'text': text};
}

/// Scrapes form fields and clickable elements from a WebView page.
class FormScraperService {
  static final FormScraperService instance = FormScraperService._();
  FormScraperService._();

  WebViewController? _controller;

  void setController(WebViewController controller) {
    _controller = controller;
  }

  String _escapeJs(String value) => jsonEncode(value);

  /// Scrape all visible form fields and clickable elements.
  Future<List<ScrapedField>> scrapeFormFields() async {
    if (_controller == null) return [];
    try {
      final result =
          await _controller!.runJavaScriptReturningResult(_buildScrapeScript());
      return _parseScrapeResult(result.toString());
    } catch (e) {
      debugPrint('[FormScraper] Error: $e');
      return [];
    }
  }

  /// Text summary for AI context.
  Future<String> getFormFieldsSummary() async {
    final fields = await scrapeFormFields();
    if (fields.isEmpty) return '未找到表单字段';

    final buffer = StringBuffer();
    buffer.writeln('页面表单字段列表：');
    for (int i = 0; i < fields.length; i++) {
      final f = fields[i];
      if (f.isClickable) {
        buffer.writeln('${i + 1}. [按钮] ${f.displayName} (选择器: ${f.selector})');
      } else {
        buffer.write('${i + 1}. ${f.displayName} (${f.tagName}');
        if (f.type != 'text') buffer.write(', ${f.type}');
        buffer.write(')');
        if (f.tagName == 'select' && f.options != null) {
          buffer.write(' 可选值: ${f.options!.map((o) => o.text).join(", ")}');
        }
        if (f.currentValue.isNotEmpty) {
          buffer.write(' [当前: ${f.currentValue}]');
        }
        buffer.writeln(' (选择器: ${f.selector})');
      }
    }
    return buffer.toString();
  }

  /// Fill a text/number/textarea field.
  Future<bool> fillField(String selector, String value) async {
    if (_controller == null) return false;
    try {
      final s = _escapeJs(selector);
      final v = _escapeJs(value);
      await _controller!.runJavaScript('''
        var el = document.querySelector($s);
        if (el) {
          var tag = el.tagName.toLowerCase();
          if (tag === 'select') {
            el.value = $v;
            el.dispatchEvent(new Event('change', { bubbles: true }));
          } else {
            el.value = $v;
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            el.dispatchEvent(new Event('blur', { bubbles: true }));
          }
          true;
        } else { false; }
      ''');
      return true;
    } catch (e) {
      debugPrint('[FormScraper] Fill error: $e');
      return false;
    }
  }

  /// Select dropdown option by visible text.
  Future<bool> selectOptionByText(String selector, String optionText) async {
    if (_controller == null) return false;
    try {
      final s = _escapeJs(selector);
      final t = _escapeJs(optionText);
      await _controller!.runJavaScript('''
        var el = document.querySelector($s);
        if (el && el.tagName.toLowerCase() === 'select') {
          for (var i = 0; i < el.options.length; i++) {
            if (el.options[i].text.trim() === $t || el.options[i].value === $t) {
              el.selectedIndex = i;
              el.dispatchEvent(new Event('change', { bubbles: true }));
              break;
            }
          }
          true;
        } else { false; }
      ''');
      return true;
    } catch (e) {
      debugPrint('[FormScraper] Select error: $e');
      return false;
    }
  }

  /// Set a date input value (format: yyyy-MM-dd).
  Future<bool> setDateField(String selector, String dateValue) async {
    if (_controller == null) return false;
    try {
      final s = _escapeJs(selector);
      final d = _escapeJs(dateValue);
      await _controller!.runJavaScript('''
        var el = document.querySelector($s);
        if (el) {
          el.value = $d;
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
          true;
        } else { false; }
      ''');
      return true;
    } catch (e) {
      debugPrint('[FormScraper] setDate error: $e');
      return false;
    }
  }

  /// Click any element by selector.
  Future<bool> clickElement(String selector) async {
    if (_controller == null) return false;
    try {
      final s = _escapeJs(selector);
      await _controller!.runJavaScript('''
        var el = document.querySelector($s);
        if (el) { el.click(); true; } else { false; }
      ''');
      return true;
    } catch (e) {
      debugPrint('[FormScraper] Click error: $e');
      return false;
    }
  }

  /// JavaScript to scrape form fields + clickable elements.
  String _buildScrapeScript() {
    return '''
    (function() {
      var fields = [];

      // 1. Scrape form inputs (input, textarea, select)
      var inputs = document.querySelectorAll('input, textarea, select');
      for (var i = 0; i < inputs.length; i++) {
        var el = inputs[i];
        var rect = el.getBoundingClientRect();
        var style = window.getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden' ||
            rect.width === 0 || rect.height === 0) continue;
        if (el.type === 'hidden') continue;

        var selector = '';
        if (el.id) {
          selector = '#' + CSS.escape(el.id);
        } else if (el.name) {
          selector = el.tagName.toLowerCase() + '[name="' + el.name + '"]';
        } else {
          var parent = el.parentElement;
          if (parent) {
            var siblings = parent.querySelectorAll(el.tagName.toLowerCase());
            for (var j = 0; j < siblings.length; j++) {
              if (siblings[j] === el) {
                selector = el.tagName.toLowerCase() + ':nth-of-type(' + (j + 1) + ')';
                break;
              }
            }
            if (parent.id) {
              selector = '#' + CSS.escape(parent.id) + ' > ' + selector;
            } else if (parent.className && typeof parent.className === 'string') {
              selector = '.' + parent.className.trim().split(/\\s+/)[0] + ' > ' + selector;
            }
          }
        }
        if (!selector) continue;

        var label = '';
        if (el.id) {
          var lbl = document.querySelector('label[for="' + el.id + '"]');
          if (lbl) label = lbl.innerText.trim();
        }
        if (!label) { var pl = el.closest('label'); if (pl) label = pl.innerText.trim(); }
        if (!label) { var prev = el.previousElementSibling; if (prev && prev.tagName === 'LABEL') label = prev.innerText.trim(); }

        var options = [];
        if (el.tagName.toLowerCase() === 'select') {
          for (var k = 0; k < el.options.length; k++) {
            options.push({ value: el.options[k].value, text: el.options[k].innerText.trim() });
          }
        }

        fields.push({
          selector: selector,
          tagName: el.tagName.toLowerCase(),
          type: el.type || 'text',
          id: el.id || null,
          name: el.name || null,
          label: label || null,
          placeholder: el.placeholder || null,
          currentValue: el.value || '',
          isVisible: true,
          isClickable: false,
          options: options.length > 0 ? options : null
        });
      }

      // 2. Scrape clickable elements (buttons, links, [onclick])
      var clickables = document.querySelectorAll('button, a[href], input[type=submit], input[type=button], [onclick], [role=button]');
      for (var i = 0; i < clickables.length; i++) {
        var el = clickables[i];
        var rect = el.getBoundingClientRect();
        var style = window.getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden' ||
            rect.width === 0 || rect.height === 0) continue;

        var selector = '';
        if (el.id) {
          selector = '#' + CSS.escape(el.id);
        } else if (el.className && typeof el.className === 'string' && el.className.trim()) {
          selector = el.tagName.toLowerCase() + '.' + el.className.trim().split(/\\s+/).join('.');
        } else {
          var parent = el.parentElement;
          if (parent && parent.id) {
            selector = '#' + CSS.escape(parent.id) + ' > ' + el.tagName.toLowerCase();
          }
        }
        if (!selector) continue;

        var text = el.innerText ? el.innerText.trim().substring(0, 50) : '';
        fields.push({
          selector: selector,
          tagName: el.tagName.toLowerCase(),
          type: 'button',
          id: el.id || null,
          name: el.name || null,
          label: text || null,
          placeholder: null,
          currentValue: '',
          isVisible: true,
          isClickable: true,
          options: null
        });
      }

      return JSON.stringify(fields);
    })();
    ''';
  }

  /// Parse the JSON result from JavaScript.
  List<ScrapedField> _parseScrapeResult(String jsonStr) {
    try {
      var clean = jsonStr.trim();
      if (clean.startsWith('"') && clean.endsWith('"')) {
        clean = clean.substring(1, clean.length - 1);
      }
      clean = clean.replaceAll('\\"', '"').replaceAll('\\\\', '\\');

      final List<dynamic> list = jsonDecode(clean);
      return list.map((item) {
        final map = Map<String, dynamic>.from(item);
        return ScrapedField(
          selector: map['selector'] ?? '',
          tagName: map['tagName'] ?? 'input',
          type: map['type'] ?? 'text',
          id: map['id'],
          name: map['name'],
          label: map['label'],
          placeholder: map['placeholder'],
          currentValue: map['currentValue'] ?? '',
          isVisible: map['isVisible'] ?? true,
          isClickable: map['isClickable'] ?? false,
          options: map['options'] != null
              ? (map['options'] as List)
                  .map((o) => ScrapedOption(
                        value: o['value'] ?? '',
                        text: o['text'] ?? '',
                      ))
                  .toList()
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('[FormScraper] Parse error: $e');
      return [];
    }
  }
}
