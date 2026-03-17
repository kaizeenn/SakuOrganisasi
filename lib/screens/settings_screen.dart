import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/dashboard_providers.dart';
import '../providers/theme_provider.dart';
import '../services/backup_service.dart';
import '../utils/app_constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;

  // Profile State
  final TextEditingController _orgNameController = TextEditingController();
  String _selectedCurrency = 'IDR';
  bool _isProfileLoading = true;
  String _appVersion = 'Loading...';
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    if (mounted) {
      setState(() {
        _orgNameController.text =
            prefs.getString('org_name') ?? AppConstants.defaultOrgName;
        _selectedCurrency = prefs.getString('currency') ?? 'IDR';
        _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
        _appVersion = packageInfo.version;
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _saveProfileSettings() async {
    if (_orgNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama Organisasi tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('org_name', _orgNameController.text);
      await prefs.setString('currency', _selectedCurrency);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pengaturan tersimpan!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: _isProfileLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Profil Organisasi'),
                _buildProfileSection(),
                const SizedBox(height: 20),

                _buildSectionHeader('Tampilan'),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.brightness_6,
                      color: Colors.indigo,
                    ),
                    title: const Text('Tema Aplikasi'),
                    subtitle: Text(_getThemeName(themeMode)),
                    onTap: _showThemeDialog,
                  ),
                ),
                const SizedBox(height: 20),

                _buildSectionHeader('Keamanan'),
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(
                      Icons.fingerprint,
                      color: Colors.purple,
                    ),
                    title: const Text('Keamanan Biometrik'),
                    subtitle: const Text(
                      'Gunakan sidik jari/wajah untuk masuk',
                    ),
                    value: _biometricEnabled,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('biometric_enabled', val);
                      if (!mounted) return;
                      setState(() => _biometricEnabled = val);
                      if (val) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Keamanan Biometrik Diaktifkan'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),

                _buildSectionHeader('Data'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.cloud_upload,
                          color: Colors.blue,
                        ),
                        title: const Text('Backup Data (Terenkripsi)'),
                        subtitle: const Text('Simpan data aman ke file'),
                        onTap: _backupData,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.cloud_download,
                          color: Colors.orange,
                        ),
                        title: const Text('Restore Data'),
                        subtitle: const Text(
                          'Pulihkan dari backup terenkripsi atau file JSON lama',
                        ),
                        onTap: _restoreData,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        title: const Text('Reset Aplikasi'),
                        subtitle: const Text('Hapus semua data permanen'),
                        onTap: _resetApp,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _buildSectionHeader('Tentang'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info, color: Colors.teal),
                    title: const Text('Versi Aplikasi'),
                    subtitle: Text('v$_appVersion'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary, // Dynamic color
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _orgNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Organisasi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Mata Uang',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCurrency,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'IDR', child: Text('IDR (Rupiah)')),
                    DropdownMenuItem(value: 'USD', child: Text('USD (Dollar)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCurrency = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveProfileSettings,
              icon: const Icon(Icons.save),
              label: const Text('Simpan Profil'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
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
      builder: (context) {
        return SimpleDialog(
          title: const Text('Pilih Tema'),
          children: [
            _themeOption(ThemeMode.system, 'Ikuti Sistem'),
            _themeOption(ThemeMode.light, 'Mode Terang'),
            _themeOption(ThemeMode.dark, 'Mode Gelap'),
          ],
        );
      },
    );
  }

  Widget _themeOption(ThemeMode mode, String label) {
    return SimpleDialogOption(
      onPressed: () {
        ref.read(themeProvider.notifier).setTheme(mode);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label),
      ),
    );
  }

  Future<void> _performAction(Future<void> Function() action) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _backupData() async {
    await _performAction(() async {
      final db = ref.read(transactionRepositoryProvider).getDatabase();
      final service = BackupService(db);
      final msg = await service.createBackup();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    });
  }

  Future<void> _restoreData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data?'),
        content: const Text(
          'PERINGATAN: Semua data saat ini akan DIHAPUS dan digantikan dengan data dari backup.\n\nLanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _performAction(() async {
        final db = ref.read(transactionRepositoryProvider).getDatabase();
        final service = BackupService(db);
        await service.restoreBackup();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Restore Berhasil! Silakan restart aplikasi.'),
            ),
          );
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(recentTransactionsProvider);
        }
      });
    }
  }

  Future<void> _resetApp() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Aplikasi?'),
        content: const Text(
          'PERINGATAN: Semua data akan DIHAPUS PERMANEN.\n\nLanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _performAction(() async {
        final db = ref.read(transactionRepositoryProvider).getDatabase();
        await db.transaction(() async {
          await db.delete(db.cashLogs).go();
          await db.delete(db.transactions).go();
          await db.delete(db.events).go();
          await db.delete(db.members).go();
          await db.delete(db.accounts).go();
          await db.delete(db.categories).go();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data berhasil dihapus.')),
          );
          ref.invalidate(dashboardSummaryProvider);
        }
      });
    }
  }
}
