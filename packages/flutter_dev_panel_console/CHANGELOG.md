## 1.1.0

 - **FEAT**: Improved Logger package output handling
   - Clean display of multi-line Logger output in list view
   - Remove ANSI escape codes and box-drawing characters in detail view
   - Replace Logger decoration lines with elegant dashed dividers
   - Better visual separation between error messages and stack traces
 - **FEAT**: Enhanced RenderFlex overflow warning capture
   - Capture complete Flutter error output including widget tree and constraints
   - Display full context for RenderFlex overflow warnings
   - Improved error detail formatting with proper highlighting
 - **FIX**: Remove trailing empty lines in log detail view
 - **FIX**: ci. ([228211f5](https://github.com/royorange/flutter_dev_panel/commit/228211f55cdd6efb9725070e7397ac525e7a9b88))
 - **FEAT**: optimize logger print. ([3f969cd8](https://github.com/royorange/flutter_dev_panel/commit/3f969cd851a0f1cb428ead10a46267625c427de6))

## 1.0.3

 - Update a dependency to the latest release.

## 1.0.2

 - **FIX**: 优化日志. ([4c73ba3d](https://github.com/royorange/flutter_dev_panel/commit/4c73ba3d25787489a7823ecf4a5e2529757bb4a7))
 - **FIX**: optimize Logger package output handling in Console module. ([6c09fb8b](https://github.com/royorange/flutter_dev_panel/commit/6c09fb8b51103186c396097339debe3d36aec7c9))

## 1.0.1

 - **REFACTOR**: use factory function for Logger integration without direct dependency. ([6467f784](https://github.com/royorange/flutter_dev_panel/commit/6467f7849cfb1a617fe33a8769b79b77e2d2e473))
 - **REFACTOR**: rename customOutput to baseOutput for better clarity. ([e4601f21](https://github.com/royorange/flutter_dev_panel/commit/e4601f213838c78b6be26415bac6bf9a336e81c7))
 - **REFACTOR**: simplify Logger package integration with better API. ([8979bb99](https://github.com/royorange/flutter_dev_panel/commit/8979bb991da4bcbb0b11ee70fb6d49bad7f14e2e))
 - **FIX**: make DevPanelLoggerOutput extend LogOutput base class. ([8d94e755](https://github.com/royorange/flutter_dev_panel/commit/8d94e7556a43072943448d41c426f2b794849d23))
 - **FIX**: improve GraphQL query serialization and Logger package integration. ([878b9aad](https://github.com/royorange/flutter_dev_panel/commit/878b9aad0ffe69747a5f9595be2a6c4ab863c996))
 - **FIX**: downgrade test package version to fix flutter_test compatibility. ([a1dacadf](https://github.com/royorange/flutter_dev_panel/commit/a1dacadf7d585eeb782ea2ca61577791d915816c))
 - **FIX**: restore console package dependency to local path. ([389d7ef5](https://github.com/royorange/flutter_dev_panel/commit/389d7ef508ee7c659d5924ab205b505027f1d9c7))
 - **FIX**: resolve all code analysis warnings in console package. ([904ad2f8](https://github.com/royorange/flutter_dev_panel/commit/904ad2f8bd6980109ac57e7b1d3e3b4da7782a83))
 - **FIX**: resolve sub-package publishing issues. ([4151d69b](https://github.com/royorange/flutter_dev_panel/commit/4151d69b4e7c0009a62b40d50d0c7ced672032fd))
 - **FIX**: add required files for publishing and fix script. ([72ac1a91](https://github.com/royorange/flutter_dev_panel/commit/72ac1a91ceeb283d3fedf2e2a11419c60ff78bbe))
 - **FIX**: 优化测试用例. ([6d06cc34](https://github.com/royorange/flutter_dev_panel/commit/6d06cc346cc19dfa5589d039143868c9f878dfda))
 - **FIX**: 修复测试. ([583b978a](https://github.com/royorange/flutter_dev_panel/commit/583b978a9e759c68ba341bfe314a2302160e801e))
 - **FIX**: 调整日志项的对齐方式，改为垂直顶部对齐。. ([b165d213](https://github.com/royorange/flutter_dev_panel/commit/b165d2133b614c7e2ab898ec347e661d40a65ab9))
 - **FEAT**: 更新 pubspec.yaml 和 pubspec.lock 文件. ([ea4e9c71](https://github.com/royorange/flutter_dev_panel/commit/ea4e9c71f11120ea29759e21c1fc3be9c959ea16))
 - **FEAT**: 发布 1.0.0 版本，包含多个模块的重大更新. ([9a123185](https://github.com/royorange/flutter_dev_panel/commit/9a1231850d0f12b5ce9d94c0fa67e9e44b3dd1f4))
 - **FEAT**: 增强控制台页面和网络监控页面的搜索框功能. ([240cc258](https://github.com/royorange/flutter_dev_panel/commit/240cc258a0b0a9a9ea5a974f15fb8770a2d466fa))
 - **FEAT**: 更新文档和示例代码以反映 DevPanel 的重命名. ([3b49e94b](https://github.com/royorange/flutter_dev_panel/commit/3b49e94b588f4cb3067a43cf0cf32f0173350f4e))
 - **FEAT**: 更新 README 和示例代码以支持新的初始化方法. ([1950a15b](https://github.com/royorange/flutter_dev_panel/commit/1950a15bbaeb1e5463d1c987428075288cf8ecd9))
 - **FEAT**: add proper Logger package integration with zero configuration. ([5fb805c8](https://github.com/royorange/flutter_dev_panel/commit/5fb805c8cdaa5ae29808ca5e8064cd8995d0e1ca))
 - **FEAT**: add safe Logger package integration for production. ([2fb8bcae](https://github.com/royorange/flutter_dev_panel/commit/2fb8bcae9689c8a8fce94bfb63aa4523ed4e541e))
 - **FEAT**: 优化UI颜色和字体权重. ([bc88b700](https://github.com/royorange/flutter_dev_panel/commit/bc88b70040db8c9b3ddd857bd9e32cb9fb34c11f))
 - **FEAT**: 优化日志显示和处理功能. ([8314faac](https://github.com/royorange/flutter_dev_panel/commit/8314faac7161200028e1c0552366493244abbcbb))
 - **FEAT**: 增强日志控制功能. ([b047d901](https://github.com/royorange/flutter_dev_panel/commit/b047d9014c7f865fdfbf34cea08dd6c4b19ea55e))
 - **FEAT**: 移除控制台页面的自动滚动按钮并更新注释为英文. ([27d7b899](https://github.com/royorange/flutter_dev_panel/commit/27d7b899c2e53d2f3d07ea1ff398a47498038f87))
 - **FEAT**: 更新ConsoleModule和FAB组件. ([be517871](https://github.com/royorange/flutter_dev_panel/commit/be5178711c186cbec5ab25d325234aa3511b17e9))
 - **FEAT**: 增强自动滚动功能. ([eb51fd79](https://github.com/royorange/flutter_dev_panel/commit/eb51fd79a5b61804045de3561d7c3c0e3fd1c0d8))
 - **FEAT**: 更新日志捕获和控制台模块. ([15749fa2](https://github.com/royorange/flutter_dev_panel/commit/15749fa29ac1485ed8035f695f353d1ac53a1af1))
 - **FEAT**: 添加完整的 Console/Logs 模块. ([54af2da0](https://github.com/royorange/flutter_dev_panel/commit/54af2da0464d5d97e314c87529a52ece1241bc97))
 - **DOCS**: update version. ([1de0c531](https://github.com/royorange/flutter_dev_panel/commit/1de0c531d31254cbfec3d8927a2f3fb79eadec62))
 - **DOCS**: update docs. ([c723a57d](https://github.com/royorange/flutter_dev_panel/commit/c723a57d53858051292c52c956e77c99b341d85f))
 - **DOCS**: simplify README files for all packages. ([9c431166](https://github.com/royorange/flutter_dev_panel/commit/9c431166e0c8b932be16bf315f4c0d5f696c3933))

# Changelog

## 1.0.0

* Major release with stable API
* Enhanced log level detection with smart strategies
* Improved Logger package integration
* Better handling of GraphQL and JSON output
* Fixed emoji detection in multi-line Logger output

## 0.0.2

* Fixed Flutter version requirement to 3.10.0
* Updated documentation

## 0.0.1

* Initial release
