import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['en', 'ru', 'uz'];

Set<String> _flatKeys(Map<String, dynamic> json, [String prefix = '']) {
  final keys = <String>{};
  json.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      keys.addAll(_flatKeys(value, path));
    } else {
      keys.add(path);
    }
  });
  return keys;
}

Map<String, dynamic> _load(String locale) =>
    jsonDecode(File('assets/translations/$locale.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('all locales have exactly the same keys', () {
    final en = _flatKeys(_load('en'));
    for (final locale in _locales.skip(1)) {
      final other = _flatKeys(_load(locale));

      expect(other.difference(en), isEmpty, reason: '$locale has keys missing in en');
      expect(en.difference(other), isEmpty, reason: '$locale is missing keys');
    }
  });

  test('every literal key used with .tr() exists in en', () {
    final en = _flatKeys(_load('en'));
    final usage = RegExp(r"""'([a-z_]+\.[a-z0-9_.]+)'\.tr\(""");
    final missing = <String>{};
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      for (final match in usage.allMatches(file.readAsStringSync())) {
        final key = match.group(1)!;
        if (!en.contains(key)) {
          missing.add('$key (${file.path})');
        }
      }
    }

    expect(missing, isEmpty);
  });
}
