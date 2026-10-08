import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'main_screen.dart';

/// Layar login (username + password) yang terhubung ke backend JWT.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    if (!mounted) return;
    final user = await AuthService.currentUser();
    if (!mounted) return;
    if (user != null) _goToMainScreen();
  }

  void _goToMainScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.login(
        login: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      _goToMainScreen();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Tidak dapat terhubung: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand mark
                  Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: p.heroGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: p.brand.withValues(alpha: 0.45),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      )
                      .animate()
                      .fade(duration: 450.ms)
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        curve: Curves.easeOutBack,
                        duration: 600.ms,
                      ),
                  const SizedBox(height: 22),
                  Text(
                    'Saku Organisasi',
                    style: context.texts.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kelola kas organisasi dengan rapi & aman',
                    textAlign: TextAlign.center,
                    style: context.texts.bodyMedium?.copyWith(
                      color: p.textMuted,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Form card
                  AppCard(
                        padding: const EdgeInsets.all(22),
                        radius: AppRadius.xl,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Masuk',
                                style: context.texts.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Gunakan akun bendahara Anda',
                                style: context.texts.bodySmall?.copyWith(
                                  color: p.textMuted,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _usernameController,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) {
                                  final s = v?.trim() ?? '';
                                  if (s.isEmpty) return 'Username wajib diisi';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _submitLogin(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Tampilkan'
                                        : 'Sembunyikan',
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                              ),

                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                child: _errorMessage == null
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 14),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: p.expense.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.sm,
                                            ),
                                            border: Border.all(
                                              color: p.expense.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                color: p.expense,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _errorMessage!,
                                                  style: context.texts.bodySmall
                                                      ?.copyWith(color: p.expense),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),

                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: _loading ? null : _submitLogin,
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.login_rounded, size: 19),
                                          SizedBox(width: 8),
                                          Text('Masuk'),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate()
                      .fade(delay: 120.ms, duration: 450.ms)
                      .slideY(begin: 0.06, end: 0, delay: 120.ms, duration: 450.ms),


                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
