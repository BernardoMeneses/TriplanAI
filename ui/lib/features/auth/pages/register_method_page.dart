import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:triplan_ai_front/common/constants/app_constants.dart';
import 'package:triplan_ai_front/common/constants/oauth_constants.dart';
import 'package:triplan_ai_front/shared/widgets/snackbar_helper.dart';
import '../../../common/app_colors.dart';
import '../../../services/auth_service.dart';
import 'register_page.dart';
import 'package:easy_localization/easy_localization.dart';

class RegisterMethodPage extends StatefulWidget {
  const RegisterMethodPage({super.key});

  @override
  State<RegisterMethodPage> createState() => _RegisterMethodPageState();
}

class _RegisterMethodPageState extends State<RegisterMethodPage> {
  final _authService = AuthService();
  bool _isLoading = false;

  void _logGoogleAuthError(String flow, String rawError) {
    if (!kDebugMode) return;

    final apiMatch = RegExp(r'ApiException:\s*(\d+)').firstMatch(rawError);
    final platformMatch = RegExp(
      r'PlatformException\(([^,]+),',
    ).firstMatch(rawError);
    final platformCode = platformMatch?.group(1)?.trim().toLowerCase() ?? '';
    final lowerError = rawError.toLowerCase();
    final code =
        apiMatch?.group(1) ?? (platformCode.isNotEmpty ? platformCode : 'n/a');
    final isIosRuntime = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroidRuntime =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    String reason;
    if (lowerError.contains('missing support for the following url schemes')) {
      reason = 'MISSING_IOS_URL_SCHEME (Info.plist CFBundleURLSchemes)';
    } else {
      switch (code) {
        case '10':
          reason = 'DEVELOPER_ERROR (SHA/package/client ID)';
          break;
        case '12500':
          reason = 'SIGN_IN_FAILED (OAuth config)';
          break;
        case '7':
          reason = 'NETWORK_ERROR';
          break;
        case '0':
          reason = 'UNKNOWN (normalmente config OAuth nativa)';
          break;
        case 'sign_in_failed':
          if (isIosRuntime) {
            reason = 'SIGN_IN_FAILED (iOS OAuth client mismatch)';
          } else if (isAndroidRuntime) {
            reason =
                'SIGN_IN_FAILED (Android OAuth config: package/SHA/client IDs)';
          } else {
            reason = 'SIGN_IN_FAILED (OAuth config)';
          }
          break;
        default:
          reason = 'UNMAPPED';
      }
    }

    debugPrint('Google $flow erro: code=$code reason=$reason');
  }

  bool get _showAppleSignIn =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _googleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: OAuthConstants.googleServerClientId,
      );

      // Forçar logout para permitir escolha de conta
      await googleSignIn.signOut();

      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      await _authService.googleLogin(
        googleId: account.id,
        email: account.email,
        name: account.displayName ?? '',
        idToken: auth.idToken ?? '',
        picture: account.photoUrl,
        accessToken: auth.accessToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('auth.account_created_success'.tr()),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Voltar para login após sucesso
        Navigator.of(context).pop();
      }
    } catch (e) {
      String errorMsg = e.toString();
      _logGoogleAuthError('register', errorMsg);

      // Tratar erros específicos de provider diferente
      if (errorMsg.contains('EMAIL_EXISTS_NATIVE') ||
          errorMsg.contains('EMAIL_EXISTS_GOOGLE')) {
        errorMsg = errorMsg.split('|').last;
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  SizedBox(width: 12),
                  Text('auth.account_exists'.tr()),
                ],
              ),
              content: Text(errorMsg),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Fecha dialog
                    Navigator.pop(context); // Volta para login
                  },
                  child: Text(
                    'auth.go_to_login'.tr(),
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        SnackBarHelper.showError(
          context,
          'auth.google_register_error'.tr(
            args: [errorMsg.replaceAll('AuthException: ', '')],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _appleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw Exception(AppConstants.appleSignInUnavailable.tr());
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final displayName = [credential.givenName, credential.familyName]
          .where((part) => part != null && part.trim().isNotEmpty)
          .join(' ')
          .trim();

      await _authService.appleLogin(
        appleId: credential.userIdentifier ?? '',
        identityToken: credential.identityToken ?? '',
        authorizationCode: credential.authorizationCode,
        email: credential.email,
        name: displayName.isEmpty ? null : displayName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('auth.account_created_success'.tr()),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pop();
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code.toString().contains('canceled')) {
        return;
      }
      SnackBarHelper.showError(context, AppConstants.appleAuthFailed.tr());
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          AppConstants.appleRegisterError.tr(
            args: [e.toString().replaceAll('AuthException: ', '')],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Logo / Título
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.flight_takeoff,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'auth.create_account'.tr(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.authChooseMethod.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Botão Google
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _googleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? AppColors.grey100 : AppColors.grey300,
                      ),
                    ),
                    elevation: 0,
                  ),
                  icon: Image.asset(
                    'assets/google_logo.png',
                    height: 24,
                    width: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.g_mobiledata, size: 24);
                    },
                  ),
                  label: Text(
                    AppConstants.signInViaGoogle.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              if (_showAppleSignIn) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _appleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? AppColors.grey100 : AppColors.grey300,
                        ),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.apple, size: 24),
                    label: Text(
                      AppConstants.signInViaApple.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Divider com "or"
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: isDark ? AppColors.grey100 : AppColors.grey300,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      AppConstants.or.tr(),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: isDark ? AppColors.grey100 : AppColors.grey300,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Botão Email/Password
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.email_outlined, color: Colors.white),
                  label: Text(
                    AppConstants.signInViaEmailPassword.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Já tens conta?
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'auth.already_have_account'.tr(),
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'auth.login'.tr(),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
