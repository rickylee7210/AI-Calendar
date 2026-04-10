import 'interfaces.dart';

/// Mock ASR service for development. Replace with XfyunAsrService for production.
class MockAsrService implements IAsrService {
  final String? mockText;
  final bool shouldTimeout;
  final Duration delay;

  MockAsrService({
    this.mockText = '明天下午三点开产品评审会',
    this.shouldTimeout = false,
    this.delay = const Duration(milliseconds: 500),
  });

  @override
  Future<String?> recognize(String audioFilePath) async {
    await Future.delayed(delay);
    if (shouldTimeout) throw AsrTimeoutException();
    return mockText;
  }
}

// TODO: Implement XfyunAsrService with real 科大讯飞 API
// class XfyunAsrService implements IAsrService { ... }
