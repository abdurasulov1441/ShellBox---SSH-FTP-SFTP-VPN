import 'dart:io';
import 'dart:typed_data';

class WakeOnLan {
  static List<int>? parseMac(String input) {
    final cleaned = input.replaceAll(RegExp('[^0-9a-fA-F]'), '');
    if (cleaned.length != 12) {
      return null;
    }
    final bytes = <int>[];
    for (var i = 0; i < 12; i += 2) {
      bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  static Future<bool> send(String mac, {String broadcast = '255.255.255.255', int port = 9}) async {
    final macBytes = parseMac(mac);
    if (macBytes == null) {
      return false;
    }
    final addr = InternetAddress.tryParse(broadcast);
    if (addr == null) {
      return false;
    }
    final packet = Uint8List(102);
    for (var i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }
    for (var i = 0; i < 16; i++) {
      for (var j = 0; j < 6; j++) {
        packet[6 + i * 6 + j] = macBytes[j];
      }
    }
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      var sent = 0;
      for (var i = 0; i < 3; i++) {
        sent = socket.send(packet, addr, port);
      }
      return sent > 0;
    } catch (_) {
      return false;
    } finally {
      socket?.close();
    }
  }
}
