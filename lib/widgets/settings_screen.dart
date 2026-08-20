import 'package:mxstream/functions/navigation_provider.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:mxstream/functions/themeprovider_class.dart';


import 'package:mxstream/functions/platform_helper.dart';
import 'package:mxstream/widgets/custom_divider.dart';
import 'package:mxstream/widgets/m3_expressive_spinner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';


import 'package:mxstream/functions/get_base_url.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mxstream/services/api_client.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:mxstream/functions/file_saver.dart' as fs;
import 'package:mxstream/widgets/extensions_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
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

}
