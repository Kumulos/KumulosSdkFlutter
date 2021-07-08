import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'kumulos.dart';
import 'utils.dart';

const String crmBaseUrl = 'https://crm.kumulos.com';

class KumulosChannel {
  final String uuid;
  final String? name;
  final bool isSubscribed;
  final Map<String, dynamic>? meta;

  KumulosChannel.fromMap(Map<String, dynamic> map)
      : uuid = map['uuid'] as String,
        name = map['name'],
        isSubscribed = map['subscribed'],
        meta =
            map['meta'] != null ? Map<String, dynamic>.from(map['meta']) : null;
}

class PushChannelManager {
  final String apiKey;
  final String secretKey;
  final HttpClient _httpClient;

  PushChannelManager(this.apiKey, this.secretKey)
      : _httpClient = new HttpClient();

  Future<List<KumulosChannel>> listChannels() async {
    var encodedIdent = Uri.encodeComponent(await Kumulos.currentUserIdentifier);
    var res = await _makeRequest(
        method: 'GET',
        url: Uri.parse('$crmBaseUrl/v1/users/$encodedIdent/channels'));

    switch (res.statusCode) {
      case 200:
        // var data = await readJsonResponse<List<Map<String, dynamic>>>(res);
        var json = await Utils.readResponse(res);
        var decoded = jsonDecode(json);
        var data = List<Map<String, dynamic>>.from(decoded);
        return data
            .map((e) => KumulosChannel.fromMap(e))
            .toList(growable: false);
      default:
        throw 'error';
    }
  }

  Future<void> unsubscribe(List<String> uuids) async {
    await _changeChannelSubscriptions(method: 'DELETE', uuids: uuids);
  }

  Future<void> subscribe(List<String> uuids) async {
    await _changeChannelSubscriptions(method: 'POST', uuids: uuids);
  }

  Future<void> setSubscriptions(List<String> uuids) async {
    await _changeChannelSubscriptions(method: 'PUT', uuids: uuids);
  }

  Future<void> clearSubscriptions() async {
    await _changeChannelSubscriptions(
        method: 'PUT', uuids: [], allowEmptyUuids: true);
  }

  Future<KumulosChannel> createChannel(
      {required String uuid,
      bool subscribe = false,
      String? name,
      bool showInPortal = false,
      Map<String, dynamic>? meta}) async {
    if (uuid.length == 0) {
      throw Exception('Channel uuid must be specified for channel creation');
    }

    if (showInPortal && (name == null || name.length == 0)) {
      throw Exception(
          'Channel name must be specified for channel creation if the channel should be displayed in the portal');
    }

    const url = '$crmBaseUrl/v1/channels';

    var req = {
      'uuid': uuid,
      'name': name,
      'showInPortal': showInPortal,
      'meta': meta,
    };

    if (subscribe) {
      req['userIdentifier'] = await Kumulos.currentUserIdentifier;
    }

    var res = await _makeRequest(
        method: 'POST', url: Uri.parse(url), body: jsonEncode(req));

    if (res.statusCode != 201) {
      throw Exception('Failed to create channel, status: ${res.statusCode}');
    }

    var json = await Utils.readResponse(res);
    var decoded = jsonDecode(json);
    var data = Map<String, dynamic>.from(decoded);

    return KumulosChannel.fromMap(data);
  }

  Future<HttpClientResponse> _makeRequest(
      {required String method, required Uri url, String? body}) async {
    var req = await _httpClient.openUrl(method, url);

    req.headers.add('Authorization',
        'Basic ' + base64Encode(utf8.encode('$apiKey:$secretKey')));
    req.headers.add('Accept', 'application/json');
    req.headers.contentType =
        new ContentType('application', 'json', charset: 'utf-8');

    if (body != null) {
      req.write(body);
    }

    return req.close();
  }

  Future<HttpClientResponse> _changeChannelSubscriptions(
      {required String method,
      required List<String> uuids,
      bool allowEmptyUuids = false}) async {
    if (!allowEmptyUuids && uuids.length == 0) {
      throw Exception('Provide an array of channel uuids');
    }

    var userIdentifier = await Kumulos.currentUserIdentifier;
    var url =
        '$crmBaseUrl/v1/users/${Uri.encodeComponent(userIdentifier)}/channels/subscriptions';

    var data = {'uuids': uuids};

    var res = await _makeRequest(
        method: method, url: Uri.parse(url), body: jsonEncode(data));

    if (res.statusCode == 404) {
      throw Exception('Some channels are not found');
    } else if (res.statusCode > 299) {
      throw Exception(
          'Failed to update channel subscription. Status ${res.statusCode}');
    }

    return res;
  }
}
