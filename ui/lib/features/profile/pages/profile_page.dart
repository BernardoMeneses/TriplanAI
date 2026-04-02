import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../common/app_colors.dart';
import '../../../common/constants/app_constants.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/google_drive_backup_service.dart';
import '../../../services/api_service.dart';
import '../../../services/subscription_service.dart';
import '../../../shared/widgets/language_selector_dialog.dart';
import '../../../shared/widgets/upgrade_dialog.dart';
import '../../premium/subscription_plans_page.dart';
import '../../../shared/widgets/snackbar_helper.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onLogout;

  const ProfilePage({super.key, this.onLogout});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _notificationsEnabled = true;
  bool _isLoadingNotifications = true;
  bool _isBackingUp = false;
  bool _isSigningInDrive = false;
  bool _canManualBackup = false;
  bool _canCloudBackup = false;
  bool _isAutoBackupPlan = false;
  bool _isDriveSignedIn = false;
  final GoogleDriveBackupService _backupService = GoogleDriveBackupService();

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final status = await SubscriptionService().getStatus(forceRefresh: true);
    final isDriveSignedIn = await _backupService.isSignedIn();

    if (mounted) {
      setState(() {
        _canCloudBackup = status.limits.canBackupCloud;
        _isAutoBackupPlan = status.limits.canAutoBackup;
        _canManualBackup =
            status.limits.canBackupCloud && !status.limits.canAutoBackup;
        _isDriveSignedIn = isDriveSignedIn;
      });
    }
  }

  Future<void> _loadNotificationSettings() async {
    final enabled = await NotificationService().areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = enabled;
      _isLoadingNotifications = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });

    await NotificationService().setNotificationsEnabled(value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                value ? Icons.notifications_active : Icons.notifications_off,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value
                      ? AppConstants.notificationsEnabled.tr()
                      : AppConstants.notificationsDisabled.tr(),
                ),
              ),
            ],
          ),
          backgroundColor: value ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.profile.tr()),
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Header com info do utilizador
          Container(
            padding: const EdgeInsets.all(24),
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: isDark
                          ? AppColors.grey800
                          : AppColors.grey200,
                      backgroundImage: user?.profilePictureUrl != null
                          ? NetworkImage(user!.profilePictureUrl!)
                          : null,
                      child: user?.profilePictureUrl == null
                          ? Text(
                              user?.fullName.substring(0, 1).toUpperCase() ??
                                  'U',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          _showImageSourceDialog(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : AppColors.surfaceLight,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user?.fullName ?? 'Utilizador',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user?.username ?? ''}',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Premium Section
          _buildSection(
            context,
            title: AppConstants.premium.tr(),
            items: [
              _buildListTile(
                context,
                icon: Icons.workspace_premium,
                title: AppConstants.activatePremium.tr(),
                subtitle: AppConstants.activatePremiumSubtitle.tr(),
                iconColor: Colors.amber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubscriptionPlansPage(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Backup Section
          if (_canCloudBackup) ...[
            _buildSection(
              context,
              title: 'backup.title'.tr(),
              items: [
                _buildGoogleDriveSignInTile(context),
                if (_canManualBackup) _buildBackupTile(context),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Definições da App
          _buildSection(
            context,
            title: AppConstants.settings.tr(),
            items: [
              _buildSwitchTile(
                context,
                icon: Icons.notifications_outlined,
                title: AppConstants.notifications.tr(),
                subtitle: AppConstants.notificationsSubtitle.tr(),
                value: _notificationsEnabled,
                isLoading: _isLoadingNotifications,
                onChanged: _toggleNotifications,
              ),
              _buildListTile(
                context,
                icon: Icons.language_outlined,
                title: AppConstants.language.tr(),
                subtitle: _getLanguageName(context),
                onTap: () {
                  LanguageSelectorDialog.show(context);
                },
              ),
              _buildListTile(
                context,
                icon: Icons.lock_outline,
                title: AppConstants.privacy.tr(),
                subtitle: AppConstants.privacySubtitle.tr(),
                onTap: () async {
                  final uri = Uri.parse(AppConstants.privacyPolicyUrl);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Ajuda e Suporte
          _buildSection(
            context,
            title: AppConstants.helpSupport.tr(),
            items: [
              _buildListTile(
                context,
                icon: Icons.help_outline,
                title: AppConstants.faqs.tr(),
                subtitle: AppConstants.faqsSubtitle.tr(),
                onTap: () {
                  _showFAQsDialog(context);
                },
              ),
              _buildListTile(
                context,
                icon: Icons.info_outline,
                title: AppConstants.about.tr(),
                subtitle: AppConstants.version.tr(
                  namedArgs: {'version': AppConstants.appVersion},
                ),
                onTap: () {
                  _showAboutDialog(context);
                },
              ),
              _buildListTile(
                context,
                icon: Icons.contact_support_outlined,
                title: AppConstants.contactSupport.tr(),
                subtitle: AppConstants.contactSupportSubtitle.tr(),
                onTap: () async {
                  final uri = Uri(
                    scheme: 'mailto',
                    path: 'webmaster@eupasoft.com',
                  );
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              // Botão de teste de notificação (apenas em debug)
              if (kDebugMode)
                _buildListTile(
                  context,
                  icon: Icons.notifications_active,
                  title: 'Testar Notificação',
                  subtitle: 'Enviar notificação de teste',
                  iconColor: Colors.orange,
                  onTap: () async {
                    await NotificationService().showTestNotification();
                    if (mounted) {
                      SnackBarHelper.showSuccess(
                        context,
                        AppConstants.testNotificationSent.tr(),
                      );
                    }
                  },
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Terminar Sessão
          _buildSection(
            context,
            title: AppConstants.account.tr(),
            items: [
              _buildListTile(
                context,
                icon: Icons.logout,
                title: AppConstants.logout.tr(),
                subtitle: AppConstants.logoutSubtitle.tr(),
                iconColor: AppColors.error,
                onTap: () {
                  _showLogoutDialog(context);
                },
              ),
              _buildListTile(
                context,
                icon: Icons.delete_forever,
                title: AppConstants.deleteAccount.tr(),
                subtitle: AppConstants.deleteAccountSubtitle.tr(),
                iconColor: AppColors.error,
                onTap: () {
                  _showDeleteAccountDialog(context);
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required bool isLoading,
    required Function(bool) onChanged,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            )
          : null,
      trailing: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
            ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> items,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        Container(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
      onTap: onTap,
    );
  }

  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(AppConstants.chooseFromGallery.tr()),
              onTap: () {
                Navigator.pop(context);
                SnackBarHelper.showInfo(
                  context,
                  AppConstants.inDevelopment.tr(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(AppConstants.takePhoto.tr()),
              onTap: () {
                Navigator.pop(context);
                SnackBarHelper.showInfo(
                  context,
                  AppConstants.inDevelopment.tr(),
                );
              },
            ),
            if (AuthService().currentUser?.profilePictureUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: Text(
                  AppConstants.removePhoto.tr(),
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  SnackBarHelper.showInfo(
                    context,
                    AppConstants.inDevelopment.tr(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(Icons.cloud_upload_outlined, color: Colors.blue),
      title: Text(
        'backup.google_drive'.tr(),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      subtitle: Text(
        'backup.google_drive_desc'.tr(),
        style: TextStyle(
          fontSize: 14,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
      trailing: _isBackingUp
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
      onTap: _isBackingUp ? null : () => _performBackup(context),
    );
  }

  Widget _buildGoogleDriveSignInTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(Icons.login, color: Colors.blue),
      title: Text(
        '${'auth.sign_in'.tr()} Google Drive',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      subtitle: Text(
        _isAutoBackupPlan
            ? '${'subscription.auto_backup'.tr()} • ${'backup.google_drive_desc'.tr()}'
            : 'backup.google_drive_desc'.tr(),
        style: TextStyle(
          fontSize: 14,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
      trailing: _isSigningInDrive
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _isDriveSignedIn ? Icons.check_circle : Icons.chevron_right,
              color: _isDriveSignedIn
                  ? Colors.green
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
      onTap: _isSigningInDrive ? null : () => _signInGoogleDrive(context),
    );
  }

  Future<void> _signInGoogleDrive(BuildContext context) async {
    setState(() => _isSigningInDrive = true);

    try {
      var signedIn = await _backupService.signIn();
      if (!signedIn) {
        // Retry forcing account chooser when first attempt silently fails.
        signedIn = await _backupService.signIn(forceAccountSelection: true);
      }

      if (!mounted) return;

      setState(() {
        _isDriveSignedIn = signedIn;
      });

      if (!signedIn) {
        SnackBarHelper.showError(context, 'backup.sign_in_failed'.tr());
      }
    } catch (_) {
      if (mounted) {
        SnackBarHelper.showError(context, 'backup.sign_in_failed'.tr());
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningInDrive = false);
      }
    }
  }

  Future<void> _performBackup(BuildContext context) async {
    // Check cloud backup permission
    final subStatus = await SubscriptionService().getStatus();
    if (!subStatus.limits.canBackupCloud) {
      if (mounted) {
        showUpgradeDialog(
          context: context,
          feature: AppConstants.backupLockedTitle.tr(),
          description: AppConstants.backupLockedDesc.tr(),
        );
      }
      return;
    }

    setState(() => _isBackingUp = true);

    try {
      if (!_isDriveSignedIn) {
        if (mounted) {
          SnackBarHelper.showWarning(
            context,
            '${'auth.sign_in'.tr()} Google Drive',
          );
        }
        return;
      }

      // Fazer backup de todas as viagens
      final backupCount = await _backupService.backupAllTrips();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  backupCount > 0 ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    backupCount > 0
                        ? 'backup.success'.tr()
                        : 'backup.no_trips'.tr(),
                  ),
                ),
              ],
            ),
            backgroundColor: backupCount > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'backup.error'.tr(args: [e.toString()]),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  String _getLanguageName(BuildContext context) {
    final locale = context.locale;
    switch (locale.languageCode) {
      case 'pt':
        return AppConstants.portuguese.tr();
      case 'en':
        return AppConstants.english.tr();
      case 'es':
        return AppConstants.spanish.tr();
      case 'fr':
        return AppConstants.french.tr();
      case 'de':
        return AppConstants.german.tr();
      case 'it':
        return AppConstants.italian.tr();
      case 'ja':
        return AppConstants.japanese.tr();
      case 'zh':
        return AppConstants.chinese.tr();
      case 'ko':
        return AppConstants.korean.tr();
      default:
        return AppConstants.portuguese.tr();
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppConstants.logout.tr()),
        content: Text(AppConstants.logoutConfirm.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppConstants.cancel.tr()),
          ),
          TextButton(
            onPressed: () async {
              final authService = AuthService();
              await authService.logout();
              if (context.mounted) {
                // Fechar dialog
                Navigator.pop(context);
                // Fechar ProfilePage
                Navigator.pop(context);
                // Callback para atualizar estado no main
                widget.onLogout?.call();
              }
            },
            child: Text(
              AppConstants.exit.tr(),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final authService = AuthService();
    final userEmail = authService.currentUser?.email;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppConstants.deleteAccount.tr()),
        content: Text(AppConstants.deleteAccountMessage.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppConstants.cancel.tr()),
          ),
          TextButton(
            onPressed: userEmail == null
                ? null
                : () async {
                    // Request deletion by email (sends confirmation link)
                    try {
                      await ApiService().post(
                        '/auth/delete-request',
                        body: {'email': userEmail},
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        SnackBarHelper.showSuccess(
                          this.context,
                          AppConstants.deleteRequestSent.tr(),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        SnackBarHelper.showError(
                          this.context,
                          '${AppConstants.errorGeneric.tr()}: $e',
                        );
                      }
                    }
                  },
            child: Text(
              AppConstants.requestDelete.tr(),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showFAQsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppConstants.faqs.tr()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(10, (i) {
              final n = i + 1;
              return Padding(
                padding: EdgeInsets.only(bottom: i < 9 ? 16.0 : 0),
                child: _buildFAQItem(
                  'profile.faq_question_$n'.tr(),
                  'profile.faq_answer_$n'.tr(),
                ),
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppConstants.close.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(answer, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppConstants.aboutTriplanAI.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TriplanAI',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.version.tr(
                namedArgs: {'version': AppConstants.appVersion},
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppConstants.aboutDescription.tr(),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              AppConstants.copyright.tr(),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppConstants.close.tr()),
          ),
        ],
      ),
    );
  }
}
