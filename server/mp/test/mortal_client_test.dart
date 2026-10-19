import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tilesense_mp/mortal.dart';

/// [MortalClient] talks to mortal_sidecar/server.py over real HTTP. That
/// service reads `Content-Length` and answers 413 without it, which is what
/// Dart's [HttpClient] sends when a request has no length set (it falls back
/// to chunked transfer encoding). These tests stand in for the sidecar with
/// the same rule, so a client change that drops the header fails here rather
/// than silently sending every Saeko move to SimpleBot.
void main() {
  late HttpServer server;
  late MortalClient client;
  final seen = <Map<String, Object?>>[];

  setUp(() async {
    seen.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final length = req.contentLength;
      void send(int code, Object body) {
        req.response
          ..statusCode = code
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
        req.response.close();
      }

      // As mortal_sidecar/server.py: no Content-Length (or an empty body) is a 413.
      if (req.uri.path != '/react') return send(404, {'error': 'not found'});
      if (length <= 0) return send(413, {'error': 'body too large'});
      final body = jsonDecode(await utf8.decoder.bind(req).join())
          as Map<String, Object?>;
      seen.add(body);
      send(200, {'reaction': null, 'riichi_discard': null});
    });
    client = MortalClient('http://127.0.0.1:${server.port}');
  });

  tearDown(() => server.close(force: true));

  test('ask sends a Content-Length body the sidecar accepts', () async {
    final reply = await client.ask(2, [
      {'type': 'start_kyoku', 'tehais': [
        for (var i = 0; i < 4; i++) List.filled(13, '1m')
      ]},
    ]);
    expect(reply, {'reaction': null, 'riichi_discard': null});
    expect(seen, hasLength(1));
    expect(seen.single['player_id'], 2);
  });

  test('ask sends only the asking seat\'s view of the hand', () async {
    await client.ask(1, [
      {'type': 'start_kyoku', 'tehais': [
        for (var i = 0; i < 4; i++) List.generate(13, (_) => '${i + 1}m')
      ]},
      {'type': 'tsumo', 'actor': 3, 'pai': '9s'},
    ]);
    final events = seen.single['events'] as List;
    final tehais = (events[1] as Map)['tehais'] as List;
    expect(tehais[1], everyElement('2m'));
    for (final other in [0, 2, 3]) {
      expect(tehais[other], everyElement('?'));
    }
    expect((events[2] as Map)['pai'], '?');
  });
}
