import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/tabs/data/secure_chat.dart';

/// Messages and backups must cross between the app and the website.
/// With E2E_DIR set, this also runs against real WebCrypto (Node) fixtures.
void main() {
  test('two devices derive the same key and read each other', () {
    final a = generateKeyPair(), b = generateKeyPair();
    expect(sharedSecret(a['priv'] as Map, b['pub'] as Map), sharedSecret(b['priv'] as Map, a['pub'] as Map));
    final env = sealFor(a['priv'] as Map, 'ka', b['pub'] as Map, 'kb', {'t': 'text', 'x': 'Hello Kwame'});
    final o = jsonDecode(env) as Map;
    expect(o['v'], 1);
    expect(o['s'], 'ka');
    expect(o['r'], 'kb');
    expect(openWith(b['priv'] as Map, a['pub'] as Map, o)['x'], 'Hello Kwame');
  });

  test('a tampered message does not open', () {
    final a = generateKeyPair(), b = generateKeyPair();
    final o = jsonDecode(sealFor(a['priv'] as Map, 'ka', b['pub'] as Map, 'kb', {'t': 'text', 'x': 'pay 100'})) as Map;
    final ct = base64Decode('${o['ct']}')..[0] ^= 1;
    expect(() => openWith(b['priv'] as Map, a['pub'] as Map, {...o, 'ct': base64Encode(ct)}), throwsA(anything));
  });

  test('a key that is not on the curve is refused', () {
    final a = generateKeyPair();
    final bad = {'kty': 'EC', 'crv': 'P-256', 'x': (a['pub'] as Map)['x'], 'y': (a['pub'] as Map)['x']};
    expect(() => sharedSecret(a['priv'] as Map, bad), throwsFormatException);
  });

  test('a password backup restores, a wrong password fails', () {
    final k = generateKeyPair();
    final ring = {'current': 'k1', 'keys': {'k1': k}};
    final w = wrapRing('long passphrase', ring);
    expect(unwrapRing('long passphrase', w)['current'], 'k1');
    expect(() => unwrapRing('wrong', w), throwsA(anything));
  }, timeout: const Timeout(Duration(minutes: 2)));

  final dir = Platform.environment['E2E_DIR'];
  test('interoperates with the website (WebCrypto)', () {
    if (dir == null) return;
    final step = Platform.environment['E2E_STEP'];
    if (step == 'keys') {
      final k = generateKeyPair();
      File('$dir/dart_keys.json').writeAsStringSync(jsonEncode(k));
    } else if (step == 'read') {
      final mine = jsonDecode(File('$dir/dart_keys.json').readAsStringSync()) as Map;
      final web = jsonDecode(File('$dir/web_out.json').readAsStringSync()) as Map;
      final msg = openWith(mine['priv'] as Map, web['pub'] as Map, jsonDecode('${web['env']}') as Map);
      expect(msg['x'], 'Akwaaba from the website ✓');
      expect(unwrapRing('correct horse', web['wrapped'] as Map)['current'], 'webkid');
      // now answer the website and back up a Dart ring for it to restore
      final webKeys = generateKeyPair();
      File('$dir/web_keys.json').writeAsStringSync(jsonEncode(webKeys));
      final env = sealFor(mine['priv'] as Map, 'dartkid', webKeys['pub'] as Map, 'webkid', {'t': 'text', 'x': 'Medaase from the app'});
      File('$dir/dart_out.json').writeAsStringSync(jsonEncode({'pub': mine['pub'], 'env': env, 'wrapped': wrapRing('battery staple', {'current': 'dartkid', 'keys': {'dartkid': mine}})}));
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
