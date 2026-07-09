import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Represents a form field extracted from a web page.
class ScrapedField {
  final String selector;
  final String tagName; // input, textarea, select
  final String type; // text, number, date, etc.
  final String? id;
  final String? name;
  final String? label;
  final String? placeholder;
  final String currentValue;
  final bool isVisible;
  final List<ScrapedOption>? options; // For select elements

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
        'options': options?.map((o) => o.toJson()).toList(),
      };

  @override
  String toString() =>
      'ScrapedField($displayName, selector=$selector, value=$currentValue)';
}

class ScrapedOption {
  final String value;
  final String text;

  ScrapedOption({required this.value, required this.text});

  Map<String, dynamic> toJson() => {'value': value, 'text': text};
}

/// Scrapes form fields from a WebView page.
class FormScraperService {
  static final FormScraperService instance = FormScraperService._();
  FormScraperService._();

  WebViewController? _controller;

  void setController(WebViewController controller) {
    _controller = controller;
  }

  String _escapeJs(String value) => jsonEncode(value);

  /// Scrape all visible form fields from the current page.
  Future<List<ScrapedField>> scrapeFormFields() async {
    if (_controller == null) return [];

    try {
      final js = _buildScrapeScript();
      final result = await _controller!.runJavaScriptReturningResult(js);
      return _parseScrapeResult(result.toString());
    } catch (e) {
      debugPrint('[FormScraper] Error: $e');
      return [];
    }
  }

  /// Get a text summary of all form fields (for AI context).
  Future<String> getFormFieldsSummary() async {
    final fields = await scrapeFormFields();
    if (fields.isEmpty) return '未找到表单字段';

    final buffer = StringBuffer();
    buffer.writeln('页面表单字段列表：');
    for (int i = 0; i < fields.length; i++) {
      final f = fields[i];
      buffer.write('${i + 1}. ${f.displayName}');
      if (f.tagName == 'select' && f.options != null) {
        buffer.write(' [选项: ${f.options!.map((o) => o.text).join(", ")}]');
      }
      if (f.currentValue.isNotEmpty) {
        buffer.write(' [当前值: ${f.currentValue}]');
      }
      buffer.writeln(' (选择器: ${f.selector})');
    }
    return buffer.toString();
  }

  /// Fill a specific field by selector with a value.
  Future<bool> fillField(String selector, String value) async {
    if (_controller == null) return false;
    try {
      final safeSelector = _escapeJs(selector);
      final safeValue = _escapeJs(value);
      await _controller!.runJavaScript('''
        var el = document.querySelector($safeSelector);
        if (el) {
          var tag = el.tagName.toLowerCase();
          if (tag === 'select') {
            el.value = $safeValue;
            el.dispatchEvent(new Event('change', { bubbles: true }));
          } else {
            el.value = $safeValue;
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            el.dispatchEvent(new Event('blur', { bubbles: true }));
          }
          true;
        } else {
          false;
        }
      ''');
      return true;
    } catch (e) {
      debugPrint('[FormScraper] Fill error: $e');
      return false;
    }
  }

  /// Click a button/element by selector.
  Future<bool> clickElement(String selector) async {
    if (_controller == null) return false;
    try {
      final safeSelector = _escapeJs(selector);
      await _controller!.runJavaScript('''
        var el = document.querySelector($safeSelector);
        if (el) { el.click(); true; } else { false; }
      ''');
      return true;
    } catch (e) {
      debugPrint('[FormScraper] Click error: $e');
      return false;
    }
  }

  /// Build JavaScript to scrape all form fields.
  String _buildScrapeScript() {
    return '''
    (function() {
      var fields = [];
      var elements = document.querySelectorAll('input, textarea, select');

      for (var i = 0; i < elements.length; i++) {
        var el = elements[i];
        var rect = el.getBoundingClientRect();
        var style = window.getComputedStyle(el);

        // Skip hidden fields
        if (style.display === 'none' || style.visibility === 'hidden' ||
            rect.width === 0 || rect.height === 0) continue;
        if (el.type === 'hidden' || el.type === 'submit' || el.type === 'button') continue;

        // Build unique selector
        var selector = '';
        if (el.id) {
          selector = '#' + CSS.escape(el.id);
        } else if (el.name) {
          selector = el.tagName.toLowerCase() + '[name="' + el.name + '"]';
        } else {
          // Build nth-of-type path
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

        // Get label
        var label = '';
        if (el.id) {
          var labelEl = document.querySelector('label[for="' + el.id + '"]');
          if (labelEl) label = labelEl.innerText.trim();
        }
        if (!label) {
          var parentLabel = el.closest('label');
          if (parentLabel) label = parentLabel.innerText.trim();
        }
        if (!label) {
          // Try previous sibling or parent text
          var prev = el.previousElementSibling;
          if (prev && prev.tagName === 'LABEL') label = prev.innerText.trim();
        }

        // Get options for select
        var options = [];
        if (el.tagName.toLowerCase() === 'select') {
          for (var k = 0; k < el.options.length; k++) {
            var opt = el.options[k];
            options.push({ value: opt.value, text: opt.innerText.trim() });
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
          options: options.length > 0 ? options : null
        });
      }
      return JSON.stringify(fields);
    })();
    ''';
  }

  /// Parse the JSON result from JavaScript.
  List<ScrapedField> _parseScrapeResult(String jsonStr) {
    try {
      // Remove surrounding quotes if present (JS string result)
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
