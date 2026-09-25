/// TileSense telemetry ingest.
///
/// One endpoint, `POST /ingest`, accepts a JSON batch from the client
/// (`navigator.sendBeacon`, so `text/plain`), captures the caller IP from the
/// proxy headers, reduces it to an HMAC + network prefix (the raw address is
/// never stored), looks the network's country, region and city up in
/// `geoip_city` (loaded by `deploy.sh geoip`), and upserts the batch into
/// Postgres. It always answers `204` — a beacon can't act on an error anyway —
/// and logs failures for monitoring.
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
import 'package:tilesense_ingest/client_network.dart';

const _maxBody = 65536;
const _maxEvents = 200;
const _allowedTypes = {
  'match_start',
  'round_start',
  'human_decision',
  'round_end',
  'match_end',
  'setting_change',
  'seat_event',
};
final _uuidRe = RegExp(r'^[0-9a-fA-F-]{36}$');

late final Pool _pool;
late final List<int> _hmacKey;
late final String _allowOrigin;

Future<void> main() async {
  final env = Platform.environment;
  _hmacKey = utf8.encode(_require(env, 'IP_HMAC_SECRET'));
  _allowOrigin = env['ALLOW_ORIGIN'] ?? '*';
  final port = int.tryParse(env['PORT'] ?? '') ?? 8787;
  final bindAddr =
      env['BIND_ADDR']?.isNotEmpty == true ? env['BIND_ADDR']! : '127.0.0.1';

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

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
  final server = await shelf_io.serve(handler, bindAddr, port);
  _log('listening on $bindAddr:${server.port}');
}

Future<Response> _ingest(Request req) async {
  try {
    final raw = await req.read().fold<List<int>>(
        <int>[], (a, b) => a.length > _maxBody ? a : (a..addAll(b)));
    if (raw.length > _maxBody) return _cors(Response(413));

    final batch = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    final clientId = batch['client_id'] as String?;
    final sessionId = batch['session_id'] as String?;
    if (clientId == null ||
        !_uuidRe.hasMatch(clientId) ||
        sessionId == null ||
        !_uuidRe.hasMatch(sessionId)) {
      return _cors(Response(400, body: 'bad ids'));
    }
    final events = (batch['events'] as List?) ?? const [];
    if (events.length > _maxEvents) return _cors(Response(413));

    final ip = clientIp(req);
    final ipHmac = Hmac(sha256, _hmacKey).convert(utf8.encode(ip)).bytes;
    final network = networkOf(ip);
    final ipPrefix = network?.prefix;
    final place = await _placeOf(network?.address);
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
            (session_id, client_id, app_version, user_agent, ip_prefix, ip_hmac,
             geo_country, geo_region, geo_city)
          values (@sid, @cid, @ver, @ua, @pfx, @hmac, @cc, @region, @city)
          on conflict (session_id) do nothing
        '''),
        parameters: {
          'sid': sessionId,
          'cid': clientId,
          'ver': appVersion,
          'ua': ua,
          'pfx': ipPrefix,
          'hmac': ipHmac,
          'cc': place?.country,
          'region': place?.region,
          'city': place?.city,
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
    _logErr('ingest failed: $e\n$st');
    // A beacon can't retry — swallow and move on.
    return _cors(Response(204));
  }
}

Future<void> _applyEvent(
    TxSession s, String sessionId, Map<String, dynamic> e) async {
  final type = e['type'] as String?;
  if (type == null || !_allowedTypes.contains(type)) return;
  final at = DateTime.tryParse(e['t'] as String? ?? '')?.toUtc() ??
      DateTime.now().toUtc();

  switch (type) {
    case 'match_start':
      // Multiplayer (mode: 'multiplayer') has no `seed`/`fast_mode`/
      // `autoplay`/`guide_shown` of its own — single-player-only concepts —
      // so those columns are left null there; `room_code`/`timer_seconds`/
      // `seat_guest_ids` are the multiplayer-only converse, left null for
      // single-player. See `server/migrations/0003_multiplayer.sql`.
      await s.execute(
        Sql.named('''
          insert into matches
            (match_id, session_id, seed, hanchan, fast_mode,
             autoplay_at_start, guide_shown_at_start, seat_characters,
             seat_is_bot, started_at, mode, room_code, timer_seconds,
             seat_guest_ids)
          values (@m, @s, @seed, @han, @fast, @auto, @guide, @chars, @bots,
                  @at, @mode, @room, @timer, @guests)
          on conflict (match_id) do nothing
        '''),
        parameters: {
          'm': e['match_id'],
          's': sessionId,
          'seed': e['seed'],
          'han': e['hanchan'],
          'fast': e['fast_mode'],
          'auto': e['autoplay'],
          'guide': e['guide_visible'],
          'at': at,
          'chars': _stringList(e['seat_characters']),
          'bots': _boolList(e['seat_is_bot']),
          'mode': (e['mode'] as String?) ?? 'single',
          'room': e['room_code'],
          'timer': e['timer_seconds'],
          'guests': _stringList(e['seat_guest_ids']),
        },
      );
      // One session per human seat, for a shared multiplayer match — see
      // `match_participants`. Absent (or empty) for single-player, where the
      // one caller-level session already covers the whole match.
      final participants = e['participants'];
      if (participants is List) {
        for (final p in participants) {
          if (p is! Map) continue;
          final guestId = p['guestId'] as String?;
          final seatSessionId = p['sessionId'] as String?;
          final seat = p['seat'];
          if (guestId == null || seatSessionId == null || seat == null) {
            continue;
          }
          await s.execute(
            Sql.named('''
              insert into clients (client_id) values (@id)
              on conflict (client_id) do update set last_seen = now()
            '''),
            parameters: {'id': guestId},
          );
          await s.execute(
            Sql.named('''
              insert into sessions (session_id, client_id)
              values (@sid, @cid)
              on conflict (session_id) do nothing
            '''),
            parameters: {'sid': seatSessionId, 'cid': guestId},
          );
          await s.execute(
            Sql.named('''
              insert into match_participants
                (match_id, session_id, seat, guest_id)
              values (@m, @sid, @seat, @gid)
              on conflict (match_id, seat) do nothing
            '''),
            parameters: {
              'm': e['match_id'],
              'sid': seatSessionId,
              'seat': int.tryParse('$seat'),
              'gid': guestId,
            },
          );
        }
      }
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
          'r': e['round_id'],
          'm': e['match_id'],
          'idx': e['round_index'],
          'wind': e['round_wind'],
          'hand': e['hand_number'],
          'dealer': e['dealer_seat'],
          'honba': e['honba'],
          'sticks': e['riichi_sticks'],
          'at': at,
        },
      );
    case 'human_decision':
      // Single-player always reports the one human seat and omits
      // `actor_seat` entirely, which is why this defaults to 0 — that
      // default is exactly single-player's fixed human seat there, not a
      // guess. Multiplayer always sends the real seat, since any of the
      // four can act.
      await s.execute(
        Sql.named('''
          insert into events
            (session_id, match_id, round_id, occurred_at, kind, actor_seat,
             tile, auto, guide_shown, guide_reco, followed_guide)
          values (@s, @m, @r, @at, @kind, @seat, @tile, @auto, @guide, @reco, @follow)
        '''),
        parameters: {
          's': sessionId,
          'm': e['match_id'],
          'r': e['round_id'],
          'at': at,
          'kind': e['kind'],
          'seat': (e['actor_seat'] as num?)?.toInt() ?? 0,
          'tile': e['tile'],
          'auto': e['auto'],
          'guide': e['guide_visible'],
          'reco': e['guide_reco'],
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
          'r': e['round_id'],
          'at': at,
          'kind': e['end_kind'],
          'win': _intList(e['winners']),
          'loser': e['loser'],
          'han': e['han'],
          'fu': e['fu'],
          'pts': e['points'],
          'yaku': jsonEncode(e['yaku'] ?? const []),
          'deltas': _intList(e['point_deltas']),
          'kept': e['dealer_kept'],
        },
      );
    case 'match_end':
      // `seat_places` is multiplayer's per-seat counterpart to
      // `human_place` — every seat's final standing rather than just the
      // one human's. Single-player never sends it, so it stays null there.
      await s.execute(
        Sql.named('''
          insert into matches (match_id, session_id, ended_at, ended_reason,
                               final_points, human_seat, human_place,
                               seat_places)
          values (@m, @s, @at, @reason, @fp, @seat, @place, @places)
          on conflict (match_id) do update set
            ended_at = excluded.ended_at,
            ended_reason = excluded.ended_reason,
            final_points = excluded.final_points,
            human_seat = excluded.human_seat,
            human_place = excluded.human_place,
            seat_places = excluded.seat_places
          where matches.ended_reason is distinct from 'game_end'
        '''),
        parameters: {
          'm': e['match_id'],
          's': sessionId,
          'at': at,
          'reason': e['reason'],
          'fp': _intList(e['final_points']),
          'seat': e['human_seat'],
          'place': e['human_place'],
          'places': _intList(e['seat_places']),
        },
      );
    case 'setting_change':
      await s.execute(
        Sql.named('''
          insert into events (session_id, match_id, occurred_at, kind, payload)
          values (@s, @m, @at, 'setting_change', @p)
        '''),
        parameters: {
          's': sessionId,
          'm': e['match_id'],
          'at': at,
          'p': jsonEncode({'setting': e['setting'], 'value': e['value']}),
        },
      );
    case 'seat_event':
      // A seat joining, leaving, reconnecting, or being converted to a bot
      // — multiplayer only. `actor_seat` is real here too, same as
      // `human_decision` above.
      await s.execute(
        Sql.named('''
          insert into events
            (session_id, match_id, occurred_at, kind, actor_seat, payload)
          values (@s, @m, @at, 'seat_event', @seat, @p)
        '''),
        parameters: {
          's': sessionId,
          'm': e['match_id'],
          'at': at,
          'seat': (e['actor_seat'] as num?)?.toInt(),
          'p': jsonEncode({
            'event': e['event'],
            'guest_id': e['guest_id'],
            'reason': e['reason'],
          }),
        },
      );
  }
}

// --- helpers ---------------------------------------------------------------

/// Single-line operational logging, `[ingest]`-tagged so it stands apart from
/// shelf's own `logRequests()` output. Info to stdout, failures to stderr.
void _log(String msg) => stdout.writeln('[ingest] $msg');
void _logErr(String msg) => stderr.writeln('[ingest] $msg');

Response _cors(Response r) => r.change(headers: {
      'access-control-allow-origin': _allowOrigin,
      'access-control-allow-methods': 'POST, OPTIONS',
      'access-control-allow-headers': 'content-type',
    });

/// Where [address] (a network address from [networkOf]) is, from the
/// `geoip_city` ranges — null when it isn't covered, the table is empty, or
/// the lookup fails for any reason. Run on its own, outside the batch's
/// transaction, so a GeoIP problem can only cost a session its location,
/// never the batch. Only the network address is sent, never the caller's own.
Future<({String country, String? region, String? city})?> _placeOf(
    String? address) async {
  if (address == null) return null;
  try {
    final rows = await _pool.execute(
      Sql.named('''
        select country, region, city from (
          select country, region, city, ip_end from geoip_city
          where ip_start <= @a::inet
          order by ip_start desc
          limit 1
        ) g
        where g.ip_end >= @a::inet
      '''),
      parameters: {'a': address},
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      country: r[0] as String,
      region: r[1] as String?,
      city: r[2] as String?,
    );
  } catch (e) {
    _logErr('geoip lookup failed: $e');
    return null;
  }
}

List<int>? _intList(Object? v) =>
    v is List ? [for (final x in v) (x as num?)?.toInt() ?? 0] : null;

List<String>? _stringList(Object? v) =>
    v is List ? [for (final x in v) x as String? ?? ''] : null;

List<bool>? _boolList(Object? v) =>
    v is List ? [for (final x in v) x as bool? ?? false] : null;

String _require(Map<String, String> env, String key) {
  final v = env[key];
  if (v == null || v.isEmpty) {
    _logErr('missing required env $key');
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
