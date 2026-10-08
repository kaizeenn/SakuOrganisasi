import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/theme_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/ui_kit.dart';
import 'auth_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;
  final TextEditingController _orgNameController = TextEditingController();
  String _selectedCurrency = 'IDR';
  bool _isProfileLoading = true;
  String _appVersion = '...';
  bool _biometricEnabled = false;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final user = await AuthService.currentUser();

    if (mounted) {
      setState(() {
        _orgNameController.text =
            prefs.getString('org_name') ?? AppConstants.defaultOrgName;
        _selectedCurrency = prefs.getString('currency') ?? 'IDR';
        _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
        _appVersion = packageInfo.version;
        _user = user;
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _saveProfileSettings() async {
    if (_orgNameController.text.isEmpty) {
      _snack('Nama organisasi tidak boleh kosong');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('org_name', _orgNameController.text);
      await prefs.setString('currency', _selectedCurrency);
      if (mounted) _snack('Pengaturan tersimpan');
    } catch (e) {
      if (mounted) _snack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: _isProfileLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // Profile header
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: p.heroGradient),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_user?['name'] ?? _orgNameController.text)
                                  .toString(),
                              style: context.texts.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '@${_user?['username'] ?? '-'}',
                              style: context.texts.bodySmall?.copyWith(
                                color: p.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppBadge(
                        text: 'Aktif',
                        color: p.income,
                        icon: Icons.verified_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Profil Organisasi'),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _orgNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Organisasi',
                          prefixIcon: Icon(Icons.business_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCurrency,
                        decoration: const InputDecoration(
                          labelText: 'Mata Uang',
                          prefixIcon: Icon(Icons.payments_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'IDR',
                            child: Text('IDR (Rupiah)'),
                          ),
                          DropdownMenuItem(
                            value: 'USD',
                            child: Text('USD (Dollar)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCurrency = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _saveProfileSettings,
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Simpan Profil'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Tampilan'),
                _SettingTile(
                  icon: Icons.brightness_6_rounded,
                  color: p.brand,
                  title: 'Tema Aplikasi',
                  subtitle: _getThemeName(themeMode),
                  onTap: _showThemeDialog,
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Keamanan'),
                _SettingTile(
                  icon: Icons.fingerprint_rounded,
                  color: p.accent,
                  title: 'Keamanan Biometrik',
                  subtitle: 'Gunakan sidik jari/wajah untuk masuk',
                  trailing: Switch(
                    value: _biometricEnabled,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('biometric_enabled', val);
                      if (!mounted) return;
                      setState(() => _biometricEnabled = val);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _SettingTile(
                  icon: Icons.logout_rounded,
                  color: p.expense,
                  title: 'Keluar Akun',
                  subtitle: 'Akhiri sesi login saat ini',
                  onTap: _logout,
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Tentang'),
                _SettingTile(
                  icon: Icons.info_rounded,
                  color: p.transfer,
                  title: 'Versi Aplikasi',
                  subtitle: 'Saku Organisasi v$_appVersion',
                ),
              ].animate().fade(duration: 380.ms).slideY(
                begin: 0.03,
                end: 0,
                duration: 380.ms,
              ),
            ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Akun?'),
        content: const Text('Anda perlu login kembali untuk mengakses data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.expense,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Ikuti Sistem';
      case ThemeMode.light:
        return 'Mode Terang';
      case ThemeMode.dark:
        return 'Mode Gelap';
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pilih Tema'),
        children: [
          _themeOption(ThemeMode.system, 'Ikuti Sistem', Icons.brightness_auto_rounded),
          _themeOption(ThemeMode.light, 'Mode Terang', Icons.light_mode_rounded),
          _themeOption(ThemeMode.dark, 'Mode Gelap', Icons.dark_mode_rounded),
        ],
      ),
    );
  }

  Widget _themeOption(ThemeMode mode, String label, IconData icon) {
    final selected = ref.watch(themeProvider) == mode;
    return SimpleDialogOption(
      onPressed: () {
        ref.read(themeProvider.notifier).setTheme(mode);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(label, style: context.texts.bodyLarge),
            const Spacer(),
            if (selected)
              Icon(Icons.check_rounded, color: context.palette.brand, size: 20),
          ],
        ),
      ),
    );
  }

}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.texts.bodySmall?.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          trailing ??
              Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 20),
        ],
      ),
    );
  }
}