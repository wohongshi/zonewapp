import 'ai_service.dart';
import 'form_scraper_service.dart';

/// Represents a parsed AI response that maps to form fields.
class FieldFillPlan {
  final ScrapedField field;
  final String valueToFill;
  final String reason;

  FieldFillPlan({
    required this.field,
    required this.valueToFill,
    required this.reason,
  });
}

/// Generates AI content based on scraped form fields, then splits
/// the response into individual field values for auto-filling.
class AiFormFillerService {
  static final AiFormFillerService instance = AiFormFillerService._();
  AiFormFillerService._();

  /// Generate content for a given template/task type, using the actual
  /// form fields scraped from the page as context.
  Future<AiResponse> generateForPage({
    required String taskType,
    required String templatePrompt,
    required List<ScrapedField> scrapedFields,
    String? extraContext,
  }) async {
    // Build a comprehensive prompt that includes form field info
    final fieldSummary = _buildFieldSummary(scrapedFields);

    final fullPrompt = '''
$templatePrompt

---页面表单字段信息$fieldSummary${extraContext != null ? '\n---附加信息\n$extraContext' : ''}

---要求
1. 根据以上表单字段信息，生成可以直接填写的内容
2. 每个需要填写的字段单独一行，格式为：【字段名】：填写内容
3. 内容要真实自然，符合高中生身份
4. 如果有字数限制，严格遵守
5. 如果有选项字段，选择最合适的选项
''';

    return AiService.instance.sendMessage(fullPrompt);
  }

  /// Parse AI response into individual field fill plans.
  List<FieldFillPlan> parseAndMatch({
    required String aiResponse,
    required List<ScrapedField> fields,
  }) {
    final plans = <FieldFillPlan>[];

    // Parse 【字段名】：内容 pattern
    final pattern = RegExp(r'【(.+?)】[：:]\s*(.+?)(?=【|\$)', dotAll: true);
    final matches = pattern.allMatches(aiResponse);

    for (final match in matches) {
      final fieldName = match.group(1)!.trim();
      final content = match.group(2)!.trim();

      // Find matching field
      final field = _findBestMatch(fieldName, fields);
      if (field != null && content.isNotEmpty) {
        plans.add(FieldFillPlan(
          field: field,
          valueToFill: content,
          reason: 'AI匹配: $fieldName → ${field.displayName}',
        ));
      }
    }

    // If no 【】 pattern found, try line-by-line matching
    if (plans.isEmpty) {
      plans.addAll(_parseLineByLine(aiResponse, fields));
    }

    return plans;
  }

  /// Execute the fill plan - actually fill the fields in the WebView.
  Future<List<String>> executeFillPlan(List<FieldFillPlan> plans) async {
    final results = <String>[];

    for (final plan in plans) {
      try {
        final success = await FormScraperService.instance
            .fillField(plan.field.selector, plan.valueToFill);
        if (success) {
          results.add('✅ ${plan.field.displayName}: ${plan.valueToFill}');
        } else {
          results.add('❌ ${plan.field.displayName}: 填写失败');
        }
        // Small delay between fills
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        results.add('❌ ${plan.field.displayName}: $e');
      }
    }

    return results;
  }

  /// Build a text summary of fields for the AI prompt.
  String _buildFieldSummary(List<ScrapedField> fields) {
    if (fields.isEmpty) return '（无）';

    final buffer = StringBuffer();
    for (int i = 0; i < fields.length; i++) {
      final f = fields[i];
      buffer.write('\n${i + 1}. ${f.displayName}');
      buffer.write(' (${f.tagName}');
      if (f.type != 'text') buffer.write(', ${f.type}');
      buffer.write(')');
      if (f.tagName == 'select' && f.options != null) {
        buffer.write(' 可选值: ${f.options!.map((o) => '"${o.text}"').join(", ")}');
      }
      if (f.currentValue.isNotEmpty) {
        buffer.write(' [当前: ${f.currentValue}]');
      }
    }
    return buffer.toString();
  }

  /// Find the best matching field for a given field name.
  ScrapedField? _findBestMatch(String name, List<ScrapedField> fields) {
    // Exact match on label/name/id
    for (final f in fields) {
      if (f.displayName == name) return f;
      if (f.label == name) return f;
      if (f.name == name) return f;
      if (f.id == name) return f;
    }

    // Partial match
    final nameLower = name.toLowerCase();
    for (final f in fields) {
      final display = f.displayName.toLowerCase();
      if (display.contains(nameLower) || nameLower.contains(display)) {
        return f;
      }
    }

    return null;
  }

  /// Fallback: parse line by line and try to match fields.
  List<FieldFillPlan> _parseLineByLine(
      String aiResponse, List<ScrapedField> fields) {
    final plans = <FieldFillPlan>[];
    final lines = aiResponse.split('\n').where((l) => l.trim().isNotEmpty);

    // Collect fillable fields (inputs and textareas, not selects)
    final fillableFields =
        fields.where((f) => f.tagName != 'select').toList();

    int fieldIndex = 0;
    for (final line in lines) {
      if (fieldIndex >= fillableFields.length) break;

      // Skip lines that look like headers or instructions
      final trimmed = line.trim();
      if (trimmed.startsWith('#') ||
          trimmed.startsWith('---') ||
          trimmed.startsWith('要求') ||
          trimmed.startsWith('注意')) continue;

      // Clean up the line
      var content = trimmed;
      // Remove leading numbering
      content = content.replaceFirst(RegExp(r'^\d+[\.\)、]\s*'), '');
      // Remove field name prefix if present
      content = content.replaceFirst(RegExp(r'^.+?[：:]\s*'), '');

      if (content.isNotEmpty && content.length >= 5) {
        plans.add(FieldFillPlan(
          field: fillableFields[fieldIndex],
          valueToFill: content,
          reason: '顺序匹配: 第${fieldIndex + 1}个字段',
        ));
        fieldIndex++;
      }
    }

    return plans;
  }
}
