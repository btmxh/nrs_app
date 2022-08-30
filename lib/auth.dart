import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nrs_app/utils.dart';
import 'package:url_launcher/url_launcher.dart';

class MALTokens {
  String refreshToken;
  String accessToken;

  MALTokens(this.refreshToken, this.accessToken);
}

Future<MALTokens> refreshMALToken(
    http.Client client, String refreshToken, String malClientId) async {
  final response = await client.post(
      Uri.https(
        'myanimelist.net',
        '/v1/oauth2/token',
      ),
      body: {
        'grant_type': 'refresh_token',
        'client_id': malClientId,
        'refresh_token': refreshToken,
      });
  if (!response.ok) {
    throw HttpException(response.statusCode, response.body);
  }

  var json = await compute(jsonDecode, response.body);
  return MALTokens(json['refresh_token'], json['access_token']);
}

String malRandomCodeChallenge() {
  const chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  return String.fromCharCodes(Iterable.generate(
      128, (_) => chars.codeUnitAt(Random.secure().nextInt(chars.length))));
}

Future<void> malAuthorize(String codeChallenge, String malClientId) async {
  await launchUrl(
      Uri.https("myanimelist.net", "v1/oauth2/authorize", {
        'response_type': 'code',
        'client_id': malClientId,
        'code_challenge': codeChallenge,
        'state': 'nrs_request',
      }),
      mode: LaunchMode.externalApplication);
}

Future<MALTokens> malExchangeCode(http.Client client, String code,
    String codeVerifier, String malClientId) async {
  final response = await client
      .post(Uri.https("myanimelist.net", "/v1/oauth2/token"), body: {
    'client_id': malClientId,
    'code': code,
    'code_verifier': codeVerifier,
    'grant_type': 'authorization_code',
  });

  if (!response.ok) {
    throw HttpException(response.statusCode, response.body);
  }

  var json = await compute(jsonDecode, response.body);
  return MALTokens(json['refresh_token'], json['access_token']);
}

Future<void> aniListAuthorize(String aniListClientId) async {
  await launchUrl(
    Uri.https(
      "anilist.co",
      "/api/v2/oauth/authorize",
      {'client_id': aniListClientId, 'response_type': 'token'},
    ),
    mode: LaunchMode.externalApplication,
  );
}
