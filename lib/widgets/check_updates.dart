import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mxstream/services/api_client.dart';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UpdateChecker {
  static Future<void> checkForUpdate(BuildContext context) async {
    if (kIsWeb) return;
    final currentVersion = await _getCurrentVersion();
    final latestVersion = await _getLatestVersion();

    if (!context.mounted) return;

    if (latestVersion != null &&
        _isNewerVersion(currentVersion, latestVersion)) {
      _showUpdateDialog(context, latestVersion);
    }
  }

  static Future<String> _getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  static Future<String?> _getLatestVersion() async {
    final response = await apiClient.get(Uri.parse(
        'https://api.github.com/repos/mirarr-app/mirarr/releases/latest'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['tag_name'];
    }
    return null;
  }

  static bool _isNewerVersion(String currentVersion, String latestVersion) {
    List<int> parseVersion(String version) {
      final clean = version.replaceAll(RegExp(r'^v'), '').split('-').first;
      final parts = clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      while (parts.length < 3) {
        parts.add(0);
      }
      return parts;
    }

    final current = parseVersion(currentVersion);
    final latest = parseVersion(latestVersion);

    for (int i = 0; i < 3; i++) {
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String newVersion) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          icon: Icon(Icons.system_update_rounded, color: colorScheme.primary, size: 32),
          title: Text(
            'Update Available',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          content: Text(
            'A new version ($newVersion) is available. Would you like to update now?',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                _launchURL(
                    'https://github.com/mirarr-app/mirarr/releases/latest');
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _launchURL(String url) async {
    if (await canLaunchUrlString(url.toString())) {
      await launchUrlString(url.toString());
    } else {
      throw 'Could not launch $url';
    }
  }
}
