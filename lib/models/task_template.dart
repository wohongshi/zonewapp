import 'package:json_annotation/json_annotation.dart';

part 'task_template.g.dart';

@JsonSerializable()
class TaskTemplate {
  final String id;
  final String name;
  final String url;
  final bool enabled;
  final bool useAi;       // true=AI生成, false=直接填写
  final List<TemplateStep> steps;
  final String? aiPrompt;
  final String? aiTaskType;
  final String? directValue; // 直接填写的固定值

  TaskTemplate({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.useAi = true,
    this.steps = const [],
    this.aiPrompt,
    this.aiTaskType,
    this.directValue,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) =>
      _$TaskTemplateFromJson(json);
  Map<String, dynamic> toJson() => _$TaskTemplateToJson(this);

  TaskTemplate copyWith({
    String? id,
    String? name,
    String? url,
    bool? enabled,
    bool? useAi,
    List<TemplateStep>? steps,
    String? aiPrompt,
    String? aiTaskType,
    String? directValue,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      useAi: useAi ?? this.useAi,
      steps: steps ?? this.steps,
      aiPrompt: aiPrompt ?? this.aiPrompt,
      aiTaskType: aiTaskType ?? this.aiTaskType,
      directValue: directValue ?? this.directValue,
    );
  }

  static List<TaskTemplate> defaults() {
    const base = 'https://szpj.sdei.edu.cn/zhszpj/web';
    return [
      TaskTemplate(
        id: 'material_sort',
        name: '材料排序',
        url: '$base/clgl/xsClpx.htm',
        useAi: false,
        aiTaskType: null,
        steps: [
          TemplateStep(action: 'click', selector: '', description: '点击"无"或排序按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'position',
        name: '任职情况',
        url: '$base/jbqk/xsRzqk.htm',
        useAi: true,
        aiTaskType: 'position',
        aiPrompt: '帮我生成担任职务：{title}\n职务描述：\n文字最少25个，最多200个',
        steps: [
          TemplateStep(action: 'click', selector: '', description: '点击"添加"按钮'),
          TemplateStep(action: 'fill', selector: '', value: '{ai_content}', description: '填写职务描述'),
          TemplateStep(action: 'click', selector: '', description: '点击"保存"按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'reward',
        name: '奖惩情况',
        url: '$base/jbqk/xsJcxx.htm',
        useAi: true,
        aiTaskType: 'reward',
        aiPrompt: '帮我生成奖惩情况：{title}\n描述文字最少25个，最多200个',
        steps: [
          TemplateStep(action: 'click', selector: '', description: '点击"添加"按钮'),
          TemplateStep(action: 'fill', selector: '', value: '{ai_content}', description: '填写奖惩描述'),
          TemplateStep(action: 'click', selector: '', description: '点击"保存"按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'physical_education',
        name: '日常体育锻炼',
        url: '$base/sxjk/xsTydl.htm',
        useAi: false,
        directValue: '100',
        aiTaskType: null,
        steps: [
          TemplateStep(action: 'fill', selector: '', value: '100', description: '填写出勤率 100%'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'psychology',
        name: '心理素质展示',
        url: '$base/sxjk/xsSxjk.htm',
        useAi: true,
        aiTaskType: 'psychology',
        aiPrompt: '本学期心理素质展示\n请描述你在高中阶段克服遇到的困难或应对挫折的典型事件。（25~200字）',
        steps: [
          TemplateStep(action: 'fill', selector: '', value: '{ai_content}', description: '填写心理素质内容'),
          TemplateStep(action: 'click', selector: '', description: '点击"保存"按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'statement',
        name: '陈述报告',
        url: '$base/csbg/xsCsbg.htm',
        useAi: true,
        aiTaskType: 'statement',
        aiPrompt: '本学期陈述报告\n用自己的成长事实，说明个性、兴趣、特长、发展潜能、生涯规划。（25~200字）',
        steps: [
          TemplateStep(action: 'fill', selector: '', value: '{ai_content}', description: '填写陈述报告'),
          TemplateStep(action: 'click', selector: '', description: '点击"保存"按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'party_activity',
        name: '党团活动',
        url: '$base/sxpd/xsDxsl.htm',
        useAi: true,
        aiTaskType: 'party_activity',
        aiPrompt: '活动主题：*\n活动类型：党团活动\n典型事例描述：（25~200字）',
        steps: [
          TemplateStep(action: 'click', selector: '', description: '点击"添加"按钮'),
          TemplateStep(action: 'fill', selector: '', value: '{ai_content}', description: '填写活动描述'),
          TemplateStep(action: 'click', selector: '', description: '点击"保存"按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'volunteer',
        name: '志愿服务',
        url: '$base/sxpd/xsDxsl.htm',
        useAi: true,
        aiTaskType: 'volunteer',
        aiPrompt: '活动主题：*\n活动类型：志愿服务\n典型事例描述：（25~200字）',
        steps: [
          TemplateStep(action: 'click', selector: '', description: '点击"添加"按钮'),
          TemplateStep(action: 'fill', selector: '', value: '{ai_content}', description: '填写志愿服务描述'),
          TemplateStep(action: 'click', selector: '', description: '点击"保存"按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'art',
        name: '艺术素养',
        url: '$base/yssy/xsYssy.htm',
        useAi: true,
        aiTaskType: 'art',
        aiPrompt: '年级：高中二年级 学年：2025-2026\n学期：下学期 项目：音乐\n社团活动情况：（25~200字）\n主要成绩：（25~200字）',
        steps: [
          TemplateStep(action: 'fill', selector: '', value: '{ai_content}', description: '填写艺术素养内容'),
          TemplateStep(action: 'click', selector: '', description: '点击"保存"按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'labor',
        name: '劳动与实践',
        url: '$base/shsj/xsShsj.htm',
        useAi: true,
        aiTaskType: 'labor',
        aiPrompt: '学年：2025-2026 学期：下学期\n类别：职业体验活动\n内容描述：（25~200字）\n承担任务：（25~200字）\n实践成果：（25~200字）',
        steps: [
          TemplateStep(action: 'click', selector: '', description: '点击"添加"按钮'),
          TemplateStep(action: 'fill', selector: '', value: '{ai_content}', description: '填写劳动实践内容'),
          TemplateStep(action: 'click', selector: '', description: '点击"保存"按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'research',
        name: '课题研究',
        url: '$base/xysp/xsYjxxxjcxcg.htm',
        useAi: true,
        aiTaskType: 'research',
        aiPrompt: '学年：2025-2026 学期：下学期\n类型：课题研究\n课题名称：{title}\n研究内容：*\n成果概述：',
        steps: [
          TemplateStep(action: 'click', selector: '', description: '点击"添加"按钮'),
          TemplateStep(action: 'fill', selector: '', value: '{ai_content}', description: '填写研究内容'),
          TemplateStep(action: 'click', selector: '', description: '点击"保存"按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
      TaskTemplate(
        id: 'project_design',
        name: '项目设计',
        url: '$base/xysp/xsYjxxxjcxcg.htm',
        useAi: true,
        aiTaskType: 'project_design',
        aiPrompt: '学年：2025-2026 学期：下学期\n类型：项目（活动）设计\n课题名称：{title}\n研究内容：*\n成果概述：',
        steps: [
          TemplateStep(action: 'click', selector: '', description: '点击"添加"按钮'),
          TemplateStep(action: 'fill', selector: '', value: '{ai_content}', description: '填写项目设计内容'),
          TemplateStep(action: 'click', selector: '', description: '点击"保存"按钮'),
          TemplateStep(action: 'screenshot', description: '截图保存'),
        ],
      ),
    ];
  }
}

@JsonSerializable()
class TemplateStep {
  final String action;
  final String selector;
  final String? value;
  final String description;
  final int? waitMs;

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
