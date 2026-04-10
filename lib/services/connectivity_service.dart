abstract class IConnectivityService {
  Future<bool> get isConnected;
}

class MockConnectivityService implements IConnectivityService {
  final bool connected;
  MockConnectivityService({this.connected = true});

  @override
  Future<bool> get isConnected async => connected;
}

// TODO: Implement RealConnectivityService using connectivity_plus
