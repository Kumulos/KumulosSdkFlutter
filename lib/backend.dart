import 'dart:async';
import 'dart:convert';

import 'dart:io';

import './utils.dart';

const rpcBaseUrl = 'https://api.kumulos.com';

enum KumulosRpcResponseCode {
  SUCESS,
  NOT_AUTHORISED,
  NO_SUCH_METHOD,
  NO_SUCH_FORMAT,
  ACCOUNT_SUSPENDED,
  INVALID_REQUEST,
  UNKNOWN_SERVER_ERROR,
  DATABASE_ERROR
}

KumulosRpcResponseCode _responseCodeFromInt(int code) {
  switch (code) {
    case 1:
      return KumulosRpcResponseCode.SUCESS;
    case 2:
      return KumulosRpcResponseCode.NOT_AUTHORISED;
    case 4:
      return KumulosRpcResponseCode.NO_SUCH_METHOD;
    case 8:
      return KumulosRpcResponseCode.NO_SUCH_FORMAT;
    case 16:
      return KumulosRpcResponseCode.ACCOUNT_SUSPENDED;
    case 32:
      return KumulosRpcResponseCode.INVALID_REQUEST;
    case 64:
      return KumulosRpcResponseCode.UNKNOWN_SERVER_ERROR;
    case 128:
      return KumulosRpcResponseCode.DATABASE_ERROR;
    default:
      throw 'Unknown code';
  }
}

class KumulosRpcResult {
  final KumulosRpcResponseCode responseCode;
  final String responseMessage;
  final dynamic payload;

  KumulosRpcResult(this.responseCode, this.responseMessage, this.payload);
}

class KumulosBackendClient {
  final String _apiKey;
  final String _secretKey;
  final HttpClient _httpClient;
  final String _installId;

  static String _sessionToken = Utils.cryptoRandomString();

  KumulosBackendClient(this._apiKey, this._secretKey, this._installId)
      : _httpClient = new HttpClient();

  Future<KumulosRpcResult> call(
      {required String methodAlias, Map<String, Object>? params}) async {
    var res = await _makeRequest(
        method: 'POST',
        url: Uri.parse('$rpcBaseUrl/b2.2/$_apiKey/$methodAlias.json'),
        body: jsonEncode(_makeRpcBody(params)));

    switch (res.statusCode) {
      case 200:
        var json = await Utils.readResponse(res);
        var decoded = jsonDecode(json);
        var data = Map<String, dynamic>.from(decoded);
        var code = _responseCodeFromInt(data['responseCode']);

        String sessionToken = data['sessionToken'] ?? _sessionToken;
        _sessionToken = sessionToken;

        return KumulosRpcResult(code, data['responseMessage'], data['payload']);
      default:
        throw 'error';
    }
  }

  Map<String, dynamic> _makeRpcBody(Map<String, dynamic>? params) {
    Map<String, dynamic> body = {
      "installId": _installId,
      "sessionToken": _sessionToken
    };

    if (params != null) {
      body['params'] = params;
    }

    return body;
  }

  Future<HttpClientResponse> _makeRequest(
      {required String method, required Uri url, String? body}) async {
    var req = await _httpClient.openUrl(method, url);

    req.headers.add('Authorization',
        'Basic ' + base64Encode(utf8.encode('$_apiKey:$_secretKey')));
    req.headers.add('Accept', 'application/json');
    req.headers.contentType =
        new ContentType('application', 'json', charset: 'utf-8');

    if (body != null) {
      req.write(body);
    }

    return req.close();
  }
}
