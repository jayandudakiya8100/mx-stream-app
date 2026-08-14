import 'package:Mirarr/functions/show_error_dialog.dart';
import 'package:Mirarr/seriesPage/checkers/custom_tmdb_ids_effects_series.dart';
import 'package:Mirarr/widgets/custom_divider.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

Future<void> _launchUrl(Uri url) async {
  if (await canLaunchUrlString(url.toString())) {
    await launchUrlString(url.toString());
  } else {
    throw Exception('Could not launch url');
  }
}

Color getColor(BuildContext context, int serieId) =>
    getSeriesColor(context, serieId);

void showTorrentOptions(BuildContext context, String serieTitle, int serieId,
    int seasonNumber, int episodeNumber, String? imdbId) {
  final String seasonStr = seasonNumber.toString().padLeft(2, '0');
  final String episodeStr = episodeNumber.toString().padLeft(2, '0');

  final String? serieImdbId = imdbId;
  Map<String, String> optionPublicTorrents = {
    '1337x': 'https://1337x.to/search/$serieTitle s${seasonStr}e$episodeStr/1/',
    'SolidTorrents':
        'https://solidtorrents.to/search?q=$serieTitle s${seasonStr}e$episodeStr',
    'Ext':
        'https://ext.to/browse/?q=$serieTitle s${seasonStr}e$episodeStr',
    'Limetorrents':
        'https://www.limetorrents.lol/search/all/$serieTitle s${seasonStr}e$episodeStr',

  };
  Map<String, String> optionPrivateTorrents = {
    'IPTorrents': 'https://www.iptorrents.com/t?q=$serieImdbId',
    'TorrentLeech':
        'https://www.torrentleech.org/torrents/browse/index/query/$serieTitle s${seasonStr}e$episodeStr',
  };

  List<String> publicTorrents = optionPublicTorrents.keys.toList();
  List<String> privateTorrents = optionPrivateTorrents.keys.toList();

  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (BuildContext context) {
      Color mainColor = getColor(context, serieId);
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Text(
                'Torrent Trackers ($serieTitle)',
                style: TextStyle(
                  color: mainColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'PUBLIC TRACKERS',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  ...publicTorrents.map((option) {
                    final url = optionPublicTorrents[option];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: mainColor.withValues(alpha: 0.2),
                          child: Icon(Icons.download_rounded, color: mainColor, size: 20),
                        ),
                        title: Text(
                          option,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.open_in_new_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                        onTap: () {
                          if (url != null) {
                            _launchUrl(Uri.parse(url));
                          } else {
                            showErrorDialog('Error', 'URL not available for $option', context);
                          }
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'PRIVATE TRACKERS',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  ...privateTorrents.map((option) {
                    final url = optionPrivateTorrents[option];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: mainColor.withValues(alpha: 0.2),
                          child: Icon(Icons.lock_outline_rounded, color: mainColor, size: 20),
                        ),
                        title: Text(
                          option,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.open_in_new_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                        onTap: () {
                          if (url != null) {
                            _launchUrl(Uri.parse(url));
                          } else {
                            showErrorDialog('Error', 'URL not available for $option', context);
                          }
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
