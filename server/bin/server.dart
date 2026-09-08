/// TileSense telemetry ingest.
///
/// One endpoint, `POST /ingest`, accepts a JSON batch from the client
/// (`navigator.sendBeacon`, so `text/plain`), captures the caller IP from the
/// proxy headers, reduces it to an HMAC + network prefix (the raw address is
/// never stored), and upserts the batch into Postgres. It always answers `204`
/// — a beacon can't act on an error anyway — and logs failures for monitoring.
///
/// Env:
///   DATABASE_URL       postgres://user:pass@host:port/db?sslmode=require
///   IP_HMAC_SECRET     >=32 random bytes (openssl rand -hex 32)
///   ALLOW_ORIGIN       CORS origin to echo (default '*')
///   PORT               listen port (default 8787)
///   BIND_ADDR          listen address (default 127.0.0.1; set 0.0.0.0 behind a
///                      platform router such as App Platform)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const _maxBody = 65536;
const _maxEvents = 200;
const _allowedTypes = {
  'match_start',
  'round_start',
  'human_decision',
  'round_end',
  'match_end',
  'setting_change',
};
final _uuidRe =
    RegExp(r'^[0-9a-fA-F-]{36}$');

late final Pool _pool;
late final List<int> _hmacKey;
late final String _allowOrigin;

Future<void> main() async {
  final env = Platform.environment;
  _hmacKey = utf8.encode(_require(env, 'IP_HMAC_SECRET'));
  _allowOrigin = env['ALLOW_ORIGIN'] ?? '*';
  final port = int.tryParse(env['PORT'] ?? '') ?? 8787;
  final bindAddr = env['BIND_ADDR']?.isNotEmpty == true
      ? env['BIND_ADDR']!
      : '127.0.0.1';

  _pool = Pool.withEndpoints(
    [_endpointFromUrl(_require(env, 'DATABASE_URL'))],
    settings: PoolSettings(
      maxConnectionCount: 8,
      sslMode: _sslModeFromUrl(_require(env, 'DATABASE_URL')),
    ),
  );
  // Fail fast if the DB is unreachable at boot.
  await _pool.execute('select 1');

  final router = Router()
    ..get('/healthz', (_) => Response.ok('ok'))
    ..get('/readyz', (_) async {
      try {
        await _pool.execute('select 1');
        return Response.ok('ready');
      } catch (_) {
        return Response.internalServerError(body: 'db down');
      }
    })
    ..options('/ingest', (_) => _cors(Response(204)))
    ..post('/ingest', _ingest);

  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
  final server = await shelf_io.serve(handler, bindAddr, port);
  stdout.writeln('ingest listening on $bindAddr:${server.port}');
}

Future<Response> _ingest(Request req) async {
  try {
    final raw = await req.read().fold<List<int>>(
        <int>[], (a, b) => a.length > _maxBody ? a : (a..addAll(b)));
    if (raw.length > _maxBody) return _cors(Response(413));

    final batch = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    final clientId = batch['client_id'] as String?;
    final sessionId = batch['session_id'] as String?;
    if (clientId == null || !_uuidRe.hasMatch(clientId) ||
        sessionId == null || !_uuidRe.hasMatch(sessionId)) {
      return _cors(Response(400, body: 'bad ids'));
    }
    final events = (batch['events'] as List?) ?? const [];
    if (events.length > _maxEvents) return _cors(Response(413));

    final ip = _clientIp(req);
    final ipHmac = Hmac(sha256, _hmacKey).convert(utf8.encode(ip)).bytes;
    final ipPrefix = _networkPrefix(ip);
    final country = req.headers['cf-ipcountry'];
    final ua = (batch['user_agent'] as String?) ?? req.headers['user-agent'];
    final appVersion = batch['app_version'] as String?;

    await _pool.runTx((s) async {
      await s.execute(
        Sql.named('''
          insert into clients (client_id, first_ua)
          values (@id, @ua)
          on conflict (client_id) do update set last_seen = now()
        '''),
        parameters: {'id': clientId, 'ua': ua},
      );
      await s.execute(
        Sql.named('''
          insert into sessions
            (session_id, client_id, app_version, user_agent, ip_prefix, ip_hmac, geo_country)
          values (@sid, @cid, @ver, @ua, @pfx, @hmac, @cc)
          on conflict (session_id) do nothing
        '''),
        parameters: {
          'sid': sessionId, 'cid': clientId, 'ver': appVersion, 'ua': ua,
          'pfx': ipPrefix, 'hmac': ipHmac, 'cc': country,
        },
      );
      for (final e in events) {
        if (e is Map<String, dynamic>) {
          await _applyEvent(s, sessionId, e);
        }
      }
    });
    return _cors(Response(204));
  } catch (e, st) {
    stderr.writeln('ingest error: $e\n$st');
    // A beacon can't retry — swallow and move on.
    return _cors(Response(204));
  }
}

Future<void> _applyEvent(
    TxSession s, String sessionId, Map<String, dynamic> e) async {
  final type = e['type'] as String?;
  if (type == null || !_allowedTypes.contains(type)) return;
  final at = DateTime.tryParse(e['t'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc();

  switch (type) {
    case 'match_start':
      await s.execute(
        Sql.named('''
          insert into matches
            (match_id, session_id, seed, hanchan, fast_mode,
             autoplay_at_start, guide_shown_at_start, started_at)
          values (@m, @s, @seed, @han, @fast, @auto, @guide, @at)
          on conflict (match_id) do nothing
        '''),
        parameters: {
          'm': e['match_id'], 's': sessionId, 'seed': e['seed'],
          'han': e['hanchan'], 'fast': e['fast_mode'],
          'auto': e['autoplay'], 'guide': e['guide_visible'], 'at': at,
        },
      );
    case 'round_start':
      await s.execute(
        Sql.named('''
          insert into rounds
            (round_id, match_id, round_index, round_wind, hand_number,
             dealer_seat, honba, riichi_sticks, started_at)
          values (@r, @m, @idx, @wind, @hand, @dealer, @honba, @sticks, @at)
          on conflict (round_id) do nothing
        '''),
        parameters: {
          'r': e['round_id'], 'm': e['match_id'], 'idx': e['round_index'],
          'wind': e['round_wind'], 'hand': e['hand_number'],
          'dealer': e['dealer_seat'], 'honba': e['honba'],
          'sticks': e['riichi_sticks'], 'at': at,
        },
      );
    case 'human_decision':
      await s.execute(
        Sql.named('''
          insert into events
            (session_id, match_id, round_id, occurred_at, kind, actor_seat,
             tile, auto, guide_shown, guide_reco, followed_guide)
          values (@s, @m, @r, @at, @kind, 0, @tile, @auto, @guide, @reco, @follow)
        '''),
        parameters: {
          's': sessionId, 'm': e['match_id'], 'r': e['round_id'], 'at': at,
          'kind': e['kind'], 'tile': e['tile'], 'auto': e['auto'],
          'guide': e['guide_visible'], 'reco': e['guide_reco'],
          'follow': e['followed_guide'],
        },
      );
    case 'round_end':
      await s.execute(
        Sql.named('''
          update rounds set
            ended_at = @at, end_kind = @kind, winners = @win, loser_seat = @loser,
            han = @han, fu = @fu, points = @pts, yaku = @yaku,
            point_deltas = @deltas, dealer_kept = @kept
          where round_id = @r
        '''),
        parameters: {
          'r': e['round_id'], 'at': at, 'kind': e['end_kind'],
          'win': _intList(e['winners']), 'loser': e['loser'],
          'han': e['han'], 'fu': e['fu'], 'pts': e['points'],
          'yaku': jsonEncode(e['yaku'] ?? const []),
          'deltas': _intList(e['point_deltas']), 'kept': e['dealer_kept'],
        },
      );
    case 'match_end':
      await s.execute(
        Sql.named('''
          insert into matches (match_id, session_id, ended_at, ended_reason,
                               final_points, human_seat, human_place)
          values (@m, @s, @at, @reason, @fp, @seat, @place)
          on conflict (match_id) do update set
            ended_at = excluded.ended_at,
            ended_reason = excluded.ended_reason,
            final_points = excluded.final_points,
            human_seat = excluded.human_seat,
            human_place = excluded.human_place
          where matches.ended_reason is distinct from 'game_end'
        '''),
        parameters: {
          'm': e['match_id'], 's': sessionId, 'at': at, 'reason': e['reason'],
          'fp': _intList(e['final_points']), 'seat': e['human_seat'],
          'place': e['human_place'],
        },
      );
    case 'setting_change':
      await s.execute(
        Sql.named('''
          insert into events (session_id, match_id, occurred_at, kind, payload)
          values (@s, @m, @at, 'setting_change', @p)
        '''),
        parameters: {
          's': sessionId, 'm': e['match_id'], 'at': at,
          'p': jsonEncode({'setting': e['setting'], 'value': e['value']}),
        },
      );
  }
}

// --- helpers ---------------------------------------------------------------

Response _cors(Response r) => r.change(headers: {
      'access-control-allow-origin': _allowOrigin,
      'access-control-allow-methods': 'POST, OPTIONS',
      'access-control-allow-headers': 'content-type',
    });

String _clientIp(Request r) {
  final xff = r.headers['x-forwarded-for'];
  if (xff != null && xff.trim().isNotEmpty) return xff.split(',').first.trim();
  final cf = r.headers['cf-connecting-ip'];
  if (cf != null && cf.trim().isNotEmpty) return cf.trim();
  final info = r.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) return info.remoteAddress.address;
  return '0.0.0.0';
}

/// /24 for IPv4, /48 for IPv6 — enough to group a network, not to identify a host.
String _networkPrefix(String ip) {
  if (ip.contains(':')) {
    final parts = ip.split(':');
    return '${parts.take(3).join(':')}::/48';
  }
  final o = ip.split('.');
  if (o.length == 4) return '${o[0]}.${o[1]}.${o[2]}.0/24';
  return ip;
}

List<int>? _intList(Object? v) =>
    v is List ? [for (final x in v) (x as num?)?.toInt() ?? 0] : null;

String _require(Map<String, String> env, String key) {
  final v = env[key];
  if (v == null || v.isEmpty) {
    stderr.writeln('missing required env $key');
    exit(2);
  }
  return v;
}

Endpoint _endpointFromUrl(String url) {
  final u = Uri.parse(url);
  final userInfo = u.userInfo.split(':');
  return Endpoint(
    host: u.host,
    port: u.hasPort ? u.port : 5432,
    database: u.pathSegments.isNotEmpty ? u.pathSegments.first : 'postgres',
    username: userInfo.isNotEmpty ? Uri.decodeComponent(userInfo[0]) : null,
    password: userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : null,
  );
}

SslMode _sslModeFromUrl(String url) {
  final m = Uri.parse(url).queryParameters['sslmode'];
  return switch (m) {
    'disable' => SslMode.disable,
    'verify-full' => SslMode.verifyFull,
    _ => SslMode.require,
  };
}
