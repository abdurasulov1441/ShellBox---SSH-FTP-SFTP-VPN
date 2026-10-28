import 'package:flutter_test/flutter_test.dart';
import 'package:shellbox/services/ftp_client.dart';
import 'package:shellbox/services/remote_fs.dart';
import 'package:shellbox/services/wake_on_lan.dart';

void main() {
  group('safeLocalName', () {
    test('strips directory traversal from server-supplied names', () {
      expect(safeLocalName('../../etc/passwd'), 'passwd');
      expect(safeLocalName(r'..\..\evil.bat'), 'evil.bat');
      expect(safeLocalName('dir/file.txt'), 'file.txt');
    });

    test('never returns an empty or dot-only name', () {
      expect(safeLocalName('..'), 'download');
      expect(safeLocalName('.'), 'download');
      expect(safeLocalName('   '), 'download');
      expect(safeLocalName('a/'), 'download');
    });

    test('replaces characters that are invalid in local file names', () {
      expect(safeLocalName('report:v1?.txt'), 'report_v1_.txt');
      expect(safeLocalName('line\nbreak'), 'line_break');
    });

    test('keeps ordinary names untouched', () {
      expect(safeLocalName('backup 2026.tar.gz'), 'backup 2026.tar.gz');
      expect(safeLocalName('.bashrc'), '.bashrc');
      expect(safeLocalName('отчёт.pdf'), 'отчёт.pdf');
    });
  });

  group('isSafeFtpArgument', () {
    test('rejects CR and LF that would inject a second FTP command', () {
      expect(isSafeFtpArgument('user\r\nDELE /important'), isFalse);
      expect(isSafeFtpArgument('pass\nword'), isFalse);
      expect(isSafeFtpArgument('pass\rword'), isFalse);
    });

    test('accepts normal values', () {
      expect(isSafeFtpArgument('RETR /home/user/file name.txt'), isTrue);
    });
  });

  group('certificateFingerprint', () {
    test('uses the OpenSSH SHA256:<base64> format without padding', () {
      final fingerprint = certificateFingerprint([1, 2, 3]);

      expect(fingerprint, startsWith('SHA256:'));
      expect(fingerprint, isNot(endsWith('=')));
      expect(fingerprint, certificateFingerprint([1, 2, 3]));
      expect(fingerprint, isNot(certificateFingerprint([1, 2, 4])));
    });
  });

  group('WakeOnLan.parseMac', () {
    test('accepts colon, dash and plain notation', () {
      const expected = [0xAA, 0xBB, 0xCC, 0x00, 0x11, 0x22];

      expect(WakeOnLan.parseMac('aa:bb:cc:00:11:22'), expected);
      expect(WakeOnLan.parseMac('AA-BB-CC-00-11-22'), expected);
      expect(WakeOnLan.parseMac('aabbcc001122'), expected);
    });

    test('rejects wrong length', () {
      expect(WakeOnLan.parseMac('aa:bb:cc:00:11'), isNull);
      expect(WakeOnLan.parseMac(''), isNull);
    });
  });
}
