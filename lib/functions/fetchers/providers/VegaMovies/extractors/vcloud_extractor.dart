import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../../core/models.dart';
import '../../provider_config.dart';

class VCloudExtractor {
  static String getBaseUrl(String url) {
    try {
      final parsed = Uri.parse(url);
      return '${parsed.scheme}://${parsed.host}';
    } catch (_) {
      return url;
    }
  }

  static String? extractDoubleAtob(String html) {
    final regex = RegExp(r'''var\s+url\s*=\s*atob\s*\(\s*atob\s*\(\s*['"]([^'"]+)['"]\s*\)\s*\)''', caseSensitive: false);
    final match = regex.firstMatch(html);
    if (match != null && match.group(1) != null) {
      try {
        final decodedOnce = utf8.decode(base64.decode(match.group(1)!));
        final decodedTwice = utf8.decode(base64.decode(decodedOnce));
        return decodedTwice;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static String? extractPxlUrl(String html) {
    final regex = RegExp(r'''var\s+pxl\s*=\s*["']([^"']+)["']''', caseSensitive: false);
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  static Future<String?> resolveFinalUrl(String startUrl, {int maxRedirects = 7}) async {
    String currentUrl = startUrl;
    int loopCount = 0;
    final client = http.Client();

    while (loopCount < maxRedirects) {
      try {
        final request = http.Request('HEAD', Uri.parse(currentUrl))
          ..followRedirects = false;
        final response = await client.send(request).timeout(const Duration(seconds: 5));
        
        final location = response.headers['location'];
        if (location == null) break;

        currentUrl = location.startsWith('http')
            ? location
            : Uri.parse(currentUrl).resolve(location).toString();
        loopCount++;
      } catch (e) {
        break;
      }
    }
    client.close();
    return currentUrl;
  }

  static Future<List<StreamLink>> extractVCloudStream(String url) async {
    final List<StreamLink> streams = [];

    try {
      String baseUrl = getBaseUrl(url);
      final sourceKey = url.contains('hubcloud') ? 'hubcloud' : 'vcloud';
      
      // Resolve dynamic base domain
      final latestBaseUrl = await ProviderConfig.resolveBaseUrl(sourceKey);
      String newUrl = url;
      if (latestBaseUrl.isNotEmpty && baseUrl != latestBaseUrl) {
        newUrl = url.replaceAll(baseUrl, latestBaseUrl);
        baseUrl = latestBaseUrl;
      }

      // Fetch Step 1 Document
      final res1 = await http.get(
        Uri.parse(newUrl),
        headers: {"User-Agent": ProviderConfig.defaultUserAgent},
      ).timeout(const Duration(seconds: 10));
      final doc1 = parser.parse(res1.body);

      String secondaryLink = '';
      if (newUrl.contains('/video/')) {
        final vdLink = doc1.querySelector('div.vd > center > a');
        secondaryLink = vdLink?.attributes['href'] ?? '';
      } else {
        String scriptTag = '';
        final scripts = doc1.querySelectorAll('script');
        for (var script in scripts) {
          final text = script.innerHtml;
          if (text.contains('url')) {
            scriptTag = text;
            break;
          }
        }

        if (newUrl.contains('vcloud')) {
          secondaryLink = extractDoubleAtob(scriptTag) ?? '';
        } else {
          final match = RegExp(r"var url = '([^']*)'").firstMatch(scriptTag);
          secondaryLink = match?.group(1) ?? '';
        }
      }

      if (secondaryLink.isEmpty) return streams;

      if (!secondaryLink.startsWith('http')) {
        secondaryLink = baseUrl + secondaryLink;
      }

      // Fetch Step 2 Document (Card with buttons)
      final res2 = await http.get(
        Uri.parse(secondaryLink),
        headers: {"User-Agent": ProviderConfig.defaultUserAgent},
      ).timeout(const Duration(seconds: 10));
      final doc2 = parser.parse(res2.body);

      final headerText = doc2.querySelector('div.card-header')?.text.trim() ?? '';
      final sizeText = doc2.querySelector('i#size')?.text.trim() ?? '';
      final qualityLabel = '$headerText ${sizeText.isNotEmpty ? '[$sizeText]' : ''}'.trim();

      // Iterate over buttons
      final buttons = doc2.querySelectorAll('h2 a.btn');

      for (var btn in buttons) {
        final link = btn.attributes['href'] ?? '';
        final text = btn.text.trim();

        if (link.isEmpty) continue;

        if (text.contains('FSL Server')) {
          streams.add(StreamLink(
            name: 'V-Cloud [FSL Server]',
            streamUrl: link,
            quality: qualityLabel,
            isHls: link.contains('.m3u8'),
          ));
        } else if (text.contains('FSLv2')) {
          streams.add(StreamLink(
            name: 'V-Cloud [FSLv2 Server]',
            streamUrl: link,
            quality: qualityLabel,
            isHls: link.contains('.m3u8'),
          ));
        } else if (text.contains('Mega Server')) {
          streams.add(StreamLink(
            name: 'V-Cloud [Mega Server]',
            streamUrl: link,
            quality: qualityLabel,
            isHls: false,
          ));
        } else if (text.contains('Download File')) {
          streams.add(StreamLink(
            name: 'V-Cloud [Direct Download]',
            streamUrl: link,
            quality: qualityLabel,
            isHls: link.contains('.m3u8'),
          ));
        } else if (text.contains('BuzzServer')) {
          try {
            final client = http.Client();
            final req = http.Request('GET', Uri.parse('$link/download'))
              ..headers['Referer'] = link
              ..followRedirects = false;
            final buzzRes = await client.send(req).timeout(const Duration(seconds: 5));
            final hxRedirect = buzzRes.headers['hx-redirect'];
            if (hxRedirect != null) {
              final buzzBase = getBaseUrl(link);
              final finalBuzzUrl = hxRedirect.startsWith('http') ? hxRedirect : buzzBase + hxRedirect;
              streams.add(StreamLink(
                name: 'V-Cloud [BuzzServer]',
                streamUrl: finalBuzzUrl,
                quality: qualityLabel,
                isHls: finalBuzzUrl.contains('.m3u8'),
              ));
            }
            client.close();
          } catch (_) {}
        } else if (link.contains('pixeldra')) {
          final pixelLink = extractPxlUrl(res2.body);
          if (pixelLink != null) {
            final baseUrlLink = getBaseUrl(pixelLink);
            final finalUrl = pixelLink.toLowerCase().contains('download')
                ? pixelLink
                : '$baseUrlLink/api/file/${pixelLink.split('/').last}?download';
            streams.add(StreamLink(
              name: 'V-Cloud [Pixeldrain]',
              streamUrl: finalUrl,
              quality: qualityLabel,
              isHls: false,
            ));
          }
        } else if (text.contains('Server : 10Gbps')) {
          String? redirectUrl = await resolveFinalUrl(link);
          if (redirectUrl != null) {
            if (redirectUrl.contains('link=')) {
              redirectUrl = redirectUrl.split('link=')[1];
            }
            streams.add(StreamLink(
              name: 'V-Cloud [10Gbps Server]',
              streamUrl: redirectUrl,
              quality: qualityLabel,
              isHls: redirectUrl.contains('.m3u8'),
            ));
          }
        }
      }
    } catch (_) {}

    return streams;
  }
}
