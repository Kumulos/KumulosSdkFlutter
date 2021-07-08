import 'dart:convert';
import 'dart:io';
import 'dart:math';

// https://www.scottbrady91.com/Dart/Generating-a-Crypto-Random-String-in-Dart
class Utils {
  static final Random _random = Random.secure();

  static String cryptoRandomString([int length = 32]) {
    var values = List<int>.generate(length, (i) => _random.nextInt(256));

    return base64Url.encode(values);
  }

  static Future<String> readResponse(HttpClientResponse response) async {
    final contents = StringBuffer();
    await for (var data in response.transform(utf8.decoder)) {
      contents.write(data);
    }
    return contents.toString();
  }
}
