import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print('Testing stream resolution for Pushpa 2: The Rule...');
  
  // Step 1: Search movie
  final searchUrl = 'https://vegamovies.ms/search.php?q=Pushpa+2';
  final res = await http.get(Uri.parse(searchUrl), headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });
  print('Search status: ${res.statusCode}');
  print('Search body preview: ${res.body.substring(0, res.body.length.clamp(0, 300))}');
}
