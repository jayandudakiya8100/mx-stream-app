import 'dart:convert';

import 'package:mxstream/functions/show_error_dialog.dart';
import 'package:mxstream/widgets/settings_screen.dart';
import 'package:mxstream/widgets/expressive_page_route.dart';
import 'package:flutter/material.dart';
import 'package:mxstream/widgets/bottom_bar.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tmdb_api/tmdb_api.dart';
import 'package:mxstream/services/api_client.dart';

import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final TMDB tmdb;
  final apiKey = dotenv.env['TMDB_API_KEY'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['TMDB_API_KEY'];
    tmdb = TMDB(ApiKeys(apiKey!, ""));
  }

  Future<void> _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    setState(() {
      _isLoading = true;
    });

    try {
      var requestToken =
          await tmdb.v3.auth.createSessionWithLogin(email, password) as String?;
      if (requestToken != null) {
        // Step 4: Create session
        var sessionData = await tmdb.v3.auth.createSession(requestToken);

        if (sessionData != null) {
          var accountData = await apiClient.get(Uri.parse(
              'https://api.themoviedb.org/3/account?api_key=$apiKey&session_id=$sessionData'));
          if (accountData.statusCode == 200) {
            final String accountId =
                json.decode(accountData.body)['id'].toString();
            _toProfile(sessionData, accountId);
          } else {
            showErrorDialog('Error',
                'Failed to get account Id. Please try again.', context);
          }
        } else {
          showErrorDialog('Error',
              'Failed to create session. Please try again later.', context);
        }
      } else {
        // Authentication failed
        showErrorDialog('Error',
            'Failed to login. Please check your credentials.', context);
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        showErrorDialog('Error',
            'Invalid username or password. Please try again.', context);
      } else {
        showErrorDialog('Error',
            'An unexpected error occurred. Please try again later.', context);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(Uri url) async {
    if (await canLaunchUrlString(url.toString())) {
      await launchUrlString(url.toString());
    } else {
      throw Exception('Could not launch url');
    }
  }

  Future<void> _signup() async {
    final url = Uri.parse('https://www.themoviedb.org/signup');

    try {
      await _launchUrl(url);
    } catch (e) {
      showErrorDialog('Error', 'Failed to launch URL', context);
    }
  }

  Future<void> _forgotpassword() async {
    final url = Uri.parse('https://www.themoviedb.org/reset-password');

    try {
      await _launchUrl(url);
    } catch (e) {
      showErrorDialog('Error', 'Failed to launch URL', context);
    }
  }

  void _toProfile(String sessionData, String accountId) async {
    final box = Hive.box('sessionBox');
    await box.put('sessionData', sessionData);
    await box.put('accountId', accountId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Account Login',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                ExpressivePageRoute(page: const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: TvFocusModeManager.isTvDevice ? 24.0 : BottomBar.getHeight(context) + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.movie_filter_rounded,
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TMDB Authentication',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log in with your TMDB account to sync watchlists, ratings, and favorites across device instances.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              autocorrect: false,
              style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
              cursorColor: colorScheme.primary,
              controller: _emailController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Username or Email',
                prefixIcon: Icon(Icons.person_outline_rounded, color: colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              obscureText: true,
              autocorrect: false,
              style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
              cursorColor: colorScheme.primary,
              controller: _passwordController,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded, color: colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              ),
            ),
            const SizedBox(height: 12.0),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotpassword,
                child: Text(
                  'Forgot password?',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _isLoading ? null : _login,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        'Sign In',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 36),
            Row(
              children: [
                Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Don't have an account?",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: _signup,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  'Create TMDB Account',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

