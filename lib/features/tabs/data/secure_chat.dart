import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// End-to-end encrypted chat, byte-compatible with the website (js/chat.js):
/// one ECDH P-256 key pair per device, the AES-256-GCM key is the raw ECDH
/// shared secret (WebCrypto deriveKey), 12-byte IVs, and the envelope
/// `{"v":1,"iv","ct","s","r"}` with standard base64. Key rings are JWK JSON in
/// the same shape the website stores, so a password backup made on either one
/// restores on the other. Private keys never leave the device unencrypted.

final _curve = ECCurve_secp256r1();
final _rand = Random.secure();

Uint8List _randomBytes(int n) => Uint8List.fromList(List<int>.generate(n, (_) => _rand.nextInt(256)));

String _b64u(Uint8List b) => base64Url.encode(b).replaceAll('=', '');
Uint8List _unb64u(String s) => base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

Uint8List _bytes32(BigInt v) {
  final out = Uint8List(32);
  var x = v;
  for (var i = 31; i >= 0; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x = x >> 8;
  }
  return out;
}

BigInt _int(Uint8List b) => b.fold(BigInt.zero, (a, e) => (a << 8) | BigInt.from(e));

/// A JWK key pair as the website keeps it: `{priv: {...d}, pub: {kty, crv, x, y}}`.
typedef JwkPair = Map<String, dynamic>;

@visibleForTesting
JwkPair generateKeyPair() {
  final n = _curve.n;
  BigInt d;
  do {
    d = _int(_randomBytes(32));
  } while (d == BigInt.zero || d >= n);
  final q = (_curve.G * d)!;
  final x = _b64u(_bytes32(q.x!.toBigInteger()!)), y = _b64u(_bytes32(q.y!.toBigInteger()!));
  return {
    // key_ops/ext as WebCrypto exports them, so the website can import this key
    'priv': {'kty': 'EC', 'crv': 'P-256', 'x': x, 'y': y, 'd': _b64u(_bytes32(d)), 'ext': true, 'key_ops': ['deriveKey']},
    'pub': {'kty': 'EC', 'crv': 'P-256', 'x': x, 'y': y},
  };
}

ECPoint _point(Map pub) {
  final x = _int(_unb64u('${pub['x']}')), y = _int(_unb64u('${pub['y']}'));
  // reject points that are not on P-256 (invalid-curve attacks)
  final prime = BigInt.parse('ffffffff00000001000000000000000000000000ffffffffffffffffffffffff', radix: 16);
  final a = _curve.curve.a!.toBigInteger()!, b = _curve.curve.b!.toBigInteger()!;
  if (x >= prime || y >= prime || (y * y - (x * x * x + a * x + b)) % prime != BigInt.zero) {
    throw const FormatException('bad key');
  }
  return _curve.curve.createPoint(x, y);
}

/// WebCrypto ECDH deriveKey(AES-GCM 256): the x-coordinate of d·Q.
@visibleForTesting
Uint8List sharedSecret(Map priv, Map peerPub) {
  final d = _int(_unb64u('${priv['d']}'));
  final s = (_point(peerPub) * d)!;
  return _bytes32(s.x!.toBigInteger()!);
}

Uint8List _gcm(bool encrypt, Uint8List key, Uint8List iv, Uint8List data) {
  final c = GCMBlockCipher(AESEngine())..init(encrypt, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  return c.process(data);
}

@visibleForTesting
String sealFor(Map myPriv, String myKid, Map peerPub, String peerKid, Map<String, dynamic> payload) {
  final iv = _randomBytes(12);
  final ct = _gcm(true, sharedSecret(myPriv, peerPub), iv, Uint8List.fromList(utf8.encode(jsonEncode(payload))));
  return jsonEncode({'v': 1, 'iv': base64Encode(iv), 'ct': base64Encode(ct), 's': myKid, 'r': peerKid});
}

@visibleForTesting
Map<String, dynamic> openWith(Map myPriv, Map peerPub, Map env) {
  final plain = _gcm(false, sharedSecret(myPriv, peerPub), base64Decode('${env['iv']}'), base64Decode('${env['ct']}'));
  return Map<String, dynamic>.from(jsonDecode(utf8.decode(plain)) as Map);
}

Uint8List _passKey(String pass, Uint8List salt) {
  final k = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))..init(Pbkdf2Parameters(salt, 250000, 32));
  return k.process(Uint8List.fromList(utf8.encode(pass)));
}

/// Password-wraps a key ring exactly like the website's wrapRing.
@visibleForTesting
Map<String, String> wrapRing(String pass, Map ring) {
  final salt = _randomBytes(16), iv = _randomBytes(12);
  final ct = _gcm(true, _passKey(pass, salt), iv, Uint8List.fromList(utf8.encode(jsonEncode(ring))));
  return {'salt': base64Encode(salt), 'iv': base64Encode(iv), 'ct': base64Encode(ct)};
}

@visibleForTesting
Map<String, dynamic> unwrapRing(String pass, Map w) {
  final plain = _gcm(false, _passKey(pass, base64Decode('${w['salt']}')), base64Decode('${w['iv']}'), base64Decode('${w['ct']}'));
  return Map<String, dynamic>.from(jsonDecode(utf8.decode(plain)) as Map);
}

// PBKDF2 at 250k rounds takes a few seconds in Dart; keep the UI responsive on phones.
Future<Map<String, String>> _wrapAsync(String pass, Map ring) => kIsWeb ? Future.value(wrapRing(pass, ring)) : compute((a) => wrapRing(a.$1, a.$2), (pass, ring));
Future<Map<String, dynamic>> _unwrapAsync(String pass, Map w) => kIsWeb ? Future(() => unwrapRing(pass, w)) : compute((a) => unwrapRing(a.$1, a.$2), (pass, w));

/// What a message decrypts to: the website's payload `{t, x, a?}` or locked.
class ChatPayload {
  const ChatPayload(this.type, this.text, {this.attachment, this.locked = false});
  final String type, text;
  final Map<String, dynamic>? attachment;
  final bool locked;
}

/// The device's secure-chat keys for the signed-in member.
class SecureChat {
  SecureChat._();
  static final instance = SecureChat._();

  static const _store = FlutterSecureStorage();
  Map<String, dynamic>? _ring;
  String? _ringUser;
  Future<Map<String, dynamic>>? _ready;
  final _peerKeys = <String, List<Map<String, dynamic>>>{};
  bool skipRestore = false; // "Start fresh" for this session (website baidx_skip_restore)

  SupabaseClient get _sb => Supabase.instance.client;
  String get _uid => _sb.auth.currentUser?.id ?? (throw StateError('not signed in'));

  /// Loads or creates this device's key ring and publishes its public key.
  /// [askRestore] is shown when the account has a password backup and this
  /// device has no key yet; it returns the password, or null to start fresh.
  Future<Map<String, dynamic>> ensureKeys({Future<String?> Function(Future<bool> Function(String pass) tryPass)? askRestore}) {
    final uid = _uid;
    if (_ring != null && _ringUser == uid) return Future.value(_ring);
    if (_ready != null && _ringUser == uid) return _ready!;
    _ringUser = uid;
    _peerKeys.clear();
    return _ready = () async {
      try {
        final raw = await _store.read(key: 'baidx_chat_ring_$uid');
        Map<String, dynamic>? ring = raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (ring?['current'] == null && !skipRestore && askRestore != null) {
          final bk = await _sb.from('key_backups').select('wrapped').eq('user_id', uid).maybeSingle();
          final wrapped = bk?['wrapped'];
          if (wrapped is Map) {
            Map<String, dynamic>? restored;
            await askRestore((pass) async {
              try {
                restored = await _unwrapAsync(pass, wrapped);
                return true;
              } catch (_) {
                return false;
              }
            });
            if (restored != null) {
              ring = restored;
            } else {
              skipRestore = true;
            }
          }
        }
        if (ring?['current'] == null) {
          final k = generateKeyPair();
          final id = _b64u(_randomBytes(9));
          ring = {'current': id, 'keys': {id: k}};
        }
        await _store.write(key: 'baidx_chat_ring_$uid', value: jsonEncode(ring));
        final cur = Map<String, dynamic>.from((ring!['keys'] as Map)[ring['current']] as Map);
        final mine = await peerKeys(uid, force: true);
        if (!mine.any((k) => k['id'] == ring!['current'] && k['current'] == true)) {
          await _sb.rpc('publish_key', params: {'p_key_id': ring['current'], 'p_public': cur['pub']});
        }
        _ring = ring;
        return ring;
      } catch (e) {
        _ready = null;
        rethrow;
      }
    }();
  }

  bool get hasKeys => _ring != null && _ringUser == _sb.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> peerKeys(String userId, {bool force = false}) async {
    if (!force && _peerKeys.containsKey(userId)) return _peerKeys[userId]!;
    final r = await _sb.rpc('peer_keys', params: {'p_user': userId});
    final list = [for (final k in (r is List ? r : const [])) if (k is Map) Map<String, dynamic>.from(k)];
    return _peerKeys[userId] = list;
  }

  /// Whether the other person has a secure-chat key (else text goes plain).
  Future<bool> peerHasKey(String peerId) async => (await peerKeys(peerId, force: true)).isNotEmpty;

  /// The envelope for [payload], or null when the peer has no key yet.
  Future<String?> encryptFor(String peerId, Map<String, dynamic> payload) async {
    final ring = await ensureKeys();
    final list = await peerKeys(peerId, force: true);
    if (list.isEmpty) return null;
    final pk = list.firstWhere((k) => k['current'] == true, orElse: () => list.first);
    final myKid = '${ring['current']}';
    final priv = Map<String, dynamic>.from(((ring['keys'] as Map)[myKid] as Map)['priv'] as Map);
    return sealFor(priv, myKid, Map<String, dynamic>.from(pk['jwk'] as Map), '${pk['id']}', payload);
  }

  /// Decrypts a chat_thread message the way the website's decryptMsg does.
  Future<ChatPayload> decrypt(Map m, String peerId) async {
    final type = '${m['type'] ?? 'text'}';
    if ((num.tryParse('${m['v'] ?? 0}') ?? 0) == 0) {
      if (type != 'text' && type != 'system') {
        try {
          final o = jsonDecode('${m['body']}');
          if (o is Map && o['a'] is Map) return ChatPayload('${o['t'] ?? type}', '${o['x'] ?? ''}', attachment: Map<String, dynamic>.from(o['a'] as Map));
        } catch (_) {
          // a plain legacy body
        }
      }
      return ChatPayload(type, '${m['body'] ?? ''}');
    }
    try {
      final ring = await ensureKeys();
      final o = jsonDecode('${m['body']}') as Map;
      final mine = m['mine'] == true;
      final myKid = '${mine ? o['s'] : o['r']}', peerKid = '${mine ? o['r'] : o['s']}';
      final keys = ring['keys'] as Map;
      if (keys[myKid] == null) return const ChatPayload('locked', '', locked: true);
      var list = await peerKeys(peerId);
      var pk = list.where((k) => k['id'] == peerKid).firstOrNull;
      if (pk == null) {
        list = await peerKeys(peerId, force: true);
        pk = list.where((k) => k['id'] == peerKid).firstOrNull;
      }
      if (pk == null) return const ChatPayload('locked', '', locked: true);
      final p = openWith(Map<String, dynamic>.from((keys[myKid] as Map)['priv'] as Map), Map<String, dynamic>.from(pk['jwk'] as Map), o);
      return ChatPayload('${p['t'] ?? 'text'}', '${p['x'] ?? ''}', attachment: p['a'] is Map ? Map<String, dynamic>.from(p['a'] as Map) : null);
    } catch (_) {
      return const ChatPayload('locked', '', locked: true);
    }
  }

  /// Decrypts an attachment's bytes (website decryptBytes).
  static Uint8List decryptBytes(Uint8List data, String keyB64, String ivB64) => _gcm(false, base64Decode(keyB64), base64Decode(ivB64), data);

  /// Saves a password-encrypted copy of this device's key ring.
  Future<void> backup(String pass) async {
    final ring = await ensureKeys();
    final w = await _wrapAsync(pass, ring);
    await _sb.from('key_backups').upsert({'user_id': _uid, 'wrapped': w, 'updated_at': DateTime.now().toUtc().toIso8601String()});
    await _store.write(key: 'baidx_chat_bk_$_uid', value: '1');
  }

  Future<bool> hasBackupFlag() async => (await _store.read(key: 'baidx_chat_bk_$_uid')) != null;
}
