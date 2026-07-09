import 'package:json_annotation/json_annotation.dart';

part 'task_template.g.dart';

/// Template for a 综评 automation task.
/// Each of the 12 projects has a configurable template defining:
/// - Where to navigate (url)
/// - What to click/fill (steps)
/// - How to use AI (aiPrompt)
@JsonSerializable()
class TaskTemplate {
  final String id;
  final String name;
  final String url;
  final bool enabled;
  final List<TemplateStep> steps;
  final String? aiPrompt;
  final String? aiTaskType;

  TaskTemplate({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.steps = const [],
    this.aiPrompt,
    this.aiTaskType,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) =>
      _$TaskTemplateFromJson(json);
  Map<String, dynamic> toJson() => _$TaskTemplateToJson(this);

  TaskTemplate copyWith({
    String? id,
    String? name,
    String? url,
    bool? enabled,
    List<TemplateStep>? steps,
    String? aiPrompt,
    String? aiTaskType,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      steps: steps ?? this.steps,
      aiPrompt: aiPrompt ?? this.aiPrompt,
      aiTaskType: aiTaskType ?? this.aiTaskType,
    );
  }

  /// Default templates for all 12 projects.
  static List<TaskTemplate> defaults() {
    const base = 'https://szpj.sdei.edu.cn/zhszpj/web';
    return [
      TaskTemplate(
        id: 'material_sort',
        name: '材料排序',
        url: '$base/clgl/xsClpx.htm',
        aiTaskType: null,
        steps: [
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"无"或排序按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'position',
        name: '任职情况',
        url: '$base/jbqk/xsRzqk.htm',
        aiTaskType: 'position',
        aiPrompt: '帮我生成担任职务：{title}\n职务描述：\n文字最少25个，最多200个',
        steps: [
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"添加"按钮',
          ),
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '{ai_content}',
            description: '填写AI生成的职务描述',
          ),
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"保存"按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'reward',
        name: '奖惩情况',
        url: '$base/jbqk/xsJcxx.htm',
        aiTaskType: 'reward',
        aiPrompt: '帮我生成奖惩情况：{title}\n描述文字最少25个，最多200个',
        steps: [
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"添加"按钮',
          ),
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '{ai_content}',
            description: '填写AI生成的奖惩描述',
          ),
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"保存"按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'physical_education',
        name: '日常体育锻炼',
        url: '$base/sxjk/xsTydl.htm',
        aiTaskType: null,
        steps: [
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '100',
            description: '填写出勤率 100%',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'psychology',
        name: '心理素质展示',
        url: '$base/sxjk/xsSxjk.htm',
        aiTaskType: 'psychology',
        aiPrompt: '本学期心理素质展示\n请描述你在高中阶段克服遇到的困难或应对挫折的典型事件，也可描述在人际交往、情绪调节等方面的事件，并简要说明你是如何应对的。（25~200字）',
        steps: [
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '{ai_content}',
            description: '填写AI生成的心理素质内容',
          ),
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"保存"按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'statement',
        name: '陈述报告',
        url: '$base/csbg/xsCsbg.htm',
        aiTaskType: 'statement',
        aiPrompt: '本学期陈述报告\n用自己的成长事实，来说明自己的个性、兴趣、特长、发展潜能、生涯规划（愿望），语言简明扼要。（25~200字）',
        steps: [
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '{ai_content}',
            description: '填写AI生成的陈述报告',
          ),
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"保存"按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'party_activity',
        name: '党团活动',
        url: '$base/sxpd/xsDxsl.htm',
        aiTaskType: 'party_activity',
        aiPrompt: '活动主题：*\n活动类型：党团活动\n典型事例描述：描述参加的典型事例活动中你承担的任务，完成情况，获得的荣誉等。（25~200字）',
        steps: [
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"添加"按钮',
          ),
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '{ai_content}',
            description: '填写AI生成的活动描述',
          ),
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"保存"按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'volunteer',
        name: '志愿服务',
        url: '$base/sxpd/xsDxsl.htm',
        aiTaskType: 'volunteer',
        aiPrompt: '活动主题：*\n活动类型：志愿服务\n典型事例描述：描述参加的典型事例活动中你承担的任务，完成情况，获得的荣誉等。（25~200字）',
        steps: [
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"添加"按钮',
          ),
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '{ai_content}',
            description: '填写AI生成的志愿服务描述',
          ),
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"保存"按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'art',
        name: '艺术素养',
        url: '$base/yssy/xsYssy.htm',
        aiTaskType: 'art',
        aiPrompt: '年级：高中二年级 学年：2025-2026\n学期：下学期 项目：音乐\n高中阶段参加的社团及活动的情况：\n文字最少25个，最多200个\n高中阶段取得的校级（含校级）以上主要成绩：\n文字最少25个，最多200个',
        steps: [
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '{ai_content}',
            description: '填写AI生成的艺术素养内容',
          ),
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"保存"按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'labor',
        name: '劳动与实践',
        url: '$base/shsj/xsShsj.htm',
        aiTaskType: 'labor',
        aiPrompt: '学年：2025-2026 学期：下学期\n类别：职业体验活动\n内容：从事劳动与实践的工作内容描述。（25~200字）\n承担任务：主要承担的实践任务。（25~200字）\n实践成果：实践任务完成后获得的奖励、证书等。（25~200字）',
        steps: [
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"添加"按钮',
          ),
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '{ai_content}',
            description: '填写AI生成的劳动实践内容',
          ),
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"保存"按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'research',
        name: '课题研究',
        url: '$base/xysp/xsYjxxxjcxcg.htm',
        aiTaskType: 'research',
        aiPrompt: '学年：2025-2026 学期：下学期\n类型：课题研究\n课题名称：{title}\n理论学习情况：\n研究内容：*\n成果概述：',
        steps: [
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"添加"按钮',
          ),
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '{ai_content}',
            description: '填写AI生成的研究内容',
          ),
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"保存"按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
      TaskTemplate(
        id: 'project_design',
        name: '项目设计',
        url: '$base/xysp/xsYjxxxjcxcg.htm',
        aiTaskType: 'project_design',
        aiPrompt: '学年：2025-2026 学期：下学期\n类型：项目（活动）设计\n课题名称：{title}\n理论学习情况：\n研究内容：*\n成果概述：',
        steps: [
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"添加"按钮',
          ),
          TemplateStep(
            action: 'fill',
            selector: '',
            value: '{ai_content}',
            description: '填写AI生成的项目设计内容',
          ),
          TemplateStep(
            action: 'click',
            selector: '',
            description: '点击"保存"按钮',
          ),
          TemplateStep(
            action: 'screenshot',
            description: '截图保存',
          ),
        ],
      ),
    ];
  }
}

/// A single step in a task template.
@JsonSerializable()
class TemplateStep {
  final String action; // 'click', 'fill', 'select', 'wait', 'screenshot', 'navigate'
  final String selector; // CSS selector
  final String? value; // Value to fill (for fill/select actions)
  final String description; // Human-readable description
  final int? waitMs; // Wait time in ms (for wait action)

  TemplateStep({
    required this.action,
    this.selector = '',
    this.value,
    required this.description,
    this.waitMs,
  });

  factory TemplateStep.fromJson(Map<String, dynamic> json) =>
      _$TemplateStepFromJson(json);
  Map<String, dynamic> toJson() => _$TemplateStepToJson(this);

  TemplateStep copyWith({
    String? action,
    String? selector,
    String? value,
    String? description,
    int? waitMs,
  }) {
    return TemplateStep(
      action: action ?? this.action,
      selector: selector ?? this.selector,
      value: value ?? this.value,
      description: description ?? this.description,
      waitMs: waitMs ?? this.waitMs,
    );
  }
}
