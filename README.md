# ZonewApp

山东省综合评价平台自动填写工具

## 功能特性

### 核心功能
- 🔄 **自动填写** - 自动完成山东省综合评价平台的12个项目
- 🤖 **AI内容生成** - 支持API模式和网页模式两种AI配置
- 📸 **自动截图** - 自动保存每个项目的完成截图
- 👥 **多账号管理** - 支持批量处理多个账号
- 💾 **数据备份** - 支持备份和恢复所有数据

### 界面功能
- 📱 **主页** - 显示当前账号、完成进度、项目状态
- 👤 **账号** - 管理账号列表，支持添加/编辑/删除
- ⚙️ **设置** - 主题、AI配置、内容设置、备份恢复

### 高级功能
- 🔔 **系统通知** - 支持OPPO、vivo、荣耀、小米灵动岛
- 🌐 **Web服务** - 隐藏功能，可通过浏览器访问管理界面
- 🎨 **主题切换** - 支持白天/夜间/跟随系统/莫奈取色

## 技术架构

### 前端 (Flutter)
- Material Design 3
- Riverpod 状态管理
- WebView 自动化
- 跨平台支持 (Android + Windows)

### 后端 (Rust)
- AI API 集成
- 数据存储 (SQLite)
- Web 服务器
- 自动化引擎

## 构建说明

### 环境要求
- Flutter 3.24.5+
- Rust 1.75+
- Android SDK 34+
- Visual Studio 2022 (Windows)

### 构建步骤

```bash
# 克隆仓库
git clone https://github.com/YOUR_USERNAME/zonewapp.git
cd zonewapp

# 安装依赖
flutter pub get

# 生成代码
flutter pub run build_runner build

# 构建 Android
flutter build apk --release

# 构建 Windows
flutter build windows --release
```

## 使用说明

### 1. 配置AI
1. 进入 设置 → AI模式选择
2. 选择 API模式 或 网页模式
3. 填写相应配置
4. 点击测试按钮验证

### 2. 添加账号
1. 进入 账号 页面
2. 点击右下角 + 按钮
3. 填写账号、密码、选科、班主任等信息
4. 点击保存

### 3. 开始自动化
1. 进入 主页 页面
2. 确认账号信息正确
3. 点击 开始 按钮
4. 等待自动完成

### 4. 隐藏功能 (Web服务)
1. 进入 设置 → 关于
2. 连续点击头像5次
3. 返回设置页面
4. 开启 Web服务
5. 访问 http://本机IP:35535

## 项目结构

```
zonewapp/
├── lib/                    # Flutter 代码
│   ├── main.dart          # 入口文件
│   ├── app.dart           # 应用主框架
│   ├── models/            # 数据模型
│   ├── providers/         # 状态管理
│   ├── screens/           # 页面
│   │   ├── home/         # 主页
│   │   ├── account/      # 账号管理
│   │   └── settings/     # 设置
│   ├── services/          # 服务
│   ├── theme/             # 主题
│   └── utils/             # 工具类
├── rust/                   # Rust 后端
│   └── src/
│       ├── ai/           # AI 集成
│       ├── automation/   # 自动化引擎
│       ├── storage/      # 数据存储
│       └── web_server/   # Web 服务器
├── android/               # Android 配置
├── windows/               # Windows 配置
└── .github/workflows/     # CI/CD
```

## 自动化项目列表

| 序号 | 项目 | 说明 |
|------|------|------|
| 1 | 材料排序 | 点击"无"并截图 |
| 2 | 任职情况 | AI生成职务描述 |
| 3 | 奖惩情况 | AI生成奖惩描述 |
| 4 | 日常体育锻炼 | 填写出勤率100% |
| 5 | 心理素质展示 | AI生成心理描述 |
| 6 | 陈述报告 | AI生成个人陈述 |
| 7 | 党团活动 | AI生成活动描述 |
| 8 | 志愿服务 | AI生成志愿描述 |
| 9 | 艺术素养 | AI生成艺术描述 |
| 10 | 劳动与实践 | AI生成实践描述 |
| 11 | 课题研究 | AI生成研究描述 |
| 12 | 项目设计 | AI生成项目描述 |

## 开发者

- **作者**: hongshi
- **B站**: https://b23.tv/koJLOZd

## 许可证

MIT License
