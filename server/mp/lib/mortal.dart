/// Asks the Mortal sidecar (mortal_sidecar/server.py) for a bot Saeko's
/// moves in a multiplayer riichi game — the server's counterpart of the
/// app's `MortalAdvisor` (flutter_client/lib/game/mortal_advisor.dart).
///
/// Off unless `MORTAL_URL` is set (`http://127.0.0.1:8790` in production,
/// see deploy/tilesense-mp.service); without it, or whenever the sidecar
/// fails, Saeko plays on `SimpleBot` like every other bot.
library;

import 'dart:convert';
import 'dart:io';

import 'package:mahjong_core/mahjong_core.dart';

/// Posts one seat's view of a hand and returns Mortal's reply; throws on
/// any failure.
typedef MortalAsk = Future<Map<String, Object?>> Function(
    int seat, List<MjaiEvent> events);

class MortalClient {
  MortalClient(String url) : _url = Uri.parse('$url/react');
  final Uri _url;
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2);

  /// The live client, or null when `MORTAL_URL` is unset. [env] is a test
  /// seam.
  static MortalClient? maybe([Map<String, String>? env]) {
    final url = (env ?? Platform.environment)['MORTAL_URL'];
    return url == null || url.isEmpty ? null : MortalClient(url);
  }

  /// Mortal's reply for [seat]. [events] is the hand with nothing hidden;
  /// only [seat]'s own view of it ([mjaiView]) is sent.
  Future<Map<String, Object?>> ask(int seat, List<MjaiEvent> events) async {
    Future<Map<String, Object?>> post() async {
      final req = await _http.postUrl(_url);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(
          {'player_id': seat, 'events': mjaiView(events, seat)}));
      final res = await req.close();
      final body = jsonDecode(await res.transform(utf8.decoder).join())
          as Map<String, Object?>;
      if (res.statusCode != 200) throw StateError('Mortal: ${body['error']}');
      return body;
    }

    return post().timeout(const Duration(seconds: 3));
  }
}
