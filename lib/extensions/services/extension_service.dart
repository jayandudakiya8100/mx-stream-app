import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/extension_models.dart';

class ExtensionService {
  static Future<CSManifest?> fetchManifest(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CSManifest.fromJson(data);
      }
    } catch (e) {
      print('Error fetching manifest: $e');
    }
    return null;
  }

  static Future<List<CSPlugin>> fetchPlugins(String pluginListUrl) async {
    try {
      final response = await http.get(Uri.parse(pluginListUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => CSPlugin.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching plugins: $e');
    }
    return [];
  }
}
