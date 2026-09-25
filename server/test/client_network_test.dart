import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tilesense_ingest/client_network.dart';

Request _req({String? xff}) => Request(
      'POST',
      Uri.parse('http://localhost/ingest'),
      headers: {if (xff != null) 'x-forwarded-for': xff},
    );

void main() {
  group('clientIp', () {
    test('takes the address nginx appended, not one the client sent', () {
      expect(clientIp(_req(xff: '203.0.113.9')), '203.0.113.9');
      // A client that sends its own X-Forwarded-For gets nginx's real peer
      // address appended after it.
      expect(clientIp(_req(xff: '1.2.3.4, 203.0.113.9')), '203.0.113.9');
      expect(clientIp(_req(xff: '1.2.3.4,203.0.113.9 ')), '203.0.113.9');
    });

    test('ignores a forged Cloudflare header', () {
      final r = Request('POST', Uri.parse('http://localhost/ingest'),
          headers: {'cf-connecting-ip': '1.2.3.4'});
      expect(clientIp(r), isNot('1.2.3.4'));
    });

    test('falls back when there is no usable header', () {
      expect(clientIp(_req()), '0.0.0.0');
      expect(clientIp(_req(xff: ' , ')), '0.0.0.0');
    });
  });

  group('networkOf', () {
    test('IPv4: the /24, unchanged from before', () {
      final n = networkOf('203.0.113.9')!;
      expect(n.prefix, '203.0.113.0/24');
      expect(n.address, '203.0.113.0');
    });

    test('IPv6: the /48, whatever the address was abbreviated to', () {
      for (final ip in [
        '2601:647:4d00:1234::1',
        '2601:0647:4d00:1234:0:0:0:1',
        '2601:647:4D00::',
      ]) {
        expect(networkOf(ip)!.prefix, '2601:647:4d00::/48', reason: ip);
      }
      // The old text-splitting read '2601:647::1' as '2601:647:::/48'.
      expect(networkOf('2601:647::1')!.prefix, '2601:647::/48');
      expect(networkOf('2601:647::1')!.address, '2601:647::');
    });

    test('an IPv4-mapped IPv6 address is an IPv4 caller', () {
      expect(networkOf('::ffff:203.0.113.9')!.prefix, '203.0.113.0/24');
    });

    test('not an address', () {
      expect(networkOf('unknown'), isNull);
      expect(networkOf(''), isNull);
    });
  });
}
