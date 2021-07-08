# kumulos_sdk_flutter_example

Demonstrates how to use the kumulos_sdk_flutter plugin.

## Getting Started

For this example to work, you will need:

- Credentials for your Kumulos app
- A `google-services.json` file for your FCM project
- An Apple developer team to provision iOS builds

To begin:

1. Edit `kumulos.json` to add your API Key and Secret Key from the Kumulos Dashboard
2. Add your `google-services.json` file to the `android/app/` directory
3. Open the `ios/Runner.xcworkspace` in Xcode and update:
   1. The development team used for signing the Runner and Extension targets
   2. The bundle identifier used for the Runner and Extension targets
   3. The group identifier on the Runner and Extension targets
