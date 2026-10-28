import 'package:flutter_test/flutter_test.dart';
import 'package:shellbox/models.dart';
import 'package:shellbox/services/stored_json.dart';

void main() {
  group('decodeJsonList', () {
    test('missing value is empty and not corrupt', () {
      expect(decodeJsonList(null).corrupt, isFalse);
      expect(decodeJsonList('').items, isEmpty);
    });

    test('broken JSON is flagged corrupt so the caller backs it up', () {
      final result = decodeJsonList('[{"id": "a"');

      expect(result.corrupt, isTrue);
      expect(result.items, isEmpty);
    });

    test('a JSON object where a list is expected is corrupt', () {
      expect(decodeJsonList('{"id": "a"}').corrupt, isTrue);
    });

    test('non-object entries are dropped and flagged', () {
      final result = decodeJsonList('[{"id": "a"}, 42]');

      expect(result.items, hasLength(1));
      expect(result.corrupt, isTrue);
    });

    test('valid list decodes cleanly', () {
      final result = decodeJsonList('[{"id": "a"}, {"id": "b"}]');

      expect(result.items.map((e) => e['id']), ['a', 'b']);
      expect(result.corrupt, isFalse);
    });
  });

  group('decodeJsonMap', () {
    test('valid map decodes to string entries', () {
      final result = decodeJsonMap('{"h:22": "ssh-ed25519 SHA256:abc"}');

      expect(Map.fromEntries(result.items), {'h:22': 'ssh-ed25519 SHA256:abc'});
      expect(result.corrupt, isFalse);
    });

    test('broken JSON is corrupt', () {
      expect(decodeJsonMap('{').corrupt, isTrue);
    });
  });

  group('parseItems', () {
    test('one malformed host does not drop the others', () {
      final raw = decodeJsonList(
        '[{"id": "1", "address": "a", "username": "u"},'
        ' {"id": 7, "address": "b"},'
        ' {"id": "3", "address": "c", "username": "u"}]',
      );

      final result = parseItems(raw, Host.fromJson, (h) => h.id.isNotEmpty);

      expect(result.items.map((h) => h.id), ['1', '3']);
      expect(result.corrupt, isTrue);
    });

    test('clean input stays clean', () {
      final raw = decodeJsonList('[{"id": "1", "address": "a", "username": "u"}]');

      final result = parseItems(raw, Host.fromJson, (h) => h.id.isNotEmpty);

      expect(result.items, hasLength(1));
      expect(result.corrupt, isFalse);
    });

    test('Host survives a toJson/fromJson roundtrip', () {
      const host = Host(id: 'x', address: '10.0.0.1', port: 2222, username: 'root', label: 'Сервер 🚀');

      final copy = Host.fromJson(host.toJson());

      expect(copy.id, host.id);
      expect(copy.port, 2222);
      expect(copy.label, 'Сервер 🚀');
    });
  });
}
