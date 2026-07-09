import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用帮助')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(context, '🚀 快速开始', [
            _step('1', '添加账号', '进入"账号"页面，点击"+"添加综评账号，填写用户名、密码、班主任、选科'),
            _step('2', '配置AI', '设置 → AI模式选择，选择API模式或WebAI2API免费模式'),
            _step('3', '配置综评项目', '设置 → 综评项目配置，逐个打开12个项目，在浏览器中抓取表单并配置步骤'),
            _step('4', '开始自动化', '主页点击"开始"，自动填写所有账号的综评内容'),
          ]),
          _section(context, '👤 账号管理', [
            _item('添加账号', '用户名和密码是综评平台的登录账号'),
            _item('选科', '选择3个科目（物理/化学/生物/政治/历史/地理）'),
            _item('任职情况', '添加担任的职务（班长、课代表等），综评时自动填写'),
            _item('奖惩情况', '添加获得的奖励（三好学生等），综评时自动填写'),
            _item('批量处理', '添加多个账号后，主页一键全部处理'),
          ]),
          _section(context, '🤖 AI模式', [
            _item('API模式', '使用OpenAI兼容接口（付费），需要填写API地址和Key'),
            _item('WebAI2API模式', '免费使用DeepSeek/ChatGPT/Gemini，需要部署WebAI2API服务'),
            _item('本地部署', '在Termux中一键部署WebAI2API，手机本地运行'),
            _item('外部服务', '使用他人部署的WebAI2API服务，填入地址即可'),
          ]),
          _section(context, '📋 综评项目配置', [
            _item('登录网址', '综评平台的登录页面URL，所有项目共用'),
            _item('基础网址', '综评平台的基础URL前缀'),
            _item('AI模式项目', '蓝色标签，需要AI生成内容的项目（任职、奖惩、心理素质等）'),
            _item('直接填写项目', '绿色标签，直接填固定值的项目（材料排序、体育锻炼）'),
            _item('点击项目', '打开内置浏览器，可视化操作'),
            _item('长按项目', '快速编辑配置（URL、选择器等）'),
          ]),
          _section(context, '🌐 内置浏览器', [
            _item('抓取标签', '自动扫描页面表单字段，显示字段名、类型、选择器'),
            _item('步骤标签', '添加/编辑/删除/排序操作步骤，从抓取结果选择选择器'),
            _item('AI填写标签', '一键AI生成内容，自动拆分并填写'),
            _item('直接填写标签', '按步骤顺序执行，直接填写固定值'),
            _item('快捷填充', '步骤编辑时可快速引用账号数据和创新探究内容'),
            _item('自动匹配', '根据步骤描述自动匹配页面字段选择器'),
          ]),
          _section(context, '📝 变量说明', [
            _item('{ai_content}', 'AI生成的内容占位符'),
            _item('{username}', '当前账号用户名'),
            _item('{teacher}', '班主任姓名'),
            _item('{subjects}', '选科（如：物理、化学、生物）'),
            _item('{position}', '第一个职务名称'),
            _item('{position_desc}', '第一个职务描述'),
            _item('{reward}', '第一个奖惩名称'),
            _item('{subject:物理}', '物理科目的创新探究内容'),
            _item('{subject:化学}', '化学科目的创新探究内容'),
          ]),
          _section(context, '🔧 高级功能', [
            _item('终端', '设置 → 打开终端，可执行Linux命令（需部署Termux环境）'),
            _item('Web服务', '设置 → 开启Web服务，电脑浏览器访问手机IP:35535管理账号'),
            _item('备份恢复', '设置 → 备份与恢复，选择目录备份/恢复所有数据'),
            _item('手势预测返回', '设置 → 开启后，Android返回手势显示预测动画'),
            _item('主题', '支持白天/夜间/纯黑/跟随系统/莫奈取色'),
          ]),
          _section(context, '❓ 常见问题', [
            _qa('Q: AI生成失败？', 'A: 检查AI模式配置是否正确，API模式需要有效的Key，WebAI2API需要服务运行中'),
            _qa('Q: 表单填写失败？', 'A: 检查CSS选择器是否正确，在浏览器"抓取"标签中确认字段选择器'),
            _qa('Q: 如何免费使用AI？', 'A: 选择WebAI2API模式，在Termux中一键部署，或使用外部服务'),
            _qa('Q: 备份文件在哪？', 'A: 快速备份在应用文档目录，也可选择自定义目录保存'),
            _qa('Q: 支持哪些平台？', 'A: 仅支持Android，需要安装山东省综合评价平台APP的环境'),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'ZonewApp v1.0.0\nby hongshi',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _step(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            child: Text(num,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(desc,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(String label, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: Text(desc,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _qa(String q, String a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          Text(a,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
