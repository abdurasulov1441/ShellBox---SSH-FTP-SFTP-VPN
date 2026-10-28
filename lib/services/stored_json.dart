import 'dart:convert';

/// Result of decoding a persisted JSON collection.
///
/// [corrupt] is true when the raw value could not be fully read; the caller
/// must back the raw value up before anything overwrites it.
class DecodedList<T> {
  const DecodedList(this.items, {this.corrupt = false});

  final List<T> items;
  final bool corrupt;
}

DecodedList<Map<String, dynamic>> decodeJsonList(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const DecodedList([]);
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const DecodedList([], corrupt: true);
  }
  if (decoded is! List) {
    return const DecodedList([], corrupt: true);
  }
  final maps = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  return DecodedList(maps, corrupt: maps.length != decoded.length);
}

DecodedList<MapEntry<String, String>> decodeJsonMap(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const DecodedList([]);
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const DecodedList([], corrupt: true);
  }
  if (decoded is! Map) {
    return const DecodedList([], corrupt: true);
  }
  return DecodedList([for (final e in decoded.entries) MapEntry(e.key.toString(), e.value.toString())]);
}

/// Parses each item separately so one malformed entry does not drop the rest.
DecodedList<T> parseItems<T>(
  DecodedList<Map<String, dynamic>> source,
  T Function(Map<String, dynamic>) parse,
  bool Function(T) valid,
) {
  final items = <T>[];
  var corrupt = source.corrupt;
  for (final json in source.items) {
    try {
      final item = parse(json);
      if (valid(item)) {
        items.add(item);
      } else {
        corrupt = true;
      }
    } on TypeError {
      corrupt = true;
    } on FormatException {
      corrupt = true;
    }
  }
  return DecodedList(items, corrupt: corrupt);
}
