// ============================================================================
// FILE: lib/presentation/pages/home/tabs/profile_tab.dart
//
// Ajustes:
// - Mostra dados do onboarding por UID (SharedPreferences):
//   - $uid:dob (ISO yyyy-mm-dd)
//   - $uid:cpf
//   - $uid:gender
//   - $uid:focus
//   - $uid:goal
// - Mostra idade calculada a partir do DOB
// - CPF mascarado
// - Mantém apelido (SessionStorage.nickname_<uid>)
// - Logout redireciona para LoginPage (stack limpa)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/data/local/session_storage.dart';
import 'package:vida_app/features/auth/presentation/pages/login_page.dart';

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

  String _nickname = '-';
  final _nicknameCtrl = TextEditingController();
  bool _savingNickname = false;

  // Onboarding / perfil do app (por UID)
  String _gender = '-';
  String _focus = '-';
  String _goal = '-';
  String _dobLabel = '-';
  String _ageLabel = '-';
  String _cpfMasked = '-';

  bool _personalDone = false;
  bool _lifeDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  String _maskCpf(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return '-';
    // ***.***.***-12 (mostra só os 2 últimos)
    return '***.***.***-${digits.substring(9, 11)}';
  }

  DateTime? _parseIsoDob(String iso) {
    if (iso.trim().isEmpty) return null;
    try {
      return DateTime.parse(iso.trim());
    } catch (_) {
      return null;
    }
  }

  int? _ageFromDob(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    final hadBirthday =
        (now.month > dob.month) ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) age--;
    if (age < 0 || age > 150) return null;
    return age;
  }

  String _formatBr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);

    final user = _auth.currentUser;
    final pkg = await PackageInfo.fromPlatform();

    String nickname = '-';
    String gender = '-';
    String focus = '-';
    String goal = '-';
    String dobLabel = '-';
    String ageLabel = '-';
    String cpfMasked = '-';

    bool personalDone = false;
    bool lifeDone = false;

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final uid = user.uid;

      // flags (novo)
      personalDone = prefs.getBool('personal_done_$uid') ?? false;
      lifeDone = prefs.getBool('life_done_$uid') ?? false;

      // dados por uid
      gender = (prefs.getString('$uid:gender') ?? '').trim();
      focus = (prefs.getString('$uid:focus') ?? '').trim();
      goal = (prefs.getString('$uid:goal') ?? '').trim();

      final dobIso = (prefs.getString('$uid:dob') ?? '').trim();
      final cpf = (prefs.getString('$uid:cpf') ?? '').trim();

      final storedNick = await SessionStorage().readNickname(uid);
      final v = (storedNick ?? '').trim();
      nickname = v.isEmpty ? '-' : v;

      // DOB / idade
      final dob = _parseIsoDob(dobIso);
      if (dob != null) {
        dobLabel = _formatBr(dob);
        final age = _ageFromDob(dob);
        ageLabel = age == null ? '-' : '$age';
      }

      // CPF
      if (cpf.isNotEmpty) cpfMasked = _maskCpf(cpf);

      // defaults bonitos
      gender = gender.isEmpty ? '-' : gender;
      focus = focus.isEmpty ? '-' : focus;
      goal = goal.isEmpty ? '-' : goal;
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _pkg = pkg;

      _nickname = nickname;
      _nicknameCtrl.text = nickname == '-' ? '' : nickname;

      _gender = gender;
      _focus = focus;
      _goal = goal;
      _dobLabel = dobLabel;
      _ageLabel = ageLabel;
      _cpfMasked = cpfMasked;

      _personalDone = personalDone;
      _lifeDone = lifeDone;

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copie manualmente: $text')));
  }

  Future<void> _saveNickname() async {
    final user = _user;
    if (user == null) return;

    final value = _nicknameCtrl.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Digite um nome/apelido.')));
      return;
    }

    setState(() => _savingNickname = true);
    await SessionStorage().saveNickname(user.uid, value);

    if (!mounted) return;
    setState(() {
      _nickname = value;
      _savingNickname = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Apelido salvo.')));
  }

  Future<void> _signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    try {
      await _auth.signOut();
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
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
                _HeaderCard(user: user, nickname: _nickname),
                const SizedBox(height: 12),

                _SectionTitle(title: 'Perfil'),
                const SizedBox(height: 8),
                _InfoCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge, color: Colors.white70),
                      title: const Text(
                        'Apelido',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Este nome aparece no app (ex: topo das Áreas)',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nicknameCtrl,
                              enabled: !_savingNickname,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Nome / Apelido',
                                labelStyle: TextStyle(color: Colors.white70),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.green,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _savingNickname || user == null
                                ? null
                                : _saveNickname,
                            child: _savingNickname
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Salvar'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white12),

                    // Dados pessoais do onboarding
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.white70),
                      title: const Text(
                        'Dados pessoais',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: const Text(
                        'Informações do onboarding (salvas por usuário)',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                    _InfoRow(label: 'Sexo', value: _gender),
                    _InfoRow(label: 'Data de nascimento', value: _dobLabel),
                    _InfoRow(label: 'Idade', value: _ageLabel),
                    _InfoRow(label: 'CPF', value: _cpfMasked),
                    const Divider(height: 1, color: Colors.white12),
                    _InfoRow(label: 'Foco', value: _focus),
                    _InfoRow(label: 'Objetivo', value: _goal),
                    const SizedBox(height: 8),
                  ],
                ),

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
                    _InfoRow(
                      label: 'Nome (Firebase)',
                      value: user?.displayName ?? '-',
                    ),
                    _InfoRow(label: 'Apelido (App)', value: _nickname),
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
                      label: 'Onboarding Perfil',
                      value: user == null
                          ? '-'
                          : (_personalDone ? 'Sim' : 'Não'),
                    ),
                    _InfoRow(
                      label: 'Onboarding Vida',
                      value: user == null ? '-' : (_lifeDone ? 'Sim' : 'Não'),
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
                        'Atualiza Firebase + dados do onboarding + apelido',
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
                        'Volta para a tela de login',
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
  const _HeaderCard({required this.user, required this.nickname});

  final User? user;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final photo = user?.photoURL;
    final title = (nickname.trim().isEmpty || nickname == '-')
        ? (user?.displayName ?? 'Usuário')
        : nickname;

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
                  title,
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
