import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/push/data/device_repository.dart';
import 'package:bjj_open_mat/core/api/endpoints.dart';

// ---------------------------------------------------------------------------
// Capturing adapter — records the outbound RequestOptions
// ---------------------------------------------------------------------------
class _CapturingAdapter implements HttpClientAdapter {
  final void Function(RequestOptions) onFetch;

  _CapturingAdapter(this.onFetch);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch(options);
    return ResponseBody.fromString('', 204, headers: {});
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  test('registerDevice POSTs token + platform to /api/v1/devices', () async {
    late RequestOptions captured;
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = _CapturingAdapter((opts) => captured = opts);
    final repo = ApiDeviceRepository(dio);

    await repo.registerDevice('abc', 'ios');

    expect(captured.path, Endpoints.devices);
    expect(captured.method, 'POST');
    final data = captured.data as Map<String, dynamic>;
    expect(data['token'], 'abc');
    expect(data['platform'], 'ios');
  });

  test('unregisterDevice DELETEs to /api/v1/devices/:token', () async {
    late RequestOptions captured;
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = _CapturingAdapter((opts) => captured = opts);
    final repo = ApiDeviceRepository(dio);

    await repo.unregisterDevice('tok123');

    expect(captured.path, Endpoints.deviceByToken('tok123'));
    expect(captured.method, 'DELETE');
  });
}
