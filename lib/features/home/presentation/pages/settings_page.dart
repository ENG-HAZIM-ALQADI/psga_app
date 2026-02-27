import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/locale/locale_cubit.dart';
import 'package:psga_app/core/theme/theme_cubit.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/features/maps/presentation/pages/maps_settings_page.dart';

/// صفحة الإعدادات
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            // بعد تسجيل الخروج، العودة لصفحة Login
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          } else if (state is AuthError) {
            // في حالة خطأ، عرض رسالة وإبقاء المستخدم في الصفحة
            context.showErrorSnackBar(state.message);
          }
        },
        builder: (context, state) {
          // إذا كانت الحالة Loading، عرض مؤشر التحميل فوق المحتوى
          if (state is AuthLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.loggingOut),
                ],
              ),
            );
          }
          
          if (state is! Authenticated) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = state.user;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // بطاقة الملف الشخصي
                _buildProfileCard(context, user.name, user.email, user.photoUrl),

                const Divider(height: 1),

                // قسم الحساب
                _buildSectionTitle(context, AppLocalizations.of(context)!.account),
                _buildSettingTile(
                  context,
                  icon: Icons.person_outline,
                  title: AppLocalizations.of(context)!.profileTitle,
                  subtitle: AppLocalizations.of(context)!.profileSubtitle,
                  onTap: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                // زر ديناميكي: إضافة أو تغيير كلمة المرور
                _buildSettingTile(
                  context,
                  icon: Icons.lock_outline,
                  title: user.hasPassword ? AppLocalizations.of(context)!.changePassword : AppLocalizations.of(context)!.addPassword,
                  subtitle: user.hasPassword 
                      ? AppLocalizations.of(context)!.changePasswordSubtitle2 
                      : AppLocalizations.of(context)!.addPasswordSubtitle2,
                  onTap: () {
                    Navigator.pushNamed(context, '/change-password');
                  },
                ),

                const Divider(height: 1),

                // قسم التنبيهات
                _buildSectionTitle(context, AppLocalizations.of(context)!.alertsSection),
                _buildSettingTile(
                  context,
                  icon: Icons.notifications_outlined,
                  title: AppLocalizations.of(context)!.alertSettings,
                  subtitle: AppLocalizations.of(context)!.alertSettingsSubtitle2,
                  onTap: () {
                    Navigator.pushNamed(context, '/alert-settings');
                  },
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.contacts_outlined,
                  title: AppLocalizations.of(context)!.contacts,
                  subtitle: AppLocalizations.of(context)!.contactsSubtitle2,
                  onTap: () {
                    Navigator.pushNamed(context, '/contacts');
                  },
                ),

                const Divider(height: 1),

                // قسم التطبيق
                _buildSectionTitle(context, AppLocalizations.of(context)!.appSection),
                _buildSettingTile(
                  context,
                  icon: Icons.route_outlined,
                  title: AppLocalizations.of(context)!.tripSettingsTitle,
                  subtitle: AppLocalizations.of(context)!.tripSettingsSubtitle2,
                  onTap: () {
                    Navigator.pushNamed(context, '/trip-settings');
                  },
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.map_outlined,
                  title: AppLocalizations.of(context)!.mapSettings,
                  subtitle: AppLocalizations.of(context)!.mapsSettingsSubtitle,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapsSettingsPage(),
                      ),
                    );
                  },
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.language,
                  title: AppLocalizations.of(context)!.language,
                  subtitle: context.watch<LocaleCubit>().isArabic ? AppLocalizations.of(context)!.arabicLanguage : AppLocalizations.of(context)!.englishLanguage,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showLanguageDialog(context);
                  },
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.dark_mode_outlined,
                  title: AppLocalizations.of(context)!.theme,
                  subtitle: _getThemeLabel(context),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showThemeDialog(context);
                  },
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.info_outline,
                  title: AppLocalizations.of(context)!.aboutApp,
                  subtitle: AppLocalizations.of(context)!.aboutAppVersion,
                  onTap: () {
                    _showAboutDialog(context);
                  },
                ),

                const Divider(height: 1),

                // قسم الخصوصية
                _buildSectionTitle(context, AppLocalizations.of(context)!.privacySecurity),
                _buildSettingTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: AppLocalizations.of(context)!.privacyPolicy,
                  onTap: () {
                    context.showInfoSnackBar(AppLocalizations.of(context)!.privacyPolicy);
                  },
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.description_outlined,
                  title: AppLocalizations.of(context)!.termsOfUse,
                  onTap: () {
                    context.showInfoSnackBar(AppLocalizations.of(context)!.termsOfUse);
                  },
                ),

                const Divider(height: 1),

                // تسجيل الخروج
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMD),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showLogoutDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.logout),
                      label: Text(
                        AppLocalizations.of(context)!.logout,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),

                // حذف الحساب
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showDeleteAccountDialog(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: Text(
                        AppLocalizations.of(context)!.deleteAccountPermanent2,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacingXL),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    String name,
    String email,
    String? photoUrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLG),
      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Theme.of(context).colorScheme.primary,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 32,
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        AppDimensions.paddingLG,
        AppDimensions.paddingMD,
        AppDimensions.paddingSM,
      ),
      child: Builder(
        builder: (context) => Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Widget? trailing,
  }) {
    return Builder(
      builder: (context) => ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              )
            : null,
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  /// عرض dialog لاختيار اللغة
  void _showLanguageDialog(BuildContext context) {
    final localeCubit = context.read<LocaleCubit>();
    final isArabic = localeCubit.isArabic;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.language, size: 24),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.chooseLanguage),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              context: context,
              flagEmoji: '🇸🇦',
              languageName: 'العربية',
              nativeName: 'Arabic',
              languageCode: 'ar',
              isSelected: isArabic,
              onTap: () {
                Navigator.pop(dialogContext);
                localeCubit.setLocale(const Locale('ar'));
              },
            ),
            const SizedBox(height: 8),
            _buildLanguageOption(
              context: context,
              flagEmoji: '🇺🇸',
              languageName: 'English',
              nativeName: 'الإنجليزية',
              languageCode: 'en',
              isSelected: !isArabic,
              onTap: () {
                Navigator.pop(dialogContext);
                localeCubit.setLocale(const Locale('en'));
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  /// بناء خيار لغة واحد
  Widget _buildLanguageOption({
    required BuildContext context,
    required String flagEmoji,
    required String languageName,
    required String nativeName,
    required String languageCode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Text(flagEmoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nativeName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.logout),
        content: Text(AppLocalizations.of(context)!.logoutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              BlocProvider.of<AuthBloc>(context).add(const LogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.logout),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.deleteAccountPermanent2,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.deleteAccountWarning2,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.deleteAccountItems2),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.deleteAccountItem1),
            Text(AppLocalizations.of(context)!.deleteAccountItem2),
            Text(AppLocalizations.of(context)!.deleteAccountItem3),
            Text(AppLocalizations.of(context)!.deleteAccountItem4),
            Text(AppLocalizations.of(context)!.deleteAccountItem5),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.deleteAccountConfirm,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              BlocProvider.of<AuthBloc>(context).add(const DeleteAccountRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.confirmDeleteAccount),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'PSGA',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        child: Icon(
          Icons.shield,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 32,
        ),
      ),
      children: [
        Text(AppLocalizations.of(context)!.appDescription),
        const SizedBox(height: 8),
        Text(AppLocalizations.of(context)!.appDescription),
      ],
    );
  }

  /// الحصول على اسم الثيم الحالي
  String _getThemeLabel(BuildContext context) {
    final themeState = context.watch<ThemeCubit>().state;
    switch (themeState) {
      case ThemeState.light:
        return AppLocalizations.of(context)!.themeLight;
      case ThemeState.dark:
        return AppLocalizations.of(context)!.themeDark;
      case ThemeState.system:
        return AppLocalizations.of(context)!.themeSystem;
    }
  }

  /// عرض dialog لاختيار الثيم
  void _showThemeDialog(BuildContext context) {
    final currentTheme = context.read<ThemeCubit>().state;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.palette_outlined, size: 24),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.chooseTheme),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context: context,
              icon: Icons.light_mode_outlined,
              title: AppLocalizations.of(context)!.themeLight,
              subtitle: AppLocalizations.of(context)!.themeLightSubtitle,
              themeState: ThemeState.light,
              isSelected: currentTheme == ThemeState.light,
              onTap: () {
                context.read<ThemeCubit>().setTheme(ThemeState.light);
                Navigator.pop(dialogContext);
                context.showSuccessSnackBar(AppLocalizations.of(context)!.themeChangedLight);
              },
            ),
            const SizedBox(height: 8),
            _buildThemeOption(
              context: context,
              icon: Icons.dark_mode_outlined,
              title: AppLocalizations.of(context)!.themeDark,
              subtitle: AppLocalizations.of(context)!.themeDarkSubtitle,
              themeState: ThemeState.dark,
              isSelected: currentTheme == ThemeState.dark,
              onTap: () {
                context.read<ThemeCubit>().setTheme(ThemeState.dark);
                Navigator.pop(dialogContext);
                context.showSuccessSnackBar(AppLocalizations.of(context)!.themeChangedDark);
              },
            ),
            const SizedBox(height: 8),
            _buildThemeOption(
              context: context,
              icon: Icons.brightness_auto_outlined,
              title: AppLocalizations.of(context)!.themeSystem,
              subtitle: AppLocalizations.of(context)!.themeSystemSubtitle,
              themeState: ThemeState.system,
              isSelected: currentTheme == ThemeState.system,
              onTap: () {
                context.read<ThemeCubit>().setTheme(ThemeState.system);
                Navigator.pop(dialogContext);
                context.showSuccessSnackBar(AppLocalizations.of(context)!.themeChangedSystem);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  /// بناء خيار ثيم واحد
  Widget _buildThemeOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeState themeState,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          color: isSelected 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1) 
            : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyMedium?.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
