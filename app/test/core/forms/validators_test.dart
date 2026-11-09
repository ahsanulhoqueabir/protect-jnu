import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/core/forms/validators.dart';

void main() {
  test('required rejects null, empty and whitespace', () {
    final rule = Validators.required();
    expect(rule(null), isNotNull);
    expect(rule('   '), isNotNull);
    expect(rule('a'), isNull);
  });

  test('optional rules accept empty values', () {
    for (final rule in [
      Validators.email(),
      Validators.phone(),
      Validators.url(),
      Validators.numeric(),
      Validators.password(),
    ]) {
      expect(rule(''), isNull);
    }
  });

  test('email', () {
    final rule = Validators.email();
    expect(rule('a.b+c@mail.example.com'), isNull);
    for (final bad in ['a', 'a@', '@b.com', 'a@b', 'a b@c.com']) {
      expect(rule(bad), isNotNull, reason: bad);
    }
  });

  test('password names the first unmet requirement', () {
    final rule = Validators.password();
    expect(rule('Ab1'), contains('8'));
    expect(rule('abcdefg1'), contains('uppercase'));
    expect(rule('ABCDEFG1'), contains('lowercase'));
    expect(rule('Abcdefgh'), contains('number'));
    expect(rule('Abcdefg1'), isNull);
  });

  test('phone needs enough digits', () {
    final rule = Validators.phone();
    expect(rule('+1 (555) 000-1234'), isNull);
    expect(rule('-- -- -- --'), isNotNull);
  });

  test('name accepts international names', () {
    final rule = Validators.name();
    expect(rule("Renée O'Brien-Núñez"), isNull);
    expect(rule('রহিম'), isNull);
    expect(rule('Bob123'), isNotNull);
  });

  test('url requires http(s) and a host', () {
    final rule = Validators.url();
    expect(rule('https://example.com'), isNull);
    expect(rule('ftp://example.com'), isNotNull);
    expect(rule('example'), isNotNull);
  });

  test('range and match', () {
    expect(Validators.range(1, 5)('6'), isNotNull);
    expect(Validators.range(1, 5)('3'), isNull);
    expect(Validators.match(() => 'a')('b'), isNotNull);
    expect(Validators.match(() => 'a')('a'), isNull);
  });

  test('compose returns the first error', () {
    final rule = Validators.compose([Validators.required('first'), Validators.email('second')]);
    expect(rule(''), 'first');
    expect(rule('x'), 'second');
    expect(rule('x@y.co'), isNull);
  });

  test('password strength grows with complexity', () {
    expect(PasswordStrength.of(''), PasswordStrength.empty);
    expect(PasswordStrength.of('abc'), PasswordStrength.weak);
    expect(PasswordStrength.of('Abcdefg1!xyzq'), PasswordStrength.strong);
  });

  group('server-mirroring rules', () {
    test('university email accepts jnu.ac.bd and subdomains only', () {
      final rule = Validators.universityEmail();
      for (final ok in ['a@jnu.ac.bd', 'b210305040@cse.jnu.ac.bd', 'A@CSE.JNU.AC.BD']) {
        expect(rule(ok), isNull, reason: ok);
      }
      for (final bad in [
        'a@gmail.com',
        'a@xjnu.ac.bd',
        'a@jnu.ac.bd.evil.com',
        'a@.jnu.ac.bd',
        'a@b@jnu.ac.bd',
      ]) {
        expect(rule(bad), isNotNull, reason: bad);
      }
    });

    test('student ID is B plus 9 digits', () {
      final rule = Validators.studentId();
      expect(rule('B210305040'), isNull);
      expect(rule('b210305040'), isNull);
      expect(rule('B21030504'), isNotNull);
      expect(rule('A210305040'), isNotNull);
    });

    test('phone matches the DB check', () {
      final rule = Validators.bdPhone();
      for (final ok in ['01712345678', '+8801712345678', '1712345678']) {
        expect(rule(ok), isNull, reason: ok);
      }
      for (final bad in ['12345', '+8791712345678', '0171234567890123', '017 1234 5678']) {
        expect(rule(bad), isNotNull, reason: bad);
      }
    });

    test('new password is 8-64 characters with no composition rules', () {
      final rule = Validators.newPassword();
      expect(rule('alllowercase'), isNull);
      expect(rule('short'), isNotNull);
      expect(rule('a' * 65), isNotNull);
    });

    test('otp code is exactly 6 digits', () {
      final rule = Validators.otpCode();
      expect(rule('123456'), isNull);
      expect(rule('12345'), isNotNull);
      expect(rule('12345a'), isNotNull);
    });
  });
}
