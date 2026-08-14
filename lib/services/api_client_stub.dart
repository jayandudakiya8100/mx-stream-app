import 'package:http/http.dart' as http;

/// Web (and any non-`dart:io`) platform: the browser owns the connection pool,
/// so the default client is all we can tune.
http.Client createSharedClient() => http.Client();
