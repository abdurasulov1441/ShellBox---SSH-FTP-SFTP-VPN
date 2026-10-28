import 'package:flutter_test/flutter_test.dart';
import 'package:shellbox/services/pin_hasher.dart';

void main() {
  // Low iteration count keeps the suite fast; the format is identical.
  const iterations = 1000;

  group('PinHasher', () {
    test('hash never contains the PIN in plaintext', () async {
      final stored = await PinHasher.hash('4821', iterations: iterations);

      expect(stored, startsWith(r'pbkdf2$1000$'));
      expect(stored, isNot(contains('4821')));
      expect(PinHasher.isHashed(stored), isTrue);
    });

    test('verify accepts the right PIN and rejects a wrong one', () async {
      final stored = await PinHasher.hash('4821', iterations: iterations);

      expect(await PinHasher.verify('4821', stored), isTrue);
      expect(await PinHasher.verify('4822', stored), isFalse);
    });

    test('same PIN gets a different hash each time thanks to the salt', () async {
      final a = await PinHasher.hash('0000', iterations: iterations);
      final b = await PinHasher.hash('0000', iterations: iterations);

      expect(a, isNot(b));
    });

    test('legacy plaintext PIN from older builds still verifies', () async {
      expect(PinHasher.isHashed('1234'), isFalse);
      expect(await PinHasher.verify('1234', '1234'), isTrue);
      expect(await PinHasher.verify('1235', '1234'), isFalse);
    });

    test('malformed stored value is rejected instead of throwing', () async {
      expect(await PinHasher.verify('1234', r'pbkdf2$abc$$'), isFalse);
      expect(await PinHasher.verify('1234', r'pbkdf2$1000$!!!$!!!'), isFalse);
      expect(await PinHasher.verify('1234', r'pbkdf2$1000'), isFalse);
    });
  });

  group('PinThrottle', () {
    test('first attempts are free', () {
      for (var i = 0; i < PinThrottle.freeAttempts; i++) {
        expect(PinThrottle.delayAfter(i), Duration.zero);
      }
    });

    test('delay starts at 30 s and doubles', () {
      expect(PinThrottle.delayAfter(5), const Duration(seconds: 30));
      expect(PinThrottle.delayAfter(6), const Duration(seconds: 60));
      expect(PinThrottle.delayAfter(7), const Duration(seconds: 120));
    });

    test('delay is capped at one hour', () {
      expect(PinThrottle.delayAfter(50), PinThrottle.maxDelay);
      expect(PinThrottle.delayAfter(1000), PinThrottle.maxDelay);
    });
  });
}
