# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Flutter Dev Panel - 模块化Flutter调试面板

## 项目概述
一个零侵入、模块化的Flutter调试面板插件，开发者可按需加载功能模块或者继承 DevModule 实现自定义模块。

## 架构设计

### 包结构（重要：已重构）
```
flutter_dev_panel/              # 核心包（必需）
├── lib/
│   └── src/
│       ├── core/               # 核心功能
│       │   ├── dev_logger.dart            # 日志捕获管理
│       │   ├── environment_manager.dart   # 环境管理（内置功能）
│       │   ├── module_registry.dart       # 模块注册
│       │   └── dev_panel_controller.dart  # 面板控制器
│       ├── models/             # 数据模型
│       │   ├── dev_module.dart            # 模块基类
│       │   ├── dev_panel_config.dart      # 配置类
│       │   └── environment_config.dart    # 环境配置
│       └── ui/                 # UI组件
│           ├── dev_panel_wrapper.dart     # 包装器（提供FAB和手势）
│           ├── dev_panel.dart             # 主面板UI
│           └── widgets/                    # 通用组件
└── packages/                   # 可选模块（独立包）
    ├── flutter_dev_panel_console/     # 日志模块
    ├── flutter_dev_panel_network/     # 网络模块  
    ├── flutter_dev_panel_device/      # 设备模块
    └── flutter_dev_panel_performance/ # 性能模块
```

**注意**：flutter_dev_panel_core 已合并到主包，环境管理是核心包的内置功能，不是独立模块。

## 代码规范

### 1. 命名规范
- 模块ID：小写下划线（`network_monitor`）
- 类名：大驼峰（`NetworkModule`）
- 文件名：小写下划线（`network_module.dart`）

### 2. 错误处理
```dart
try {
  // 可能失败的操作
} catch (e) {
  debugPrint('Error: $e');
  // 返回默认值或空状态，不要崩溃
}
```

### 3. 性能考虑
- 避免在build方法中进行耗时操作
- 使用 `const` 构造函数
- 合理使用 `setState`，避免不必要的重建

### 4. UI规范
- 遵循Material Design
- 支持亮色/暗色主题
- 文案使用英文
- 提供适当的loading和empty状态

## Git规范

### Commit规范
- commit格式符合 Conventional Commits, 仅用标准的前缀

## 注意事项

### 必须遵守
- ✅ 零侵入原则：不修改用户业务代码
- ✅ 生产安全：使用 `kDebugMode` 而非 `assert`
- ✅ 优雅降级：插件不可用时不崩溃
- ✅ 模块独立：模块间不直接依赖

### 避免
- ❌ 包含mock数据或示例URL
- ❌ 生成环境等配置内置默认值（由用户定义）
- ❌ 使用外部库（如GetX）
- ❌ 在生产代码中使用 `print`

### 最佳实践
- 使用 `debugPrint` 而非 `print`
- 持久化数据时处理异常
- 提供配置选项而非硬编码
- 文档注释说明公共API

## 最佳实践记录
- 生产模式下对外的接口中用kDebugMode保护, 尽量对性能零开销

## 发布检查清单
- [ ] 所有测试通过
- [ ] 移除调试代码
- [ ] 更新版本号
- [ ] 更新CHANGELOG
- [ ] 检查生产环境安全
- [ ] 文档完整准确