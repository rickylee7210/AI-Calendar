import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calendar/services/connectivity_service.dart';

void main() {
  group('MockConnectivityService', () {
    test('returns true when connected', () async {
      final svc = MockConnectivityService(connected: true);
      expect(await svc.isConnected, true);
    });

    test('returns false when disconnected', () async {
      final svc = MockConnectivityService(connected: false);
      expect(await svc.isConnected, false);
    });
  });
}
