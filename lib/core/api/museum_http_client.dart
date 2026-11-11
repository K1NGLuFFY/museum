import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/artworks/artwork.dart';

abstract interface class MuseumApiClient {
  Future<Map<String, dynamic>> get(Uri uri, {CancellationToken? cancellation});
  void close();
}

class MuseumHttpClient implements MuseumApiClient {
  MuseumHttpClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
    this.retryDelay = const Duration(milliseconds: 500),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout, retryDelay;

  @override
  Future<Map<String, dynamic>> get(
    Uri uri, {
    CancellationToken? cancellation,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      cancellation?.check();
      final abort = Completer<void>();
      void cancel() {
        if (!abort.isCompleted) abort.complete();
      }

      cancellation?.addListener(cancel);
      try {
        final request = http.AbortableRequest(
          'GET',
          uri,
          abortTrigger: abort.future,
        )..headers['Accept'] = 'application/json';
        final response = await _client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(
              timeout,
              onTimeout: () {
                cancel();
                throw TimeoutException('Museum request timed out');
              },
            );
        cancellation?.check();
        if (response.statusCode != 200) {
          final transient =
              response.statusCode == 429 || response.statusCode >= 500;
          if (transient && attempt < 2) {
            final seconds = int.tryParse(response.headers['retry-after'] ?? '');
            await Future<void>.delayed(
              seconds == null
                  ? retryDelay * (1 << attempt)
                  : Duration(seconds: seconds.clamp(0, 5)),
            );
            continue;
          }
          throw MuseumException(
            response.statusCode == 429
                ? 'The museum is busy. Please try again shortly.'
                : 'The museum could not return this request. Please try again.',
            statusCode: response.statusCode,
          );
        }
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json is! Map<String, dynamic>) throw const FormatException();
        return json;
      } on http.RequestAbortedException {
        throw const RequestCancelled();
      } on FormatException {
        throw const MuseumException(
          'The museum returned an unreadable response.',
        );
      } on TimeoutException {
        if (attempt == 2) {
          throw const MuseumException(
            'The museum took too long to respond. Please try again.',
          );
        }
      } on http.ClientException {
        if (attempt == 2) {
          throw const MuseumException(
            'Unable to reach the museum. Check your connection and try again.',
          );
        }
      } finally {
        cancellation?.removeListener(cancel);
      }
      await Future<void>.delayed(retryDelay * (1 << attempt));
    }
    throw const MuseumException('Unable to reach the museum.');
  }

  @override
  void close() => _client.close();
}
