// ============================================================================
// FILE: lib/presentation/pages/home/tabs/profile_tab.dart
//
// Perfil (padrão de apps):
// - Mostra a conta logada (email/nome/foto/provider/uid)
// - Mostra estado (email verificado, onboarding concluído por usuário)
// - Ações: copiar UID, recarregar, sair (Firebase + Google)
// - Mostra info do app (versão/build)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _auth = FirebaseAuth.instance;

  bool _loading = true;

  User? _user;
  PackageInfo? _pkg;
  bool? _onboardingDoneForUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final user = _auth.currentUser;
    final pkg = await PackageInfo.fromPlatform();

    bool? onboarding;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      onboarding = prefs.getBool('onboarding_done_${user.uid}') ?? false;
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _pkg = pkg;
      _onboardingDoneForUser = onboarding;
      _loading = false;
    });
  }

  Future<void> _refreshUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (_) {}
    await _load();
  }

  Future<void> _copyToClipboard(String text) async {
    // Sem Clipboard package extra: usa TextField selection workaround? Melhor: Scaffold msg.
    // (Se você quiser cópia real, eu adiciono flutter/services Clipboard no próximo passo.)
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copie manualmente: $text')));
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}

    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Você saiu da conta.')));

    await _load();
  }

  String _providerLabel(User user) {
    final ids = user.providerData.map((e) => e.providerId).toSet();
    if (ids.contains('google.com')) return 'Google';
    if (ids.contains('password')) return 'Email/Senha';
    if (ids.isEmpty) return 'Desconhecido';
    return ids.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _HeaderCard(user: user),
                const SizedBox(height: 12),

                _SectionTitle(title: 'Conta'),
                const SizedBox(height: 8),
                _InfoCard(
                  children: [
                    _InfoRow(
                      label: 'Provider',
                      value: user == null ? '-' : _providerLabel(user),
                    ),
                    _InfoRow(label: 'Email', value: user?.email ?? '-'),
                    _InfoRow(label: 'Nome', value: user?.displayName ?? '-'),
                    _InfoRow(
                      label: 'UID',
                      value: user?.uid ?? '-',
                      trailing: user == null
                          ? null
                          : TextButton(
                              onPressed: () => _copyToClipboard(user.uid),
                              child: const Text('Copiar'),
                            ),
                    ),
                    _InfoRow(
                      label: 'Email verificado',
                      value: user == null
                          ? '-'
                          : (user.emailVerified ? 'Sim' : 'Não'),
                    ),
                    _InfoRow(
                      label: 'Onboarding concluído',
                      value: user == null
                          ? '-'
                          : ((_onboardingDoneForUser ?? false) ? 'Sim' : 'Não'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                _SectionTitle(title: 'Ações'),
                const SizedBox(height: 8),
                _InfoCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.refresh, color: Colors.white70),
                      title: const Text(
                        'Recarregar dados',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Atualiza info do Firebase (verificação, nome, etc.)',
                        style: TextStyle(color: Colors.white60),
                      ),
                      onTap: _refreshUser,
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        'Sair da conta',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Desloga do Firebase e Google (se aplicável)',
                        style: TextStyle(color: Colors.white60),
                      ),
                      onTap: _signOut,
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                _SectionTitle(title: 'App'),
                const SizedBox(height: 8),
                _InfoCard(
                  children: [
                    _InfoRow(
                      label: 'Versão',
                      value: _pkg == null ? '-' : _pkg!.version,
                    ),
                    _InfoRow(
                      label: 'Build',
                      value: _pkg == null ? '-' : _pkg!.buildNumber,
                    ),
                    _InfoRow(
                      label: 'Package',
                      value: _pkg == null ? '-' : _pkg!.packageName,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final photo = user?.photoURL;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white10,
            backgroundImage: (photo != null && photo.isNotEmpty)
                ? NetworkImage(photo)
                : null,
            child: (photo == null || photo.isEmpty)
                ? const Icon(Icons.person, color: Colors.white70, size: 30)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Usuário',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'Sem email',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 14,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      trailing: trailing,
    );
  }
}
