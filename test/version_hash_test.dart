import 'package:echo_bay/core/version/version_checker.dart';
import 'package:flutter_test/flutter_test.dart';

/// The body Flutter writes when the build passes `--build-number`.
String _versionJson(String buildNumber) =>
    '{"app_name":"echo_bay","version":"0.1.0","build_number":"$buildNumber",'
    '"package_name":"echo_bay"}';

void main() {
  group('versionHashOf', () {
    test('the build number is part of the fingerprint', () {
      expect(versionHashOf(_versionJson('1760000000')), '0.1.0+1760000000');
    });

    test('a redeploy produces a different fingerprint', () {
      expect(
        versionHashOf(_versionJson('1760000001')),
        isNot(versionHashOf(_versionJson('1760000000'))),
      );
    });

    test('a build that skipped --build-number still reads', () {
      expect(
        versionHashOf('{"version":"0.1.0","package_name":"echo_bay"}'),
        '0.1.0',
      );
    });

    test('unparseable or empty bodies give no fingerprint', () {
      expect(versionHashOf('not json'), isNull);
      expect(versionHashOf('[]'), isNull);
      expect(versionHashOf('{}'), isNull);
    });
  });
}
