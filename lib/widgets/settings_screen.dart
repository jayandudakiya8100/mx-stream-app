import 'package:Mirarr/functions/navigation_provider.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/functions/themeprovider_class.dart';
import 'package:Mirarr/functions/supabase_provider.dart';
import 'package:Mirarr/services/supabase_sync_service.dart';
import 'package:Mirarr/functions/platform_helper.dart';
import 'package:Mirarr/widgets/custom_divider.dart';
import 'package:Mirarr/widgets/m3_expressive_spinner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:Mirarr/database/watch_history_database.dart';
import 'package:Mirarr/models/watch_history_model.dart';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Mirarr/services/api_client.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:Mirarr/functions/file_saver.dart' as fs;
import 'package:Mirarr/widgets/extensions_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _supabaseUrlController = TextEditingController();
  final TextEditingController _supabaseAnonKeyController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSyncing = false;
  Map<String, dynamic>? _syncStatus;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      _supabaseUrlController.text = supabaseProvider.supabaseUrl ?? '';
      _supabaseAnonKeyController.text = supabaseProvider.supabaseAnonKey ?? '';
      _loadSyncStatus();
    });
  }

  @override
  void dispose() {
    _supabaseUrlController.dispose();
    _supabaseAnonKeyController.dispose();
    super.dispose();
  }

  void _loadSyncStatus() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (supabaseProvider.isConfigured) {
      final syncService = SupabaseSyncService(supabaseProvider.client);
      final status = await syncService.getSyncStatus();
      setState(() {
        _syncStatus = status;
      });
    }
  }

  void _saveSupabaseConfig() async {
    if (_formKey.currentState!.validate()) {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      await supabaseProvider.setSupabaseConfig(
        _supabaseUrlController.text.trim().isEmpty ? null : _supabaseUrlController.text.trim(),
        _supabaseAnonKeyController.text.trim().isEmpty ? null : _supabaseAnonKeyController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            supabaseProvider.isConfigured
              ? 'Supabase configuration saved successfully!'
              : 'Supabase configuration cleared',
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );

      // Reload sync status after configuration change
      _loadSyncStatus();
    }
  }

  void _clearSupabaseConfig() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    await supabaseProvider.clearSupabaseConfig();
    _supabaseUrlController.clear();
    _supabaseAnonKeyController.clear();

    setState(() {
      _syncStatus = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Supabase configuration cleared'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  void _uploadWatchHistory() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (!supabaseProvider.isConfigured) return;

    setState(() {
      _isSyncing = true;
    });

    final syncService = SupabaseSyncService(supabaseProvider.client);
    final success = await syncService.uploadWatchHistory();

    setState(() {
      _isSyncing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
            ? 'Watch history uploaded successfully!'
            : 'Failed to sync watch history. Check your connection. Make sure you have configured Supabase correctly. Read the documentation for more information.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _loadSyncStatus();
    }
  }

  void _downloadWatchHistory() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (!supabaseProvider.isConfigured) return;

    setState(() {
      _isSyncing = true;
    });

    final syncService = SupabaseSyncService(supabaseProvider.client);
    final success = await syncService.downloadWatchHistory();

    setState(() {
      _isSyncing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
            ? 'Watch history downloaded successfully!'
            : 'Failed to sync watch history. Check your connection. Make sure you have configured Supabase correctly. Read the documentation for more information.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _loadSyncStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () {
            final modalRoute = ModalRoute.of(context);
            if (modalRoute != null && !modalRoute.isFirst) {
              Navigator.pop(context);
            } else {
              Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
            }
          },
        ),
        title: Text(
          'Settings',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Extensions & Repositories Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Extensions & Providers',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const CustomDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExtensionsScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.extension_rounded,
                              color: colorScheme.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Extensions',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Manage repositories & installed plugins',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: colorScheme.onSurfaceVariant,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Supabase Configuration Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Supabase Configuration',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const CustomDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Consumer<SupabaseProvider>(
                builder: (context, supabaseProvider, child) {
                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configure your Supabase project to sync your watch history across devices. Configuration is saved locally.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _supabaseUrlController,
                          decoration: InputDecoration(
                            labelText: 'Supabase URL',
                            hintText: 'https://your-project.supabase.co',
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHigh,
                            labelStyle: TextStyle(color: colorScheme.primary),
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                          ),
                          style: TextStyle(color: colorScheme.onSurface),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final uri = Uri.tryParse(value);
                              if (uri == null) {
                                return 'Please enter a valid URL';
                              }
                              if (!value.contains('supabase.co')) {
                                return 'Please enter a valid Supabase URL';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _supabaseAnonKeyController,
                          decoration: InputDecoration(
                            labelText: 'Supabase Anon Key',
                            hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHigh,
                            labelStyle: TextStyle(color: colorScheme.primary),
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                          ),
                          style: TextStyle(color: colorScheme.onSurface),
                          obscureText: true,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (value.length < 50) {
                                return 'Anon key seems too short';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: _saveSupabaseConfig,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text('Save Configuration'),
                            ),
                            OutlinedButton(
                              onPressed: _clearSupabaseConfig,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.onSurface,
                                side: BorderSide(color: colorScheme.outlineVariant),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (supabaseProvider.isConfigured)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Supabase configured successfully',
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 14),
                                ),
                              ],
                            ),
                          ),

                        // Sync Section
                        if (supabaseProvider.isConfigured) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Sync Watch History',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_syncStatus != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sync Status',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Local items: ${_syncStatus!['local_count']}',
                                    style: TextStyle(color: colorScheme.onSurface),
                                  ),
                                  Text(
                                    'Remote items: ${_syncStatus!['remote_count']}',
                                    style: TextStyle(color: colorScheme.onSurface),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _isSyncing ? null : _uploadWatchHistory,
                                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                                label: const Text('Upload'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _isSyncing ? null : _downloadWatchHistory,
                                icon: const Icon(Icons.cloud_download_rounded, size: 18),
                                label: const Text('Download'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.greenAccent[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                tileColor: colorScheme.surfaceContainerHigh,
                title: Text('Documentation', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                onTap: () {
                  launchUrl(Uri.parse('https://github.com/mirarr-app/mirarr/blob/main/SUPABASE_SETUP.md'));
                },
                trailing: Icon(Icons.arrow_forward_ios_rounded, color: colorScheme.primary, size: 18),
              ),
            ),

            // Import Data Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Import Data',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const CustomDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.import_contacts_rounded, color: colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Import from Letterboxd',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Go to letterboxd.com/settings/data/\n2. Export your data and unzip the downloaded file.\n3. Tap below and select the "watched.csv" file.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openLetterboxdSettings,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Open Letterboxd'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(color: colorScheme.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _importLetterboxdCsv,
                          icon: const Icon(Icons.file_upload_rounded, size: 18),
                          label: const Text('Select watched.csv'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tv_rounded, color: colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Import from TV Time',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Use the "TV Time Out by Refract" extension to export either of your movies or series JSON files.\n2. Tap below to select and import the JSON file.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _importTvTimeJson,
                      icon: const Icon(Icons.file_upload_rounded),
                      label: const Text('Select JSON File'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restore_rounded, color: colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Restore Backup',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Import your exported watched history JSON files (will be merged into existing history) or replace the entire database with a .db backup file.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _importMoviesJson,
                          icon: const Icon(Icons.movie_outlined, size: 18),
                          label: const Text('Movies (JSON)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(color: colorScheme.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _importShowsJson,
                          icon: const Icon(Icons.tv_outlined, size: 18),
                          label: const Text('TV Shows (JSON)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(color: colorScheme.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        if (!kIsWeb)
                          FilledButton.icon(
                            onPressed: _importDbFile,
                            icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
                            label: const Text('Database (.db)'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Export Data Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Export Data',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const CustomDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.download_rounded, color: colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Export Shelf Database',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Export your local shelf database as JSON files (separate for movies and TV shows) or as the SQLite .db file itself.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _exportMoviesJson,
                          icon: const Icon(Icons.movie_outlined, size: 18),
                          label: const Text('Movies (JSON)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(color: colorScheme.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _exportShowsJson,
                          icon: const Icon(Icons.tv_outlined, size: 18),
                          label: const Text('TV Shows (JSON)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(color: colorScheme.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        if (!kIsWeb)
                          FilledButton.icon(
                            onPressed: _exportDbFile,
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Database (.db)'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Region Selection Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Select Region',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const CustomDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Consumer<RegionProvider>(
                builder: (context, regionProvider, child) {
                  return DropdownButtonFormField<String>(
                    dropdownColor: colorScheme.surfaceContainerHigh,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHigh,
                      labelText: 'Select Region',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      labelStyle: TextStyle(color: colorScheme.primary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                    ),
                    initialValue: regionProvider.currentRegion,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                    items: [
                      DropdownMenuItem<String>(
                        value: 'iran',
                        child: Text('Iran', style: TextStyle(color: colorScheme.onSurface)),
                      ),
                      DropdownMenuItem<String>(
                        value: 'worldwide',
                        child: Text('Worldwide', style: TextStyle(color: colorScheme.onSurface)),
                      ),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        Provider.of<RegionProvider>(context, listen: false)
                            .setRegion(newValue);
                      }
                    },
                  );
                },
              ),
            ),

            // Theme Selection Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Text(
                'Select Theme',
                style: TextStyle(
                    color: Theme.of(context).primaryColor, fontSize: 20),
              ),
            ),
            const CustomDivider(),

            // Theme List
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ListTile(
                  title: const Text('Orange Theme',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  trailing: const Icon(Icons.circle, color: Colors.orange),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme(AppThemes.orangeTheme);
                  },
                ),
                ListTile(
                  title: const Text(
                    'Blue Theme',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  trailing: const Icon(Icons.circle, color: Colors.blue),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme(AppThemes.blueTheme);
                  },
                ),
                ListTile(
                  title: const Text(
                    'Red Theme',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  trailing: const Icon(Icons.circle, color: Colors.red),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme(AppThemes.redTheme);
                  },
                ),
                ListTile(
                  title: const Text('Yellow Theme',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  trailing: const Icon(Icons.circle, color: Colors.yellow),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme(AppThemes.yellowTheme);
                  },
                ),
                ListTile(
                  title: const Text('Grey Theme',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  trailing: const Icon(Icons.circle, color: Colors.grey),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme(AppThemes.greyTheme);
                  },
                ),
                ListTile(
                  title: const Text('Brown Theme',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  trailing: const Icon(Icons.circle, color: Colors.brown),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme(AppThemes.brownTheme);
                  },
                ),
                ListTile(
                  title: const Text('Green Theme',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  trailing: const Icon(Icons.circle, color: Colors.green),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme(AppThemes.greenTheme);
                  },
                ),
                ListTile(
                  title: const Text('Mono Theme',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                  trailing: const Text(
                    'Mono',
                    style:
                        TextStyle(color: Colors.grey, fontFamily: 'RobotoMono'),
                  ),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme(AppThemes.monoFontTheme);
                  },
                ),
                ListTile(
                  title: const Text('Nothing',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  trailing: const Icon(Icons.circle, color: Colors.grey),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme(AppThemes.nothingFontTheme);
                  },
                ),
                if (AppPlatform.isAndroid)
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      return ListTile(
                        title: const Text('Material You (Dynamic Colors)',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                        subtitle: Text(
                          'Use system wallpaper colors',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.palette_outlined,
                          color: themeProvider.isDynamicTheme
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                        onTap: () {
                          themeProvider.setDynamicTheme();
                        },
                      );
                    },
                  ),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    if (!themeProvider.isOmarchyLinux) {
                      return const SizedBox.shrink();
                    }
                    return ListTile(
                      title: const Text('Omarchy Theme',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          )),
                      trailing: const Text(
                        'Omarchy',
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'RobotoMono',
                        ),
                      ),
                      onTap: () {
                        themeProvider.setOmarchyTheme();
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openLetterboxdSettings() async {
    final url = Uri.parse('https://letterboxd.com/settings/data/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Letterboxd settings URL')),
        );
      }
    }
  }

  List<List<String>> _parseCsv(String content) {
    final List<List<String>> rows = [];
    List<String> currentRow = [];
    StringBuffer currentField = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            currentField.write('"');
            i++; // Skip next quote
          } else {
            inQuotes = false;
          }
        } else {
          currentField.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
        } else if (char == '\n' || char == '\r') {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          if (currentRow.any((field) => field.isNotEmpty)) {
            rows.add(currentRow);
          }
          currentRow = [];
          if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
            i++; // Skip \n
          }
        } else {
          currentField.write(char);
        }
      }
    }
    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString().trim());
      if (currentRow.any((field) => field.isNotEmpty)) {
        rows.add(currentRow);
      }
    }
    return rows;
  }

  void _importLetterboxdCsv() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
        // On web the default blur handling cancels the pick one second after
        // the window regains focus, which races the browser's change event.
        cancelUploadOnWindowBlur: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content = '';
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        final ioFile = File(file.path!);
        content = await ioFile.readAsString();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to read file content')),
          );
        }
        return;
      }

      final rows = _parseCsv(content);
      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected CSV file is empty')),
          );
        }
        return;
      }

      final header = rows.first.map((e) => e.trim().toLowerCase()).toList();
      final dateIdx = header.indexOf('date');
      final nameIdx = header.indexOf('name');
      final yearIdx = header.indexOf('year');

      if (dateIdx == -1 || nameIdx == -1 || yearIdx == -1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid Letterboxd CSV. Missing columns: Date, Name, or Year.'),
            ),
          );
        }
        return;
      }

      final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
      final baseUrl = getBaseUrl(region);
      final apiKey = dotenv.env['TMDB_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('TMDB API Key is missing. Check setup.')),
          );
        }
        return;
      }

      if (mounted) {
        final importedCount = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (context) => ImportProgressDialog(
            csvRows: rows,
            dateIdx: dateIdx,
            nameIdx: nameIdx,
            yearIdx: yearIdx,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
        );

        if (importedCount != null && importedCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported $importedCount watched movies!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking or parsing CSV file: $e')),
        );
      }
    }
  }

  void _importTvTimeJson() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
        cancelUploadOnWindowBlur: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content = '';
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        final ioFile = File(file.path!);
        content = await ioFile.readAsString();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to read file content')),
          );
        }
        return;
      }

      final dynamic decoded = json.decode(content);
      if (decoded is! List) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid JSON format. Expected a JSON array.')),
          );
        }
        return;
      }

      if (!mounted) return;
      final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
      final baseUrl = getBaseUrl(region);
      final apiKey = dotenv.env['TMDB_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('TMDB API Key is missing. Check setup.')),
          );
        }
        return;
      }

      if (mounted) {
        final importedCount = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (context) => TvTimeImportProgressDialog(
            jsonList: decoded,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
        );

        if (importedCount != null && importedCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported $importedCount items!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking or parsing JSON file: $e')),
        );
      }
    }
  }

  void _exportMoviesJson() async {
    try {
      final db = WatchHistoryDatabase();
      final movies = await db.getWatchedMovies();
      if (movies.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No watched movies to export.')),
          );
        }
        return;
      }

      final listMap = movies.map((item) => item.toMap()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(listMap);

      if (kIsWeb) {
        fs.saveFile(jsonString, 'watched_movies.json');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Movies exported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (Platform.isLinux || Platform.isWindows) {
        final outputFile = await FilePicker.saveFile(
          dialogTitle: 'Save Watched Movies JSON',
          fileName: 'watched_movies.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(jsonString);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Movies exported successfully to $outputFile'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/watched_movies.json';
        final file = File(filePath);
        await file.writeAsString(jsonString);

        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Mirarr Watched Movies Export',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting movies: $e')),
        );
      }
    }
  }

  void _exportShowsJson() async {
    try {
      final db = WatchHistoryDatabase();
      final shows = await db.getWatchedShows();
      if (shows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No watched TV shows to export.')),
          );
        }
        return;
      }

      final listMap = shows.map((item) => item.toMap()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(listMap);

      if (kIsWeb) {
        fs.saveFile(jsonString, 'watched_shows.json');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('TV shows exported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (Platform.isLinux || Platform.isWindows) {
        final outputFile = await FilePicker.saveFile(
          dialogTitle: 'Save Watched TV Shows JSON',
          fileName: 'watched_shows.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(jsonString);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('TV shows exported successfully to $outputFile'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/watched_shows.json';
        final file = File(filePath);
        await file.writeAsString(jsonString);

        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Mirarr Watched TV Shows Export',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting TV shows: $e')),
        );
      }
    }
  }

  void _exportDbFile() async {
    if (kIsWeb) return;
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = p.join(documentsDirectory.path, 'watch_history.db');
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database file does not exist yet.')),
          );
        }
        return;
      }

      if (Platform.isLinux || Platform.isWindows) {
        final outputFile = await FilePicker.saveFile(
          dialogTitle: 'Save Database File',
          fileName: 'watch_history.db',
          type: FileType.custom,
          allowedExtensions: ['db'],
        );
        if (outputFile != null) {
          await dbFile.copy(outputFile);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Database exported successfully to $outputFile'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        final tempDirectory = await getTemporaryDirectory();
        final tempDbPath = p.join(tempDirectory.path, 'watch_history.db');
        await dbFile.copy(tempDbPath);

        await Share.shareXFiles(
          [XFile(tempDbPath)],
          subject: 'Mirarr Database Export',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting database file: $e')),
        );
      }
    }
  }

  void _importMoviesJson() => _importWatchHistoryJson(
        kind: 'movies',
        progressLabel: 'Importing movie watch history...',
      );

  void _importShowsJson() => _importWatchHistoryJson(
        kind: 'TV shows',
        progressLabel: 'Importing TV shows watch history...',
      );

  Future<void> _importWatchHistoryJson({
    required String kind,
    required String progressLabel,
  }) async {
    bool isDialogOpen = false;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
        cancelUploadOnWindowBlur: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content = '';
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (!kIsWeb && file.path != null) {
        final ioFile = File(file.path!);
        content = await ioFile.readAsString();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to read file content')),
          );
        }
        return;
      }

      final dynamic decoded = json.decode(content);
      if (decoded is! List) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid JSON format. Expected a JSON list.')),
          );
        }
        return;
      }

      final List<WatchHistoryItem> items = [];
      var skipped = 0;
      for (final rawMap in decoded) {
        if (rawMap is! Map) {
          skipped++;
          continue;
        }
        try {
          items.add(
            WatchHistoryItem.fromMap(Map<String, dynamic>.from(rawMap)),
          );
        } catch (e) {
          skipped++;
          debugPrint('Skipping invalid $kind watch history item: $e');
        }
      }

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No valid $kind watch history items found.')),
          );
        }
        return;
      }

      if (mounted) {
        isDialogOpen = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              content: Row(
                children: [
                  const M3ExpressiveSpinner(size: 28),
                  const SizedBox(width: 20),
                  Expanded(child: Text(progressLabel)),
                ],
              ),
            ),
          ),
        ).then((_) => isDialogOpen = false);
      }

      final db = WatchHistoryDatabase();
      await db.importWatchHistory(items);

      if (mounted && isDialogOpen) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${items.length} watched $kind!'
              '${skipped > 0 ? ' Skipped $skipped unreadable entries.' : ''}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && isDialogOpen) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing $kind: $e')),
        );
      }
    }
  }

  void _importDbFile() async {
    if (kIsWeb) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        cancelUploadOnWindowBlur: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = p.join(documentsDirectory.path, 'watch_history.db');

      final db = WatchHistoryDatabase();
      await db.close();

      if (file.bytes != null) {
        final ioFile = File(dbPath);
        await ioFile.writeAsBytes(file.bytes!);
      } else if (file.path != null) {
        final ioFile = File(file.path!);
        await ioFile.copy(dbPath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to read database file.')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database restored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring database: $e')),
        );
      }
    }
  }
}

class ImportProgressDialog extends StatefulWidget {
  final List<List<String>> csvRows;
  final int dateIdx;
  final int nameIdx;
  final int yearIdx;
  final String baseUrl;
  final String? apiKey;

  const ImportProgressDialog({
    Key? key,
    required this.csvRows,
    required this.dateIdx,
    required this.nameIdx,
    required this.yearIdx,
    required this.baseUrl,
    required this.apiKey,
  }) : super(key: key);

  @override
  _ImportProgressDialogState createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<ImportProgressDialog> {
  int _processedCount = 0;
  int _successCount = 0;
  int _failedCount = 0;
  bool _isCancelled = false;
  bool _isFinished = false;
  String _currentMovieName = '';
  final WatchHistoryDatabase _db = WatchHistoryDatabase();

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  void _startImport() async {
    for (int i = 1; i < widget.csvRows.length; i++) {
      if (_isCancelled) break;

      final row = widget.csvRows[i];
      if (row.length <= widget.nameIdx || row.length <= widget.dateIdx || row.length <= widget.yearIdx) {
        if (mounted) {
          setState(() {
            _processedCount++;
            _failedCount++;
          });
        }
        continue;
      }

      final dateStr = row[widget.dateIdx].trim();
      final name = row[widget.nameIdx].trim();
      final yearStr = row[widget.yearIdx].trim();

      if (name.isEmpty) {
        if (mounted) {
          setState(() {
            _processedCount++;
            _failedCount++;
          });
        }
        continue;
      }

      if (mounted) {
        setState(() {
          _currentMovieName = name;
        });
      }

      final date = DateTime.tryParse(dateStr) ?? DateTime.now();

      try {
        int? tmdbId;
        String? title;
        String? posterPath;

        String searchUrl = '${widget.baseUrl}search/movie?api_key=${widget.apiKey}&query=${Uri.encodeComponent(name)}';
        if (yearStr.isNotEmpty) {
          searchUrl += '&primary_release_year=$yearStr';
        }

        var response = await apiClient.get(Uri.parse(searchUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> results = data['results'] ?? [];
          if (results.isNotEmpty) {
            final first = results.first;
            tmdbId = first['id'];
            title = first['title'];
            posterPath = first['poster_path'];
          }
        }

        if (tmdbId == null && yearStr.isNotEmpty) {
          final fallbackUrl = '${widget.baseUrl}search/movie?api_key=${widget.apiKey}&query=${Uri.encodeComponent(name)}';
          response = await apiClient.get(Uri.parse(fallbackUrl));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final List<dynamic> results = data['results'] ?? [];
            if (results.isNotEmpty) {
              final first = results.first;
              tmdbId = first['id'];
              title = first['title'];
              posterPath = first['poster_path'];
            }
          }
        }

        if (tmdbId != null && title != null) {
          await _db.addMovieToHistory(
            tmdbId: tmdbId,
            title: title,
            posterPath: posterPath,
            watchedAt: date,
          );
          _successCount++;
        } else {
          _failedCount++;
        }
      } catch (e) {
        _failedCount++;
      }

      if (mounted) {
        setState(() {
          _processedCount++;
        });
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      setState(() {
        _isFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.csvRows.length - 1;
    final progress = total > 0 ? _processedCount / total : 0.0;

    return PopScope(
      canPop: _isFinished || _isCancelled,
      child: AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          _isFinished
              ? 'Import Completed'
              : _isCancelled
                  ? 'Import Cancelled'
                  : 'Importing movies...',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isFinished && !_isCancelled) ...[
              Text(
                'Processing: $_currentMovieName',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Total processed: $_processedCount / $total',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Successful: $_successCount',
              style: const TextStyle(color: Colors.green),
            ),
            Text(
              'Failed / Unmatched: $_failedCount',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          if (!_isFinished && !_isCancelled)
            TextButton(
              onPressed: () {
                setState(() {
                  _isCancelled = true;
                });
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          if (_isFinished || _isCancelled)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(_successCount);
              },
              child: Text(
                'Close',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}

class TvTimeImportProgressDialog extends StatefulWidget {
  final List<dynamic> jsonList;
  final String baseUrl;
  final String? apiKey;

  const TvTimeImportProgressDialog({
    Key? key,
    required this.jsonList,
    required this.baseUrl,
    required this.apiKey,
  }) : super(key: key);

  @override
  State<TvTimeImportProgressDialog> createState() => _TvTimeImportProgressDialogState();
}

class _TvTimeImportProgressDialogState extends State<TvTimeImportProgressDialog> {
  int _processedCount = 0;
  int _totalCount = 0;
  int _successCount = 0;
  int _failedCount = 0;
  bool _isCancelled = false;
  bool _isFinished = false;
  bool _isSeries = false;
  String _currentName = '';
  final WatchHistoryDatabase _db = WatchHistoryDatabase();

  // Cache show/movie lookups to avoid redundant API queries
  final Map<String, Map<String, dynamic>?> _tmdbCache = {};

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<Map<String, dynamic>?> _findMovieTmdb({
    required String title,
    int? tvdbId,
    String? imdbId,
    int? year,
    required String baseUrl,
    required String apiKey,
  }) async {
    if (imdbId != null && imdbId.isNotEmpty) {
      try {
        final findUrl = '${baseUrl}find/$imdbId?api_key=$apiKey&external_source=imdb_id';
        final response = await apiClient.get(Uri.parse(findUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> results = data['movie_results'] ?? [];
          if (results.isNotEmpty) {
            return results.first;
          }
        }
      } catch (_) {}
    }

    if (tvdbId != null) {
      try {
        final findUrl = '${baseUrl}find/$tvdbId?api_key=$apiKey&external_source=tvdb_id';
        final response = await apiClient.get(Uri.parse(findUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> results = data['movie_results'] ?? [];
          if (results.isNotEmpty) {
            return results.first;
          }
        }
      } catch (_) {}
    }

    // Fallback to search
    try {
      String searchUrl = '${baseUrl}search/movie?api_key=$apiKey&query=${Uri.encodeComponent(title)}';
      if (year != null) {
        searchUrl += '&primary_release_year=$year';
      }
      var response = await apiClient.get(Uri.parse(searchUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        if (results.isNotEmpty) {
          return results.first;
        }
      }

      if (year != null) {
        // Try search without year
        final searchUrlNoYear = '${baseUrl}search/movie?api_key=$apiKey&query=${Uri.encodeComponent(title)}';
        response = await apiClient.get(Uri.parse(searchUrlNoYear));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> results = data['results'] ?? [];
          if (results.isNotEmpty) {
            return results.first;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<Map<String, dynamic>?> _findTvTmdb({
    required String title,
    int? tvdbId,
    String? imdbId,
    required String baseUrl,
    required String apiKey,
  }) async {
    if (tvdbId != null) {
      try {
        final findUrl = '${baseUrl}find/$tvdbId?api_key=$apiKey&external_source=tvdb_id';
        final response = await apiClient.get(Uri.parse(findUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> results = data['tv_results'] ?? [];
          if (results.isNotEmpty) {
            return results.first;
          }
        }
      } catch (_) {}
    }

    if (imdbId != null && imdbId.isNotEmpty) {
      try {
        final findUrl = '${baseUrl}find/$imdbId?api_key=$apiKey&external_source=imdb_id';
        final response = await apiClient.get(Uri.parse(findUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> results = data['tv_results'] ?? [];
          if (results.isNotEmpty) {
            return results.first;
          }
        }
      } catch (_) {}
    }

    // Fallback to search
    try {
      final searchUrl = '${baseUrl}search/tv?api_key=$apiKey&query=${Uri.encodeComponent(title)}';
      final response = await apiClient.get(Uri.parse(searchUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        if (results.isNotEmpty) {
          return results.first;
        }
      }
    } catch (_) {}

    return null;
  }

  void _startImport() async {
    // Determine if movies or series JSON
    final isSeriesDetected = widget.jsonList.any((item) => item is Map && item.containsKey('seasons'));

    if (mounted) {
      setState(() {
        _isSeries = isSeriesDetected;
      });
    }

    if (isSeriesDetected) {
      // Parse series and flatten episodes
      final List<Map<String, dynamic>> watchedEpisodes = [];
      for (var seriesItem in widget.jsonList) {
        if (seriesItem is Map<String, dynamic>) {
          final seriesTitle = seriesItem['title'] as String? ?? 'Unknown Series';
          final idMap = seriesItem['id'] as Map<String, dynamic>?;
          final tvdbId = idMap?['tvdb'] as int?;
          final imdbId = idMap?['imdb'] as String?;
          final seriesCreatedAtStr = seriesItem['created_at'] as String?;

          final seasons = seriesItem['seasons'] as List<dynamic>?;
          if (seasons != null) {
            for (var season in seasons) {
              if (season is Map<String, dynamic>) {
                final seasonNumber = season['number'] as int? ?? 1;
                final episodes = season['episodes'] as List<dynamic>?;
                if (episodes != null) {
                  for (var episode in episodes) {
                    if (episode is Map<String, dynamic>) {
                      final isWatched = episode['is_watched'];
                      if (isWatched == true || isWatched == 'true') {
                        final episodeNumber = episode['number'] as int? ?? 1;
                        final episodeTitle = episode['name'] as String? ?? 'Episode $episodeNumber';
                        final watchedAtStr = episode['watched_at'] as String?;

                        watchedEpisodes.add({
                          'seriesTitle': seriesTitle,
                          'tvdbId': tvdbId,
                          'imdbId': imdbId,
                          'seasonNumber': seasonNumber,
                          'episodeNumber': episodeNumber,
                          'episodeTitle': episodeTitle,
                          'watchedAt': watchedAtStr,
                          'seriesCreatedAt': seriesCreatedAtStr,
                        });
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      if (watchedEpisodes.isEmpty) {
        if (mounted) {
          setState(() {
            _isFinished = true;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _totalCount = watchedEpisodes.length;
        });
      }

      for (int i = 0; i < watchedEpisodes.length; i++) {
        if (_isCancelled) break;

        final episode = watchedEpisodes[i];
        final seriesTitle = episode['seriesTitle'] as String;
        final tvdbId = episode['tvdbId'] as int?;
        final imdbId = episode['imdbId'] as String?;
        final seasonNumber = episode['seasonNumber'] as int;
        final episodeNumber = episode['episodeNumber'] as int;
        final episodeTitle = episode['episodeTitle'] as String;
        final watchedAtStr = episode['watchedAt'] as String?;
        final seriesCreatedAtStr = episode['seriesCreatedAt'] as String?;

        if (mounted) {
          setState(() {
            _currentName = '$seriesTitle S${seasonNumber}E$episodeNumber';
          });
        }

        final date = (watchedAtStr != null && watchedAtStr.isNotEmpty)
            ? (DateTime.tryParse(watchedAtStr) ?? DateTime.now())
            : (seriesCreatedAtStr != null && seriesCreatedAtStr.isNotEmpty
                ? (DateTime.tryParse(seriesCreatedAtStr) ?? DateTime.now())
                : DateTime.now());

        try {
          final cacheKey = tvdbId != null ? 'tvdb_$tvdbId' : (imdbId != null ? 'imdb_$imdbId' : 'title_$seriesTitle');
          Map<String, dynamic>? tmdbData;

          if (_tmdbCache.containsKey(cacheKey)) {
            tmdbData = _tmdbCache[cacheKey];
          } else {
            tmdbData = await _findTvTmdb(
              title: seriesTitle,
              tvdbId: tvdbId,
              imdbId: imdbId,
              baseUrl: widget.baseUrl,
              apiKey: widget.apiKey ?? '',
            );
            _tmdbCache[cacheKey] = tmdbData;
          }

          if (tmdbData != null) {
            final tmdbId = tmdbData['id'] as int;
            final resolvedTitle = tmdbData['name'] as String? ?? seriesTitle;
            final posterPath = tmdbData['poster_path'] as String?;

            await _db.addShowToHistory(
              tmdbId: tmdbId,
              title: resolvedTitle,
              posterPath: posterPath,
              watchedAt: date,
              seasonNumber: seasonNumber,
              episodeNumber: episodeNumber,
              episodeTitle: episodeTitle,
            );
            _successCount++;
          } else {
            _failedCount++;
          }
        } catch (e) {
          _failedCount++;
        }

        if (mounted) {
          setState(() {
            _processedCount++;
          });
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }
    } else {
      // Parse movies
      final List<Map<String, dynamic>> watchedMovies = [];
      for (var item in widget.jsonList) {
        if (item is Map<String, dynamic>) {
          final isWatched = item['is_watched'];
          if (isWatched == true || isWatched == 'true') {
            watchedMovies.add(item);
          }
        }
      }

      if (watchedMovies.isEmpty) {
        if (mounted) {
          setState(() {
            _isFinished = true;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _totalCount = watchedMovies.length;
        });
      }

      for (int i = 0; i < watchedMovies.length; i++) {
        if (_isCancelled) break;

        final movie = watchedMovies[i];
        final title = movie['title'] as String? ?? 'Unknown Movie';
        final idMap = movie['id'] as Map<String, dynamic>?;
        final tvdbId = idMap?['tvdb'] as int?;
        final imdbId = idMap?['imdb'] as String?;
        final year = movie['year'] as int?;
        final watchedAtStr = movie['watched_at'] as String?;
        final createdAtStr = movie['created_at'] as String?;

        if (mounted) {
          setState(() {
            _currentName = title;
          });
        }

        final date = (watchedAtStr != null && watchedAtStr.isNotEmpty)
            ? (DateTime.tryParse(watchedAtStr) ?? DateTime.now())
            : (createdAtStr != null && createdAtStr.isNotEmpty
                ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
                : DateTime.now());

        try {
          final cacheKey = imdbId != null ? 'imdb_$imdbId' : (tvdbId != null ? 'tvdb_$tvdbId' : 'title_$title');
          Map<String, dynamic>? tmdbData;

          if (_tmdbCache.containsKey(cacheKey)) {
            tmdbData = _tmdbCache[cacheKey];
          } else {
            tmdbData = await _findMovieTmdb(
              title: title,
              tvdbId: tvdbId,
              imdbId: imdbId,
              year: year,
              baseUrl: widget.baseUrl,
              apiKey: widget.apiKey ?? '',
            );
            _tmdbCache[cacheKey] = tmdbData;
          }

          if (tmdbData != null) {
            final tmdbId = tmdbData['id'] as int;
            final resolvedTitle = tmdbData['title'] as String? ?? title;
            final posterPath = tmdbData['poster_path'] as String?;

            await _db.addMovieToHistory(
              tmdbId: tmdbId,
              title: resolvedTitle,
              posterPath: posterPath,
              watchedAt: date,
            );
            _successCount++;
          } else {
            _failedCount++;
          }
        } catch (e) {
          _failedCount++;
        }

        if (mounted) {
          setState(() {
            _processedCount++;
          });
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (mounted) {
      setState(() {
        _isFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalCount > 0 ? _processedCount / _totalCount : 0.0;

    return PopScope(
      canPop: _isFinished || _isCancelled,
      child: AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          _isFinished
              ? 'Import Completed'
              : _isCancelled
                  ? 'Import Cancelled'
                  : (_isSeries ? 'Importing TV Time series...' : 'Importing TV Time movies...'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isFinished && !_isCancelled) ...[
              Text(
                'Processing: $_currentName',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Total processed: $_processedCount / $_totalCount',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Successful: $_successCount',
              style: const TextStyle(color: Colors.green),
            ),
            Text(
              'Failed / Unmatched: $_failedCount',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          if (!_isFinished && !_isCancelled)
            TextButton(
              onPressed: () {
                setState(() {
                  _isCancelled = true;
                });
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          if (_isFinished || _isCancelled)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(_successCount);
              },
              child: Text(
                'Close',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}
