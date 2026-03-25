# Flutter Dev Panel - Device Module

[![pub package](https://img.shields.io/pub/v/flutter_dev_panel_device.svg)](https://pub.dev/packages/flutter_dev_panel_device)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.13.0-blue)](https://flutter.dev)

Device information module for Flutter Dev Panel that provides detailed insights into device specifications and system information.

## Features

- **Hardware details** - Device model, manufacturer, and unique identifiers
- **Screen metrics** - Resolution, pixel density, PPI, and physical size
- **System info** - Operating system version and SDK levels
- **Memory status** - Available and total RAM
- **App details** - Package name, version, build number
- **Battery status** - Battery level and charging state

## Installation

[![flutter_dev_panel version](https://img.shields.io/pub/v/flutter_dev_panel.svg?label=flutter_dev_panel)](https://pub.dev/packages/flutter_dev_panel)

```yaml
dependencies:
  flutter_dev_panel: ^latest_version  # Replace with latest version from badges above
  flutter_dev_panel_device: ^latest_version
```

## Usage

```dart
import 'package:flutter_dev_panel/flutter_dev_panel.dart';
import 'package:flutter_dev_panel_device/flutter_dev_panel_device.dart';

void main() {
  // Initialize with device module
  DevPanel.initialize(
    modules: [DeviceModule()],
  );
  
  runApp(MyApp());
}

// Access device information
final controller = DeviceInfoController.instance;
await controller.loadDeviceInfo();

final deviceInfo = controller.deviceInfo;
if (deviceInfo != null) {
  print('Device: ${deviceInfo.deviceModel}');
  print('OS: ${deviceInfo.operatingSystem} ${deviceInfo.osVersion}');
  print('Screen: ${deviceInfo.screenWidth}x${deviceInfo.screenHeight}');
  print('PPI: ${deviceInfo.pixelsPerInch}');
}
```


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.