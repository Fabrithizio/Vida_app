// ============================================================================
// FILE: lib/features/home/presentation/tabs/profile_tab.dart
//
// O que faz:
// - Mostra o perfil do usuário com dados da conta, apelido e onboarding.
// - Mantém a seção atual de dados pessoais básicos.
// - Adiciona uma área própria para editar os dados do onboarding que mudam
//   com o tempo (contexto de vida / rotina / trabalho / finanças etc.).
// - Salva tudo nas mesmas chaves já usadas no onboarding: "uid:id_da_pergunta".
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/core/onboarding/questions.dart';
import 'package:vida_app/data/local/session_storage.dart';
import 'package:vida_app/features/auth/presentation/pages/login_page.dart';
import 'package:vida_app/features/health_sync/presentation/pages/smart_health_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = true;
  User? _user;
  PackageInfo? _pkg;

  String _nickname = '-';
  final TextEditingController _nicknameCtrl = TextEditingController();
  bool _savingNickname = false;

  // Onboarding / perfil básico
  String _gender = '-';
  String _focus = '-';
  String _goal = '-';
  String _dobLabel = '-';
  String _ageLabel = '-';
  String _cpfMasked = '-';
  bool _personalDone = false;
  bool _lifeDone = false;

  // Resumo dos dados mutáveis
  Map<String, String> _mutableAnswers = <String, String>{};

  static const List<String> _mutableQuestionIds = <String>[
    'living_with',
    'children_count',
    'family_relationship',
    'home_routine_load',
    'study_work',
    'occupation_type',
    'work_field',
    'work_schedule_format',
    'work_demand_type',
    'work_satisfaction',
    'health_self_rating',
    'health_limitations',
    'sleep_hours_avg',
    'exercise_frequency',
    'last_checkup',
    'stress_level',
    'emotional_state',
    'rest_capacity',
    'mental_load',
    'life_demands_capacity',
    'financial_situation',
    'income_stability',
    'financial_main_difficulty',
    'expense_tracking',
    'dependents_financial',
    'social_life',
    'emotional_support',
    'romantic_relationship',
    'friendship_connection',
    'loneliness',
    'personal_organization',
    'home_organization',
    'screen_time',
    'phone_usage_purpose',
    'consistency',
    'routine_predictability',
    'routine_main_weight',
    'focus',
    'goal',
    'app_help',
    'start_preference',
  ];

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
    return '***.***.***-${digits.substring(9, 11)}';
  }

  DateTime? _parseIsoDate(String iso) {
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

  String _formatBr(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year.toString().padLeft(4, '0')}';
  }

  Question? _questionById(String id) {
    for (final q in lifeQuestions) {
      if (q.id == id) return q;
    }
    return null;
  }

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
    final mutableAnswers = <String, String>{};

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final uid = user.uid;

      personalDone = prefs.getBool('personal_done_$uid') ?? false;
      lifeDone = prefs.getBool('life_done_$uid') ?? false;

      gender = (prefs.getString('$uid:gender') ?? '').trim();
      focus = (prefs.getString('$uid:focus') ?? '').trim();
      goal = (prefs.getString('$uid:goal') ?? '').trim();
      final dobIso = (prefs.getString('$uid:dob') ?? '').trim();
      final cpf = (prefs.getString('$uid:cpf') ?? '').trim();

      final storedNick = await SessionStorage().readNickname(uid);
      final v = (storedNick ?? '').trim();
      nickname = v.isEmpty ? '-' : v;

      final dob = _parseIsoDate(dobIso);
      if (dob != null) {
        dobLabel = _formatBr(dob);
        final age = _ageFromDob(dob);
        ageLabel = age == null ? '-' : '$age';
      }

      if (cpf.isNotEmpty) cpfMasked = _maskCpf(cpf);

      gender = gender.isEmpty ? '-' : gender;
      focus = focus.isEmpty ? '-' : focus;
      goal = goal.isEmpty ? '-' : goal;

      for (final id in _mutableQuestionIds) {
        final raw = (prefs.getString('$uid:$id') ?? '').trim();
        if (raw.isEmpty) continue;
        final q = _questionById(id);
        if (q != null && q.type == QuestionType.date) {
          final dt = _parseIsoDate(raw);
          mutableAnswers[id] = dt == null ? raw : _formatBr(dt);
        } else {
          mutableAnswers[id] = raw;
        }
      }
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
      _mutableAnswers = mutableAnswers;
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

  Future<void> _openMutableDataEditor() async {
    final user = _user;
    if (user == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _MutableLifeDataPage(uid: user.uid, initialValues: _mutableAnswers),
      ),
    );

    if (changed == true) {
      await _load();
    }
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

  int get _filledMutableCount =>
      _mutableAnswers.values.where((e) => e.trim().isNotEmpty).length;

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
                const _SectionTitle(title: 'Perfil'),
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
                        'Informações mais fixas do onboarding',
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
                const _SectionTitle(title: 'Dados que mudam com o tempo'),
                const SizedBox(height: 8),
                _InfoCard(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.sync_alt_rounded,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Contexto atual da sua vida',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        'Edite rotina, trabalho, finanças, relações, saúde e outras respostas do onboarding que podem mudar com o tempo.\n\n'
                        'Preenchidos: $_filledMutableCount de ${_mutableQuestionIds.length}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white54,
                      ),
                      onTap: _openMutableDataEditor,
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    _MutablePreviewRow(
                      icon: Icons.home_rounded,
                      label: 'Casa e família',
                      value: _mutableAnswers['living_with'] ?? '-',
                    ),
                    _MutablePreviewRow(
                      icon: Icons.work_rounded,
                      label: 'Trabalho / estudos',
                      value: _mutableAnswers['study_work'] ?? '-',
                    ),
                    _MutablePreviewRow(
                      icon: Icons.favorite_rounded,
                      label: 'Saúde e corpo',
                      value: _mutableAnswers['health_self_rating'] ?? '-',
                    ),
                    _MutablePreviewRow(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Finanças',
                      value: _mutableAnswers['financial_situation'] ?? '-',
                    ),
                    _MutablePreviewRow(
                      icon: Icons.flag_rounded,
                      label: 'Prioridade atual',
                      value: _mutableAnswers['goal'] ?? '-',
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openMutableDataEditor,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Abrir editor desses dados'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SectionTitle(title: 'Conta'),
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
                const _SectionTitle(title: 'Ações'),
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
                        'Atualiza Firebase + onboarding + apelido',
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
                const _SectionTitle(title: 'Saúde & smartwatch'),
                const SizedBox(height: 8),
                _InfoCard(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.watch_rounded,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Conectar saúde / smartwatch',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Liga o app ao Health Connect / Apple Health para enviar dados ao Areas automaticamente',
                        style: TextStyle(color: Colors.white60),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SmartHealthPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SectionTitle(title: 'App'),
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

class _MutablePreviewRow extends StatelessWidget {
  const _MutablePreviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.white54, size: 20),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MutableLifeDataPage extends StatefulWidget {
  const _MutableLifeDataPage({required this.uid, required this.initialValues});

  final String uid;
  final Map<String, String> initialValues;

  @override
  State<_MutableLifeDataPage> createState() => _MutableLifeDataPageState();
}

class _MutableLifeDataPageState extends State<_MutableLifeDataPage> {
  late final Map<String, String> _values;
  bool _saving = false;

  static const List<String> _orderedIds = <String>[
    'living_with',
    'children_count',
    'family_relationship',
    'home_routine_load',
    'study_work',
    'occupation_type',
    'work_field',
    'work_schedule_format',
    'work_demand_type',
    'work_satisfaction',
    'health_self_rating',
    'health_limitations',
    'sleep_hours_avg',
    'exercise_frequency',
    'last_checkup',
    'stress_level',
    'emotional_state',
    'rest_capacity',
    'mental_load',
    'life_demands_capacity',
    'financial_situation',
    'income_stability',
    'financial_main_difficulty',
    'expense_tracking',
    'dependents_financial',
    'social_life',
    'emotional_support',
    'romantic_relationship',
    'friendship_connection',
    'loneliness',
    'personal_organization',
    'home_organization',
    'screen_time',
    'phone_usage_purpose',
    'consistency',
    'routine_predictability',
    'routine_main_weight',
    'focus',
    'goal',
    'app_help',
    'start_preference',
  ];

  @override
  void initState() {
    super.initState();
    _values = Map<String, String>.from(widget.initialValues);
  }

  List<Question> get _questions {
    final map = <String, Question>{for (final q in lifeQuestions) q.id: q};
    return _orderedIds
        .map((id) => map[id])
        .whereType<Question>()
        .toList(growable: false);
  }

  Future<void> _pickOption(Question q) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101010),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.question,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((q.helper ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        q.helper!,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in q.options)
                      ListTile(
                        title: Text(
                          option,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: (_values[q.id] ?? '') == option
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.greenAccent,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(option),
                      ),
                    if (q.optional)
                      ListTile(
                        leading: const Icon(
                          Icons.clear_rounded,
                          color: Colors.white54,
                        ),
                        title: const Text(
                          'Limpar resposta',
                          style: TextStyle(color: Colors.white70),
                        ),
                        onTap: () => Navigator.of(context).pop('__clear__'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;
    setState(() {
      if (result == '__clear__') {
        _values.remove(q.id);
      } else {
        _values[q.id] = result;
      }
    });
  }

  Future<void> _editDate(Question q) async {
    final controller = TextEditingController(text: _values[q.id] ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),
          title: Text(q.question, style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'DD/MM/AAAA',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green),
              ),
            ),
          ),
          actions: [
            if (q.optional)
              TextButton(
                onPressed: () => Navigator.of(context).pop('__clear__'),
                child: const Text('Limpar'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) return;
    if (result == '__clear__') {
      setState(() => _values.remove(q.id));
      return;
    }

    final iso = _brToIso(result);
    if (iso == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data inválida. Use DD/MM/AAAA.')),
      );
      return;
    }

    setState(() {
      _values[q.id] = _isoToBr(iso);
    });
  }

  String? _brToIso(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    try {
      final dt = DateTime(year, month, day);
      if (dt.year != year || dt.month != month || dt.day != day) {
        return null;
      }
      return '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  String _isoToBr(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year.toString().padLeft(4, '0')}';
  }

  String _storeValue(Question q) {
    final raw = (_values[q.id] ?? '').trim();
    if (raw.isEmpty) return '';
    if (q.type == QuestionType.date) {
      final iso = _brToIso(raw);
      return iso ?? raw;
    }
    return raw;
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();

    for (final q in _questions) {
      final key = '${widget.uid}:${q.id}';
      final value = _storeValue(q);
      if (value.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  Map<String, List<Question>> _groupedQuestions() {
    final map = <String, List<Question>>{};
    for (final q in _questions) {
      final section = q.sectionTitle ?? 'Outros';
      map.putIfAbsent(section, () => <Question>[]).add(q);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedQuestions();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Dados que mudam com o tempo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'Aqui você atualiza as respostas do onboarding que podem mudar com o tempo, como rotina, trabalho, finanças, relações, saúde e prioridades atuais.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in grouped.entries) ...[
            Text(
              entry.key,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < entry.value.length; i++) ...[
                    _EditableQuestionTile(
                      question: entry.value[i],
                      value: (_values[entry.value[i].id] ?? '').trim(),
                      onTap: () {
                        final q = entry.value[i];
                        if (q.type == QuestionType.options) {
                          _pickOption(q);
                        } else if (q.type == QuestionType.date) {
                          _editDate(q);
                        }
                      },
                    ),
                    if (i != entry.value.length - 1)
                      const Divider(height: 1, color: Colors.white12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveAll,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Salvar alterações'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EditableQuestionTile extends StatelessWidget {
  const _EditableQuestionTile({
    required this.question,
    required this.value,
    required this.onTap,
  });

  final Question question;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        question.question,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? 'Não preenchido' : value,
            style: TextStyle(
              color: value.isEmpty ? Colors.white38 : Colors.white70,
            ),
          ),
          if ((question.helper ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              question.helper!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
      onTap: onTap,
    );
  }
}
