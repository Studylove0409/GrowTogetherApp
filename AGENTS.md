# AGENTS.md — 一起进步呀 (GrowTogetherApp)

## 项目概览

- **产品名称**：一起进步呀
- **类型**：情侣共同成长 Flutter App
- **一句话描述**：情侣制定计划、每日打卡、互相提醒、互相监督，在可爱温柔的氛围里一起变好
- **版本**：1.0.0+1（MVP 阶段，UI 骨架已完成，无后端）
- **Dart SDK**：^3.8.1
- **Flutter**：Material 3，useMaterial3: true

## 当前状态

项目处于 **UI 骨架阶段**：
- 4 个 Tab 页面（首页、计划、提醒、我的）已实现
- 数据全部来自 `MockData` 静态常量，无真实后端
- 没有状态管理库（无 Provider/Riverpod/Bloc）
- 没有路由库（无 go_router，页面切换靠 IndexedStack）
- 没有网络请求、没有数据库、没有本地持久化
- 没有 iOS 目录（仅 Android）
- 测试文件为 Flutter 模板默认生成的 `widget_test.dart`，无实际测试

## 目录结构

```
lib/
├── main.dart                    # 入口，runApp(GrowTogetherApp())
├── app.dart                     # MaterialApp + GrowTogetherShell（底部导航）
├── core/
│   └── theme/
│       ├── app_colors.dart      # 色彩常量（粉色系）
│       ├── app_spacing.dart     # 间距 Token（xs~xxl）
│       ├── app_text_styles.dart # 文字样式（display/title/section/body/caption）
│       └── app_theme.dart       # ThemeData（Material 3 主题配置）
├── data/
│   ├── models/
│   │   ├── plan.dart            # Plan 模型 + PlanOwner 枚举 (me/partner/together)
│   │   ├── profile.dart         # Profile 模型（姓名、伴侣、天数、邀请码）
│   │   └── reminder.dart        # Reminder 模型
│   └── mock/
│       └── mock_data.dart       # MockData 静态假数据（profile/plans/reminders/growthRecords）
├── features/
│   ├── home/
│   │   └── home_page.dart       # 首页：成长状态卡、今日计划、今日统计、成长记录入口
│   ├── plans/
│   │   └── plans_page.dart      # 计划页：分段 Tab（我的/TA的/共同）+ 计划列表
│   ├── reminders/
│   │   └── reminders_page.dart  # 提醒页：收到/发出 Tab + 发送提醒输入框
│   └── profile/
│       └── profile_page.dart    # 我的页：个人信息、邀请码、设置列表、退出登录
├── shared/
│   └── widgets/
│       ├── app_card.dart        # 通用卡片组件（圆角28、粉色阴影、可点击）
│       ├── primary_button.dart  # 主按钮（FilledButton 包装，可选图标）
│       └── section_header.dart  # 标题栏（标题 + 可选操作链接）
文档设计/
├── DESIGN.md                    # 视觉规范（色彩/字体/间距/圆角/阴影/组件）
└── 情侣共同成长小程序prd_可爱版.md  # PRD（产品功能/页面结构/业务规则）
```

## 架构模式

- **分层**：`core`（主题）→ `data`（模型+数据源）→ `features`（页面）→ `shared`（复用组件）
- **页面组织**：每个 feature 一个目录，每个目录一个主页面文件
- **导航**：`IndexedStack` + `NavigationBar`（4 个 Tab），无命名路由
- **状态管理**：纯 `setState`，仅 PlansPage 和 RemindersPage 有局部状态（Tab 切换）
- **数据层**：全部 `const` 静态假数据，模型为纯 Dart 类（无 JSON 序列化）

## 设计风格

- **视觉关键词**：可爱、温暖、情侣感、奶油粉色系、大圆角卡片
- **主色**：`#FF8FAB`（粉）、`#FF6F96`（深粉）、`#FFE4EC`（浅粉）
- **背景**：`#FFF8F1`（奶油白）
- **圆角**：卡片 28dp，按钮 28dp，输入框 22dp
- **阴影**：粉色透明阴影 `rgba(255,143,171,0.10~0.16)`
- **文案语气**：温柔可爱但不幼稚，可用"呀、啦、哦"，避免命令式/过度撒娇

## 核心数据模型

```dart
enum PlanOwner { me, partner, together }

class Plan {
  title, subtitle, owner(PlanOwner), icon(IconData),
  minutes, completedDays, totalDays, doneToday, color(Color)
  double get progress => completedDays / totalDays;
}

class Profile {
  name, partnerName, togetherDays, inviteCode, isBound
}

class Reminder {
  title, message, time, icon(IconData), sentByMe, color(Color)
}
```

## 关键依赖

仅 Flutter SDK + cupertino_icons，无第三方库。开发依赖 flutter_test + flutter_lints。

## PRD 核心功能（V1.0）

1. 情侣绑定（邀请码机制）
2. 创建个人计划 / 共同计划
3. 每日打卡（完成状态 + 今日总结 + 心情）
4. 互相提醒（温柔文案）
5. 成长记录（连续天数、完成率、日历）
6. 10 个页面：登录、首页、情侣绑定、计划列表、创建计划、计划详情、打卡、提醒、成长记录、我的

## 待实现事项

- [ ] 状态管理方案选型与接入
- [ ] 路由方案（go_router 或 Navigator 2.0）
- [ ] 后端接入（用户系统、计划 CRUD、打卡、提醒）
- [ ] 本地持久化（SharedPreferences / Hive / SQLite）
- [ ] 登录/注册/绑定流程
- [ ] 创建计划页、计划详情页、打卡页、成长记录页、情侣绑定页
- [ ] 通知推送（本地通知 / 远程推送）
- [ ] iOS 平台配置
- [ ] 单元测试 / Widget 测试
- [ ] 国际化（如需要）

## 开发命令

```bash
flutter pub get          # 安装依赖
flutter run              # 运行 App
flutter analyze          # 静态分析
flutter test             # 运行测试
flutter build apk        # 构建 Android APK
```

## Agent skills

### Issue tracker

工单以 markdown 文件存放在 `.scratch/<feature-slug>/` 目录下。详见 `docs/agents/issue-tracker.md`。

### Triage labels

使用默认五标签词汇：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。详见 `docs/agents/triage-labels.md`。

### Domain docs

单上下文布局：`CONTEXT.md` + `docs/adr/` 在仓库根目录。详见 `docs/agents/domain.md`。

## 注意事项

- 项目原本设计为微信小程序（DESIGN.md 中有 rpx 单位和 WXML 规范），当前已转为 Flutter 实现。Flutter 代码中的尺寸单位为逻辑像素（dp），不要混用 rpx
- DESIGN.md 是视觉规范的权威来源，新增 UI 组件应参考其中的色彩、间距、圆角、阴影规范
- 所有页面当前无实际交互逻辑（按钮 onPressed 为空），接入功能时需逐个实现
- MockData 是当前唯一数据源，新增功能应先建立真实数据层再替换
