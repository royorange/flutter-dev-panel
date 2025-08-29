## 1.0.4

 - Update a dependency to the latest release.

## 1.0.3

 - Update a dependency to the latest release.

## 1.0.2

 - Bump "flutter_dev_panel_performance" to `1.0.2`.

## 1.0.1

 - **REFACTOR**: 重构为模块化架构. ([ef4edf8a](https://github.com/royorange/flutter_dev_panel/commit/ef4edf8a350a88e230ae8b40508efb4978ff99f6))
 - **FIX**: downgrade test package version to fix flutter_test compatibility. ([a1dacadf](https://github.com/royorange/flutter_dev_panel/commit/a1dacadf7d585eeb782ea2ca61577791d915816c))
 - **FIX**: unify Flutter version requirement to 3.10.0 across all packages. ([d7552d8e](https://github.com/royorange/flutter_dev_panel/commit/d7552d8e41c1be7f08ab461df83df32bad95e8b4))
 - **FIX**: add required files for publishing and fix script. ([72ac1a91](https://github.com/royorange/flutter_dev_panel/commit/72ac1a91ceeb283d3fedf2e2a11419c60ff78bbe))
 - **FIX**: 优化测试用例. ([6d06cc34](https://github.com/royorange/flutter_dev_panel/commit/6d06cc346cc19dfa5589d039143868c9f878dfda))
 - **FIX**: 增强性能监控模块，优化电池状态和图表显示. ([af4522aa](https://github.com/royorange/flutter_dev_panel/commit/af4522aa83721ac9710d518853766b367442cb60))
 - **FIX**: 更新设备信息和性能监控模块，增强电池状态监控. ([e8fd7f94](https://github.com/royorange/flutter_dev_panel/commit/e8fd7f94203b3758bec8b6e9efa30f957b0c4207))
 - **FIX**: 移除不再使用的悬浮按钮组件并优化FAB管理. ([36d0f8c0](https://github.com/royorange/flutter_dev_panel/commit/36d0f8c018132cd8f30c4623f24226f2c1a9fd6a))
 - **FIX**: 增强FAB内容构建和优先级管理. ([16a36e15](https://github.com/royorange/flutter_dev_panel/commit/16a36e15fb78b45dbd62aa1f1af464d4f1f5cdf6))
 - **FIX**: 更新Flutter开发面板的API和UI组件. ([0873ef11](https://github.com/royorange/flutter_dev_panel/commit/0873ef115757ff05137c8d4343ddb20440fe6a07))
 - **FIX**: 修复UI和状态管理问题. ([80d1dd17](https://github.com/royorange/flutter_dev_panel/commit/80d1dd1703131da5989d954cc303c72c6ef030ec))
 - **FEAT**: 更新 pubspec.yaml 和 pubspec.lock 文件. ([ea4e9c71](https://github.com/royorange/flutter_dev_panel/commit/ea4e9c71f11120ea29759e21c1fc3be9c959ea16))
 - **FEAT**: 发布 1.0.0 版本，包含多个模块的重大更新. ([9a123185](https://github.com/royorange/flutter_dev_panel/commit/9a1231850d0f12b5ce9d94c0fa67e9e44b3dd1f4))
 - **FEAT**: 重构性能监控逻辑，使用 PerformanceUpdateCoordinator 统一管理 Timer. ([c0d9b70b](https://github.com/royorange/flutter_dev_panel/commit/c0d9b70b75f1eeffd942ad1eae61caba92d675ab))
 - **FEAT**: 优化 LeakDetector 和 PerformanceMonitorController 的监控逻辑. ([9576ecb0](https://github.com/royorange/flutter_dev_panel/commit/9576ecb0b8f77e9bb36efb6ba86d02189028b386))
 - **FEAT**: 优化性能模块中的内存趋势指示器. ([a7cdb476](https://github.com/royorange/flutter_dev_panel/commit/a7cdb47635228121ccdb14bcecae53783d0d5fda))
 - **FEAT**: 更新 README 和示例代码以反映 PerformanceModule 的自动 Timer 追踪功能. ([91c6cb86](https://github.com/royorange/flutter_dev_panel/commit/91c6cb869296e9a4ff6f538cc735ebac393b469f))
 - **FEAT**: 优化performance 模块，添加timer 调试信息. ([4236e42a](https://github.com/royorange/flutter_dev_panel/commit/4236e42aad7235f44c025419e315aafd27f860f3))
 - **FEAT**: 更新文档和示例代码以反映 DevPanel 的重命名. ([3b49e94b](https://github.com/royorange/flutter_dev_panel/commit/3b49e94b588f4cb3067a43cf0cf32f0173350f4e))
 - **FEAT**: 移除电池监控功能并优化性能监控. ([38765686](https://github.com/royorange/flutter_dev_panel/commit/387656864012ebdc233b5d23925a3cc70fc7a652))
 - **FEAT**: 优化UI颜色和字体权重. ([bc88b700](https://github.com/royorange/flutter_dev_panel/commit/bc88b70040db8c9b3ddd857bd9e32cb9fb34c11f))
 - **FEAT**: 更新日志捕获和控制台模块. ([15749fa2](https://github.com/royorange/flutter_dev_panel/commit/15749fa29ac1485ed8035f695f353d1ac53a1af1))
 - **DOCS**: simplify README files for all packages. ([9c431166](https://github.com/royorange/flutter_dev_panel/commit/9c431166e0c8b932be16bf315f4c0d5f696c3933))

# Changelog

## 1.0.0

* Major release with stable API
* Automatic Timer tracking via Zone API
* Memory leak detection with growth rate indicators
* Resource monitoring for Timers and StreamSubscriptions
* Interactive performance analysis with actionable advice
* Enhanced UI with expandable lists and detailed stack traces

## 0.0.2

* Fixed Flutter version requirement to 3.10.0
* Updated documentation

## 0.0.1

* Initial release
