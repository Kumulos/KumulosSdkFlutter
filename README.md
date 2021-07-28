# Kumulos Flutter SDK

Kumulos provides tools to build and host backend storage for apps, send push notifications, view audience and behavior analytics, and report on adoption, engagement and performance.

## Get Started

Add the following dependency to your `pubspec.yaml` and run `pub install`:

```yaml
dependencies:
  kumulos_sdk_flutter: 1.1.0
```

Next, create a `kumulos.json` file in your project's root directory with Kumulos configuration:

```json
{
    "apiKey": "YOUR_API_KEY",
    "secretKey": "YOUR_SECRET_KEY",
    "enableCrashReporting": false,
    "inAppConsentStrategy": "in-app-disabled",
    "enableDeferredDeepLinking": false
}
```

Declare the asset in your `pubspec.yaml`:

```yaml
assets:
  - kumulos.json
```

In your Dart code, you can now import & use Kumulos features:

```dart
import 'package:kumulos_sdk_flutter/kumulos.dart';
var installId = await Kumulos.installId;
```

For more information on integrating the Flutter SDK with your project, please see the [Kumulos Flutter integration guide](https://docs.kumulos.com/developer-guide/sdk-reference/flutter).

## Contributing

Pull requests are welcome for any improvements you might wish to make. If it's something big and you're not sure about it yet, we'd be happy to discuss it first. You can either file an issue or drop us a line to [support@kumulos.com](mailto:support@kumulos.com).

## License

This project is licensed under the MIT license with portions licensed under the BSD 2-Clause license. See our LICENSE file and individual source files for more information.