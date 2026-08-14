import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// A keep-alive client for platforms with `dart:io`, so TCP connections and TLS
/// sessions are reused across the app instead of being torn down per request.
http.Client createSharedClient() {
  final httpClient = HttpClient()
    ..maxConnectionsPerHost = 8
    ..idleTimeout = const Duration(seconds: 30)
    ..connectionTimeout = const Duration(seconds: 10);
  return IOClient(httpClient);
}
