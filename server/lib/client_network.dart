/// Where a request came from, reduced to what the ingest keeps: the network
/// a caller is on, never the host.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

/// The address the request came from.
///
/// nginx appends the peer address it actually saw to `X-Forwarded-For`
/// (`$proxy_add_x_forwarded_for`), after whatever the client sent in that
/// header itself, so the *last* entry is the only one a client can't forge.
/// Without the header — a direct call over loopback, such as the multiplayer
/// server's — it is the socket's own peer address.
String clientIp(Request r) {
  final xff = r.headers['x-forwarded-for'];
  if (xff != null) {
    final last = xff.split(',').last.trim();
    if (last.isNotEmpty) return last;
  }
  final info = r.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) return info.remoteAddress.address;
  return '0.0.0.0';
}

/// The network [ip] is on — /24 for IPv4, /48 for IPv6, enough to group a
/// network but not to identify a host — as its CIDR [prefix] (what
/// `sessions.ip_prefix` stores) and its bare network [address] (what the
/// GeoIP lookup takes). Null when [ip] isn't an address.
({String prefix, String address})? networkOf(String ip) {
  final parsed = InternetAddress.tryParse(ip);
  if (parsed == null) return null;
  var bytes = parsed.rawAddress;
  // An IPv4-mapped IPv6 address (::ffff:a.b.c.d) is an IPv4 caller.
  if (bytes.length == 16 &&
      bytes.take(10).every((b) => b == 0) &&
      bytes[10] == 0xff &&
      bytes[11] == 0xff) {
    bytes = bytes.sublist(12);
  }
  final v4 = bytes.length == 4;
  // Keep the network's bytes, zero the host's, and let InternetAddress write
  // it out in canonical form (IPv6 lower-case and ::-compressed).
  final keep = v4 ? 3 : 6;
  final network = Uint8List(bytes.length)..setRange(0, keep, bytes);
  final address = InternetAddress.fromRawAddress(network).address;
  return (prefix: '$address/${keep * 8}', address: address);
}
