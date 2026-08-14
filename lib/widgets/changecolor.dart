import 'package:Mirarr/functions/themeprovider_class.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    final themesList = [
      {'name': 'Orange Theme', 'color': const Color(0xFFFF9800), 'theme': AppThemes.orangeTheme},
      {'name': 'Blue Theme', 'color': const Color(0xFF2196F3), 'theme': AppThemes.blueTheme},
      {'name': 'Red Theme', 'color': const Color(0xFFF44336), 'theme': AppThemes.redTheme},
      {'name': 'Green Theme', 'color': const Color(0xFF4CAF50), 'theme': AppThemes.greenTheme},
      {'name': 'Yellow Theme', 'color': const Color(0xFFFFEB3B), 'theme': AppThemes.yellowTheme},
      {'name': 'Grey Theme', 'color': const Color(0xFF9E9E9E), 'theme': AppThemes.greyTheme},
      {'name': 'Brown Theme', 'color': const Color(0xFF795548), 'theme': AppThemes.brownTheme},
      {'name': 'Mono Theme', 'color': const Color(0xFF607D8B), 'theme': AppThemes.monoFontTheme},
      {'name': 'Nothing Theme', 'color': const Color(0xFFD32F2F), 'theme': AppThemes.nothingFontTheme},
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Appearance',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Color Themes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          ...themesList.map((item) {
            final targetTheme = item['theme'] as ThemeData;
            final isSelected = themeProvider.currentTheme == targetTheme;
            final itemColor = item['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.2),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: itemColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: itemColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                title: Text(
                  item['name'] as String,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                    : null,
                onTap: () {
                  themeProvider.setTheme(targetTheme);
                },
              ),
            );
          }).toList(),
          if (themeProvider.isOmarchyLinux) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                leading: Icon(Icons.terminal_rounded, color: colorScheme.primary),
                title: Text(
                  'Omarchy Linux System Theme',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                onTap: () {
                  themeProvider.setOmarchyTheme();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

