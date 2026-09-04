import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/core/utils/url_security.dart';

void main() {
  group('UrlSecurity.isSafeWebUrl', () {
    test('Accepts valid HTTPS URLs', () {
      expect(UrlSecurity.isSafeWebUrl('https://tabletop.com.br/eventos'), isTrue);
      expect(UrlSecurity.isSafeWebUrl('https://notion.so/my-page'), isTrue);
      expect(UrlSecurity.isSafeWebUrl('https://sub.domain.org/path?q=1&b=2#frag'), isTrue);
    });

    test('Accepts valid HTTP URLs', () {
      expect(UrlSecurity.isSafeWebUrl('http://example.com'), isTrue);
    });

    test('Rejects dangerous and malicious schemes', () {
      expect(UrlSecurity.isSafeWebUrl('javascript:alert(1)'), isFalse);
      expect(UrlSecurity.isSafeWebUrl('file:///etc/passwd'), isFalse);
      expect(UrlSecurity.isSafeWebUrl('data:text/html,<script>alert(1)</script>'), isFalse);
      expect(UrlSecurity.isSafeWebUrl('intent://scan/#Intent;scheme=zxing;package=com.google.zxing.client.android;end'), isFalse);
      expect(UrlSecurity.isSafeWebUrl('tel:123456789'), isFalse);
      expect(UrlSecurity.isSafeWebUrl('sms:123456789'), isFalse);
    });

    test('Rejects invalid, empty or null inputs', () {
      expect(UrlSecurity.isSafeWebUrl(null), isFalse);
      expect(UrlSecurity.isSafeWebUrl(''), isFalse);
      expect(UrlSecurity.isSafeWebUrl('   '), isFalse);
      expect(UrlSecurity.isSafeWebUrl('not a url at all'), isFalse);
      expect(UrlSecurity.isSafeWebUrl('https://'), isFalse);
    });
  });
}
