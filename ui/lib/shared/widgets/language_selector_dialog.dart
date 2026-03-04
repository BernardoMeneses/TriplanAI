import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../common/app_colors.dart';
import '../../common/constants/app_constants.dart';

class LanguageSelectorDialog extends StatelessWidget {
  const LanguageSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLocale = context.locale;

    final languages = [
      {'code': 'pt', 'name': AppConstants.portuguese, 'flag': '🇵🇹'},
      {'code': 'en', 'name': AppConstants.english, 'flag': '🇬🇧'},
      {'code': 'es', 'name': AppConstants.spanish, 'flag': '🇪🇸'},
      {'code': 'fr', 'name': AppConstants.french, 'flag': '🇫🇷'},
      {'code': 'de', 'name': AppConstants.german, 'flag': '🇩🇪'},
      {'code': 'it', 'name': AppConstants.italian, 'flag': '🇮🇹'},
      {'code': 'ja', 'name': AppConstants.japanese, 'flag': '🇯🇵'},
      {'code': 'zh', 'name': AppConstants.chinese, 'flag': '🇨🇳'},
      {'code': 'ko', 'name': AppConstants.korean, 'flag': '🇰🇷'},
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.language,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  AppConstants.language.tr(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: languages.map((lang) {
              final isSelected = currentLocale.languageCode == lang['code'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? AppColors.primary.withOpacity(0.1)
                    : (isDark ? AppColors.grey800 : AppColors.grey100),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
                ),
                child: ListTile(
                  leading: Text(
                    lang['flag']!,
                    style: const TextStyle(fontSize: 32),
                  ),
                  title: Text(
                    (lang['name']! as String).tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                    ),
                  ),
                  trailing: isSelected
                    ? Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                  onTap: () async {
                    await context.setLocale(Locale(lang['code']!));
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text((lang['name']! as String).tr()),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppConstants.close.tr(),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LanguageSelectorDialog(),
    );
  }
}
