/// TileSense multiplayer game server entrypoint.
///
/// Env:
///   PORT        listen port (default 8789)
///   BIND_ADDR   listen address (default 127.0.0.1; set 0.0.0.0 behind a
///               platform router such as nginx)
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/server.dart';

Future<void> main() async {
  final env = Platform.environment;
  final port = int.tryParse(env['PORT'] ?? '') ?? 8789;
  final bindAddr =
      env['BIND_ADDR']?.isNotEmpty == true ? env['BIND_ADDR']! : '127.0.0.1';

  final manager = RoomManager();
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(buildMultiplayerHandler(manager));
  final server = await shelf_io.serve(handler, bindAddr, port);
  stdout.writeln('[mp] listening on ${server.address.host}:${server.port}');
}
