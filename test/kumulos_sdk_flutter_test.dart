import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumulos_sdk_flutter/kumulos.dart';

void main() {
  const MethodChannel channel = MethodChannel('kumulos_sdk_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    // expect(await Kumulos.platformVersion, '42');
  });
}
