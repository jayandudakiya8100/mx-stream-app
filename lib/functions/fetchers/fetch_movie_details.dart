import 'package:mxstream/functions/get_base_url.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mxstream/services/api_client.dart';
import 'dart:convert';

final apiKey = dotenv.env['TMDB_API_KEY'];

Future<Map<String, dynamic>> fetchMovieDetails(
  int movieId,
  String region, {
  String? sessionId,
  List<String> appendToResponse = const [],
}) async {
  try {
    final baseUrl = getBaseUrl(region);
    final queryParameters = <String, String>{
      'api_key': apiKey ?? '',
      if (appendToResponse.isNotEmpty)
        'append_to_response': appendToResponse.join(','),
      if (sessionId != null) 'session_id': sessionId,
    };
    final response = await apiClient.get(
      Uri.parse('${baseUrl}movie/$movieId').replace(
        queryParameters: queryParameters,
      ),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load movie details');
    }
  } catch (e) {
    throw Exception('Failed to load movie details');
  }
}
