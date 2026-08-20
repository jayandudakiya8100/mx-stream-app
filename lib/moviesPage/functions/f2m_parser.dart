import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mxstream/services/api_client.dart';

class F2MLink {
  final String label;
  final String url;

  const F2MLink({required this.label, required this.url});
}

class F2MDownloadItem {
  final String title;
  final String quality;
  final String encoder;
  final String size;
  final List<String> extraTags;
  final List<F2MLink> links;

  const F2MDownloadItem({
    required this.title,
    required this.quality,
    required this.encoder,
    required this.size,
    required this.extraTags,
    required this.links,
  });
}

class F2MSeasonGroup {
  final String seasonName;
  final List<F2MDownloadItem> items;

  const F2MSeasonGroup({
    required this.seasonName,
    required this.items,
  });
}

String sanitizeText(String input) {
  if (input.isEmpty) return input;
  String text = input;

  // Dictionary translations
  text = text.replaceAll('بدون حذفیات', 'Uncut');
  text = text.replaceAll('دو زبانه', 'Dual Audio');
  text = text.replaceAll('دوبله فارسی', 'Persian Dubbed');
  text = text.replaceAll('دوبله', 'Dubbed');
  text = text.replaceAll('زیرنویس چسبیده', 'Soft Subbed');
  text = text.replaceAll('زیرنویس فارسی', 'Persian Subs');
  text = text.replaceAll('زیرنویس', 'Subs');
  text = text.replaceAll('کیفیت', 'Quality');
  text = text.replaceAll('انکودر', 'Encoder');
  text = text.replaceAll('میانگین حجم', 'Avg Size');
  text = text.replaceAll('حجم', 'Size');
  text = text.replaceAll('نامشخص', '');
  text = text.replaceAll('فصل', 'Season');
  text = text.replaceAll('قسمت', 'Episode');
  text = text.replaceAll('دانلود', 'Download');
  text = text.replaceAll('لینک', 'Link');
  text = text.replaceAll('فیلم', '');

  // Strip any remaining Persian / Arabic characters
  text = text.replaceAll(
      RegExp(
          r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]+'),
      '');

  // Clean up punctuation and whitespace
  text = text.replaceAll(RegExp(r'^[^\w\d\(\)\[\]\-]+'), '');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

List<F2MSeasonGroup> parseF2MDownloads(String html) {
  try {
    final document = html_parser.parse(html);
    final sec = document.getElementById('downloads');
    if (sec == null) return [];

    final List<F2MSeasonGroup> result = [];
    final seasons = sec.querySelectorAll('.download-season');

    if (seasons.isNotEmpty) {
      for (final season in seasons) {
        final sName = _seasonName(season);
        final lists = season
            .querySelectorAll('.download-list')
            .where((dl) => _findParent(dl, 'download-season') == season);
        final items = _parseLists(lists);
        if (items.isNotEmpty) {
          result.add(F2MSeasonGroup(seasonName: sName, items: items));
        }
      }
    } else {
      final lists = sec
          .querySelectorAll('.download-list')
          .where((dl) => _findParent(dl, 'download-season') == null);
      final items = _parseLists(lists);
      if (items.isNotEmpty) {
        result.add(F2MSeasonGroup(seasonName: '', items: items));
      }
    }

    return result;
  } catch (e) {
    return [];
  }
}

List<F2MDownloadItem> _parseLists(Iterable<Element> lists) {
  final List<F2MDownloadItem> result = [];
  for (final dl in lists) {
    final titleEl =
        dl.querySelector('p.title span') ?? dl.querySelector('p.title');
    final rawTitle = _textOf(titleEl);

    // Extract extra tags from rawTitle
    final extraTags = <String>[];
    if (rawTitle.contains('بدون حذفیات')) {
      extraTags.add('Uncut');
    }
    if (rawTitle.contains('دو زبانه')) {
      extraTags.add('Dual Audio');
    }
    if (rawTitle.contains('دوبله فارسی')) {
      extraTags.add('Persian Dubbed');
    } else if (rawTitle.contains('دوبله')) {
      extraTags.add('Dubbed');
    }
    if (rawTitle.contains('زیرنویس چسبیده')) {
      extraTags.add('Soft Subbed');
    } else if (rawTitle.contains('زیرنویس فارسی')) {
      extraTags.add('Persian Subs');
    } else if (rawTitle.contains('زیرنویس')) {
      extraTags.add('Subs');
    }

    for (final li
        in _directChildren(dl, 'ul').expand((ul) => _directChildren(ul, 'li'))) {
      final rawQuality = _field(li, 'کیفیت');
      final rawEncoder = _field(li, 'انکودر');
      final sizeAvg = _field(li, 'میانگین حجم');
      final rawSize = sizeAvg.isNotEmpty ? sizeAvg : _field(li, 'حجم');

      final cleanQuality = sanitizeText(rawQuality);
      final cleanEncoder = sanitizeText(rawEncoder);
      final cleanSize = sanitizeText(rawSize);

      // Quality is the main title!
      String mainTitle = cleanQuality;
      if (mainTitle.isEmpty) {
        final cleanRawTitle = sanitizeText(rawTitle);
        mainTitle = cleanRawTitle;
      }
      if (mainTitle.isEmpty) {
        mainTitle = 'HD Quality';
      }

      final links = _episodeLinks(li);
      if (links.isNotEmpty) {
        result.add(F2MDownloadItem(
          title: mainTitle,
          quality: cleanQuality,
          encoder: cleanEncoder,
          size: const {'—', '-', '–', 'mdash;'}.contains(cleanSize) ? '' : cleanSize,
          extraTags: extraTags,
          links: links
              .map((l) => F2MLink(
                    label: sanitizeText(l.$1).isEmpty ? 'Download' : sanitizeText(l.$1),
                    url: l.$2,
                  ))
              .toList(),
        ));
      }
    }
  }
  return result;
}

String _seasonName(Element season) {
  final btn = season.querySelector('button');
  if (btn == null) return 'Season';

  final badge = btn.querySelector('span');
  final badgeText = _textOf(badge);

  String rawName = btn.nodes
      .whereType<Text>()
      .map((t) => t.text.trim())
      .where((t) => t.isNotEmpty)
      .join(' ')
      .trim();

  if (rawName.isEmpty) {
    rawName = _textOf(btn);
  }

  if (badgeText.isNotEmpty && rawName.contains(badgeText)) {
    rawName = rawName.replaceAll(badgeText, '').trim();
  }

  final cleanName = _translateSeasonName(rawName);
  final cleanBadge = _translateBadge(badgeText);

  if (cleanBadge.isNotEmpty) {
    return '$cleanName [$cleanBadge]';
  }
  return cleanName;
}

String _translateSeasonName(String input) {
  if (input.isEmpty) return 'Season';
  String text = input;

  const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  for (int i = 0; i < 10; i++) {
    text = text.replaceAll(persianDigits[i], englishDigits[i]);
  }

  final Map<String, String> seasonMap = {
    'اول': '1',
    'دوم': '2',
    'سوم': '3',
    'چهارم': '4',
    'پنجم': '5',
    'ششم': '6',
    'هفتم': '7',
    'هشتم': '8',
    'نهم': '9',
    'دهم': '10',
    'یازدهم': '11',
    'دوازدهم': '12',
    'سیزدهم': '13',
    'چهاردهم': '14',
    'پانزدهم': '15',
    'شانزدهم': '16',
    'هفدهم': '17',
    'هجدهم': '18',
    'نوزدهم': '19',
    'بیستم': '20',
  };

  for (final entry in seasonMap.entries) {
    if (text.contains(entry.key)) {
      return 'Season ${entry.value}';
    }
  }

  final numMatch = RegExp(r'\d+').firstMatch(text);
  if (numMatch != null) {
    final sNum = int.tryParse(numMatch.group(0) ?? '') ?? 1;
    return 'Season $sNum';
  }

  final clean = sanitizeText(text);
  if (clean.isEmpty) return 'Season';
  if (!clean.toLowerCase().contains('season')) {
    return 'Season $clean';
  }
  return clean;
}

String _translateBadge(String input) {
  if (input.isEmpty) return '';
  if (input.contains('به اتمام رسیده')) return 'Completed';
  if (input.contains('در حال پخش')) return 'Ongoing';
  return sanitizeText(input);
}

String _field(Element row, String labelKey) {
  final key = labelKey.replaceAll(' ', '');
  for (final span in row.querySelectorAll('span')) {
    final label = _textOf(span).replaceAll(RegExp(r'\s+'), '');
    final raw = _textOf(span);
    if (!label.contains(key) || !raw.contains(':')) continue;

    final nxt = span.nextElementSibling;
    if (nxt != null) {
      final val = _textOf(nxt);
      if (val.isNotEmpty) return val;
    }

    final parentNode = span.parentNode;
    if (parentNode != null) {
      final siblings = parentNode.nodes;
      final i = siblings.indexOf(span);
      if (i >= 0 && i + 1 < siblings.length) {
        final next = siblings[i + 1];
        if (next is Text) {
          final val = next.text.trim();
          if (val.isNotEmpty) return val;
        }
      }
    }

    final parentText = _textOf(span.parent);
    final idx = parentText.indexOf(':');
    if (idx >= 0 && idx + 1 < parentText.length) {
      return parentText.substring(idx + 1).trim();
    }
  }
  return '';
}

List<(String, String)> _episodeLinks(Element container) {
  final links = <(String, String)>[];
  final seen = <String>{};

  for (final a in container.querySelectorAll('a.btn-default[href]')) {
    final href = (a.attributes['href'] ?? '').trim();
    if (!href.startsWith('http') || !seen.add(href)) continue;
    final label = _textOf(a).isEmpty ? 'Download' : _textOf(a);
    links.add((label, href));
  }
  if (links.isNotEmpty) return links;

  for (final a in container.querySelectorAll('a[onclick]')) {
    final onclick = a.attributes['onclick'] ?? '';
    if (!onclick.contains('handleDownloadClick')) continue;
    final href = _extractHandleDownloadClickUrl(onclick);
    if (href == null || !seen.add(href)) continue;
    final label = _textOf(a).isEmpty ? 'Download' : _textOf(a);
    links.add((label, href));
  }
  return links;
}

String? _extractHandleDownloadClickUrl(String onclick) {
  final single = onclick.indexOf("'");
  if (single >= 0) {
    final end = onclick.indexOf("'", single + 1);
    if (end > single) return onclick.substring(single + 1, end);
  }
  final dbl = onclick.indexOf('"');
  if (dbl >= 0) {
    final end = onclick.indexOf('"', dbl + 1);
    if (end > dbl) return onclick.substring(dbl + 1, end);
  }
  return null;
}

Element? _findParent(Element el, String className) {
  Element? p = el.parent;
  while (p != null) {
    if (p.classes.contains(className)) return p;
    p = p.parent;
  }
  return null;
}

Iterable<Element> _directChildren(Element parent, String tag) {
  return parent.children.where((c) => c.localName == tag);
}

String _textOf(Element? el) {
  if (el == null) return '';
  return el.text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

Future<List<F2MSeasonGroup>> fetchF2MDownloadLinks(String imdbId) async {
  if (imdbId.isEmpty) return [];
  final formattedId = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';

  try {
    const searchUrl = 'https://www.nilfgaard.top/quick-search';
    const siteOrigin = 'https://www.nilfgaard.top';

    final response = await apiClient.post(
      Uri.parse(searchUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'q=${Uri.encodeQueryComponent(formattedId)}&sort=${Uri.encodeQueryComponent('modified_at:desc')}',
      timeout: const Duration(seconds: 10),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];

    String? pageUrl;
    for (final item in decoded) {
      if (item is! Map) continue;
      if (item['imdb_id']?.toString() != formattedId) continue;
      final path = item['url']?.toString();
      if (path == null || path.isEmpty) continue;
      pageUrl = path.startsWith('http') ? path : '$siteOrigin$path';
      break;
    }

    if (pageUrl == null) return [];

    final pageResponse = await apiClient.get(
      Uri.parse(pageUrl),
      timeout: const Duration(seconds: 12),
    );

    if (pageResponse.statusCode < 200 || pageResponse.statusCode >= 300) {
      return [];
    }

    return parseF2MDownloads(pageResponse.body);
  } catch (_) {
    return [];
  }
}
