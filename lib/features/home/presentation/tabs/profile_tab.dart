// ============================================================================
// FILE: lib/features/home/presentation/tabs/profile_tab.dart
//
// O que faz:
// - Mostra o perfil do usuário com visual mais alinhado ao app atual
// - Centraliza identidade, contexto atual, perfil vivo, saúde, conta e app
// - Mantém edição do apelido e dos dados mutáveis do onboarding
// - Prepara melhor a tela para crescer com Play Store e sync futuro
//
// Ajustes desta versão:
// - topo mais vivo e menos técnico
// - destaque para perfil vivo e status de saúde
// - contexto atual mais claro e útil
// - detalhes técnicos rebaixados para a parte final
// - mantém compatibilidade com os services já usados no projeto
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/core/onboarding/questions.dart';
import 'package:vida_app/data/local/session_storage.dart';
import 'package:vida_app/features/areas/application/profile/live_user_profile_bridge.dart';
import 'package:vida_app/features/areas/presentation/widgets/areas_model_assets.dart';
import 'package:vida_app/features/auth/presentation/pages/login_page.dart';
import 'package:vida_app/features/health_sync/health_sync_service.dart';
import 'package:vida_app/features/health_sync/presentation/pages/smart_health_page.dart';
import 'package:vida_app/features/home/presentation/tabs/profile_mutable_answers_service.dart';
import 'package:vida_app/features/home/presentation/tabs/profile_mutable_question_ids.dart';
import 'package:vida_app/features/home/presentation/tabs/profile_mutable_summary_formatter.dart';
import 'package:vida_app/features/life_journey/presentation/pages/life_journey_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileMutableAnswersService _mutableService =
      const ProfileMutableAnswersService();
  final ProfileMutableSummaryFormatter _summaryFormatter =
      const ProfileMutableSummaryFormatter();
  final LiveUserProfileBridge _profileBridge = LiveUserProfileBridge();
  final SmartHealthSyncService _smartHealthService = SmartHealthSyncService();

  bool _loading = true;

  User? _user;
  PackageInfo? _pkg;
  SmartHealthSnapshot? _healthSnapshot;

  String _nickname = '-';
  final TextEditingController _nicknameCtrl = TextEditingController();

  String _gender = '-';
  String _focus = '-';
  String _goal = '-';
  String _dobLabel = '-';
  String _ageLabel = '-';
  String _cpfMasked = '-';
  bool _personalDone = false;
  bool _lifeDone = false;

  String _liveProfileLabel = 'Em adaptação';
  String _liveProfileReason =
      'O app ainda está organizando seus sinais mais recentes.';
  Set<String> _liveTags = <String>{};
  Set<String> _livePrimaryAreas = <String>{};

  Map<String, String> _mutableAnswers = <String, String>{};

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

    SmartHealthSnapshot? healthSnapshot;
    String liveProfileLabel = 'Em adaptação';
    String liveProfileReason =
        'O app ainda está organizando seus sinais mais recentes.';
    Set<String> liveTags = <String>{};
    Set<String> livePrimaryAreas = <String>{};

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final uid = user.uid;

      personalDone = prefs.getBool('personal_done_$uid') ?? false;
      lifeDone = prefs.getBool('life_done_$uid') ?? false;

      gender = (prefs.getString('$uid:gender') ?? '').trim();
      focus = (prefs.getString('$uid:focus') ?? '').trim();
      goal = (prefs.getString('$uid:goal') ?? '').trim();

      final dobIso =
          (prefs.getString('$uid:dob') ??
                  prefs.getString('birth_date_$uid') ??
                  prefs.getString('$uid:birthDate') ??
                  '')
              .trim();

      final cpf = (prefs.getString('$uid:cpf') ?? '').trim();
      final storedNick = await SessionStorage().readNickname(uid);
      final nick = (storedNick ?? '').trim();
      nickname = nick.isEmpty ? '-' : nick;

      final dob = _parseIsoDate(dobIso);
      if (dob != null) {
        dobLabel = _formatBr(dob);
        final age = _ageFromDob(dob);
        ageLabel = age == null ? '-' : '$age';
      }

      if (cpf.isNotEmpty) {
        cpfMasked = _maskCpf(cpf);
      }

      gender = gender.isEmpty ? '-' : gender;
      focus = focus.isEmpty ? '-' : focus;
      goal = goal.isEmpty ? '-' : goal;

      final loaded = await _mutableService.loadAll();
      for (final entry in loaded.entries) {
        final q = _questionById(entry.key);
        if (q != null && q.type == QuestionType.date) {
          final dt = _parseIsoDate(entry.value);
          mutableAnswers[entry.key] = dt == null ? entry.value : _formatBr(dt);
        } else {
          mutableAnswers[entry.key] = entry.value;
        }
      }

      healthSnapshot = await _smartHealthService.readSnapshot(uid);

      try {
        liveProfileLabel = await _profileBridge.currentLabel();
        final reason = await _profileBridge.currentReason();
        liveProfileReason = reason.trim().isEmpty
            ? liveProfileReason
            : reason.trim();
        liveTags = await _profileBridge.currentTags();
        livePrimaryAreas = await _profileBridge.currentPrimaryAreas();
      } catch (_) {}
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
      _healthSnapshot = healthSnapshot;
      _liveProfileLabel = liveProfileLabel;
      _liveProfileReason = liveProfileReason;
      _liveTags = liveTags;
      _livePrimaryAreas = livePrimaryAreas;
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
    _showSnack('Copie manualmente: $text');
  }

  Future<void> _openMutableDataEditor() async {
    final user = _user;
    if (user == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            _MutableLifeDataPage(uid: user.uid, initialValues: _mutableAnswers),
      ),
    );

    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openLifeJourney() async {
    final user = _user;
    if (user == null) return;

    final birthDate = _birthDateForJourney();
    if (birthDate == null) {
      _showSnack('Cadastre a data de nascimento para liberar a Linha da Vida.');
      return;
    }

    final userName = _displayNameForJourney(user);
    final sex = _sexForJourney();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            LifeJourneyPage(userName: userName, sex: sex, birthDate: birthDate),
      ),
    );
  }

  Future<void> _openHealth() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SmartHealthPage()));
    if (!mounted) return;
    await _load();
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
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  DateTime? _birthDateForJourney() {
    if (_dobLabel.trim().isEmpty || _dobLabel == '-') return null;
    final parts = _dobLabel.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  UserSex _sexForJourney() {
    final raw = _gender.trim().toLowerCase();
    if (raw.contains('mulher') || raw.contains('femin')) {
      return UserSex.female;
    }
    return UserSex.male;
  }

  String _displayNameForJourney(User user) {
    final nick = _nickname.trim();
    if (nick.isNotEmpty && nick != '-') return nick;
    final display = (user.displayName ?? '').trim();
    if (display.isNotEmpty) return display;
    final email = (user.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;
    return 'Usuário';
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

  double get _mutableCompletion {
    if (profileMutableQuestionIds.isEmpty) return 0;
    return (_filledMutableCount / profileMutableQuestionIds.length).clamp(
      0.0,
      1.0,
    );
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
        now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) age--;
    if (age < 0 || age > 150) return null;
    return age;
  }

  String _formatBr(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}';
  }

  Question? _questionById(String id) {
    for (final q in lifeQuestions) {
      if (q.id == id) return q;
    }
    return null;
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Color _liveProfileColor() {
    final lower = _liveProfileLabel.toLowerCase();
    if (lower.contains('pressão')) return const Color(0xFFEF4444);
    if (lower.contains('crescimento')) return const Color(0xFF22C55E);
    if (lower.contains('rotina')) return const Color(0xFFF59E0B);
    if (lower.contains('reconex')) return const Color(0xFF60A5FA);
    if (lower.contains('retom')) return const Color(0xFFA78BFA);
    return const Color(0xFF94A3B8);
  }

  String _healthLabel() {
    final snapshot = _healthSnapshot;
    if (snapshot == null) return 'Sem leitura';
    if (!snapshot.isConnected) return 'Não conectado';
    if (!snapshot.hasAnyData) return 'Conectado';
    return 'Ativo';
  }

  String _healthSubtitle() {
    final snapshot = _healthSnapshot;
    if (snapshot == null) return 'Ainda sem dados de saúde.';
    if (!snapshot.isConnected) {
      return 'Conecte Health Connect para enriquecer o app automaticamente.';
    }
    if (snapshot.lastSyncAt == null) {
      return 'Conectado, mas ainda sem sincronização útil.';
    }
    final diff = DateTime.now().difference(snapshot.lastSyncAt!);
    if (diff.inDays >= 1) {
      return 'Última sync há ${diff.inDays} dia${diff.inDays > 1 ? 's' : ''}.';
    }
    if (diff.inHours >= 1) {
      return 'Última sync há ${diff.inHours}h.';
    }
    return 'Sincronizado hoje.';
  }

  Color _healthColor() {
    final snapshot = _healthSnapshot;
    if (snapshot == null) return const Color(0xFF94A3B8);
    if (!snapshot.isConnected) return const Color(0xFFEF4444);
    if (!snapshot.hasAnyData) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: [
                _ProfileHeroCard(
                  user: user,
                  nickname: _nickname,
                  liveProfileLabel: _liveProfileLabel,
                  liveProfileReason: _liveProfileReason,
                  healthLabel: _healthLabel(),
                  liveProfileColor: _liveProfileColor(),
                  healthColor: _healthColor(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.cake_rounded,
                        label: 'Idade',
                        value: _ageLabel == '-' ? '—' : _ageLabel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.sync_alt_rounded,
                        label: 'Contexto',
                        value:
                            '$_filledMutableCount/${profileMutableQuestionIds.length}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.watch_rounded,
                        label: 'Saúde',
                        value: _healthLabel(),
                        valueColor: _healthColor(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _SectionTitle(
                  title: 'Seu momento agora',
                  subtitle:
                      'Esses blocos ajudam o app a entender quem você é hoje, não só quem você era no onboarding.',
                ),
                const SizedBox(height: 8),
                _GlassCard(
                  child: Column(
                    children: [
                      _RichInfoRow(
                        icon: Icons.flag_rounded,
                        label: 'Foco atual',
                        value: _focus,
                      ),
                      const Divider(height: 18, color: Colors.white12),
                      _RichInfoRow(
                        icon: Icons.rocket_launch_rounded,
                        label: 'Objetivo atual',
                        value: _goal,
                      ),
                      const Divider(height: 18, color: Colors.white12),
                      _RichInfoRow(
                        icon: Icons.health_and_safety_rounded,
                        label: 'Saúde automática',
                        value: _healthSubtitle(),
                        valueColor: Colors.white70,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _InlineHeader(
                        icon: Icons.psychology_alt_rounded,
                        title: 'Perfil vivo atual',
                        subtitle:
                            'Essa leitura muda com seu uso, check-ins e sinais reais do app.',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SoftPill(
                            label: _liveProfileLabel,
                            color: _liveProfileColor(),
                          ),
                          ..._liveTags
                              .take(4)
                              .map(
                                (tag) => _SoftPill(
                                  label: _prettyTag(tag),
                                  color: Colors.white70,
                                  outlined: true,
                                ),
                              ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _liveProfileReason,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      if (_livePrimaryAreas.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Áreas mais sensíveis agora',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.90),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _livePrimaryAreas
                              .map(
                                (id) => _SoftPill(
                                  label: _areaName(id),
                                  color: Colors.white54,
                                  outlined: true,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const _SectionTitle(
                  title: 'Contexto atual da sua vida',
                  subtitle:
                      'Esses dados são os que mais mudam com o tempo e ajudam o app a acompanhar seu momento real.',
                ),
                const SizedBox(height: 8),
                _GlassCard(
                  child: Column(
                    children: [
                      _InlineHeader(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Dados que mudam com o tempo',
                        subtitle:
                            'Preenchidos: $_filledMutableCount de ${profileMutableQuestionIds.length}',
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: _mutableCompletion,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ContextPreviewGrid(
                        summaryFormatter: _summaryFormatter,
                        mutableAnswers: _mutableAnswers,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _openMutableDataEditor,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Atualizar meu momento atual'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const _SectionTitle(
                  title: 'Atalhos importantes',
                  subtitle:
                      'Deixe o perfil com cara de central pessoal, não só de cadastro.',
                ),
                const SizedBox(height: 8),
                _QuickActionsGrid(
                  onOpenLifeJourney: _openLifeJourney,
                  onOpenHealth: _openHealth,
                  onRefresh: _refreshUser,
                ),
                const SizedBox(height: 14),
                const _SectionTitle(
                  title: 'Dados pessoais',
                  subtitle:
                      'Base mais fixa do seu perfil. Continua aqui, mas sem roubar a cena do que é vivo.',
                ),
                const SizedBox(height: 8),
                _GlassCard(
                  child: Column(
                    children: [
                      _RichInfoRow(
                        icon: Icons.person_rounded,
                        label: 'Sexo',
                        value: _gender,
                      ),
                      const Divider(height: 18, color: Colors.white12),
                      _RichInfoRow(
                        icon: Icons.calendar_month_rounded,
                        label: 'Data de nascimento',
                        value: _dobLabel,
                      ),
                      const Divider(height: 18, color: Colors.white12),
                      _RichInfoRow(
                        icon: Icons.cake_rounded,
                        label: 'Idade',
                        value: _ageLabel,
                      ),
                      const Divider(height: 18, color: Colors.white12),
                      _RichInfoRow(
                        icon: Icons.badge_rounded,
                        label: 'CPF',
                        value: _cpfMasked,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const _SectionTitle(
                  title: 'Conta e aplicativo',
                  subtitle:
                      'Parte mais técnica, mas ainda útil para manutenção e suporte.',
                ),
                const SizedBox(height: 8),
                _GlassCard(
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: Colors.white70,
                      collapsedIconColor: Colors.white54,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text(
                        'Detalhes da conta',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        user?.email ?? 'Sem email',
                        style: const TextStyle(color: Colors.white60),
                      ),
                      children: [
                        _RichInfoRow(
                          icon: Icons.login_rounded,
                          label: 'Provider',
                          value: user == null ? '-' : _providerLabel(user),
                        ),
                        const Divider(height: 18, color: Colors.white12),
                        _RichInfoRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'Email',
                          value: user?.email ?? '-',
                        ),
                        const Divider(height: 18, color: Colors.white12),
                        _RichInfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Nome no Firebase',
                          value: user?.displayName ?? '-',
                        ),
                        const Divider(height: 18, color: Colors.white12),
                        _RichInfoRow(
                          icon: Icons.badge_rounded,
                          label: 'Apelido no app',
                          value: _nickname,
                        ),
                        const Divider(height: 18, color: Colors.white12),
                        _RichInfoRow(
                          icon: Icons.mark_email_read_rounded,
                          label: 'Email verificado',
                          value: user == null
                              ? '-'
                              : (user.emailVerified ? 'Sim' : 'Não'),
                        ),
                        const Divider(height: 18, color: Colors.white12),
                        _RichInfoRow(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Onboarding Perfil',
                          value: user == null
                              ? '-'
                              : (_personalDone ? 'Concluído' : 'Pendente'),
                        ),
                        const Divider(height: 18, color: Colors.white12),
                        _RichInfoRow(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Onboarding Vida',
                          value: user == null
                              ? '-'
                              : (_lifeDone ? 'Concluído' : 'Pendente'),
                        ),
                        const Divider(height: 18, color: Colors.white12),
                        _RichInfoRow(
                          icon: Icons.copy_rounded,
                          label: 'UID',
                          value: user?.uid ?? '-',
                          trailing: user == null
                              ? null
                              : TextButton(
                                  onPressed: () => _copyToClipboard(user.uid),
                                  child: const Text('Copiar'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _GlassCard(
                  child: Column(
                    children: [
                      _RichInfoRow(
                        icon: Icons.apps_rounded,
                        label: 'Versão',
                        value: _pkg?.version ?? '-',
                      ),
                      const Divider(height: 18, color: Colors.white12),
                      _RichInfoRow(
                        icon: Icons.numbers_rounded,
                        label: 'Build',
                        value: _pkg?.buildNumber ?? '-',
                      ),
                      const Divider(height: 18, color: Colors.white12),
                      _RichInfoRow(
                        icon: Icons.inventory_2_rounded,
                        label: 'Package',
                        value: _pkg?.packageName ?? '-',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _GlassCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          'Recarregar dados',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Atualiza Firebase, perfil vivo, saúde e contexto.',
                          style: TextStyle(color: Colors.white60),
                        ),
                        onTap: _refreshUser,
                      ),
                      const Divider(height: 18, color: Colors.white12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                        ),
                        title: const Text(
                          'Sair da conta',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Volta para a tela de login.',
                          style: TextStyle(color: Colors.white60),
                        ),
                        onTap: _signOut,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _areaName(String id) {
    switch (id) {
      case 'body_health':
        return 'Corpo';
      case 'mind_emotion':
        return 'Mente';
      case 'finance_material':
        return 'Finanças';
      case 'work_vocation':
        return 'Trabalho';
      case 'learning_intellect':
        return 'Aprendizado';
      case 'relations_community':
        return 'Relações';
      case 'digital_tech':
        return 'Digital';
      case 'environment_home':
        return 'Casa';
      case 'purpose_values':
        return 'Direção';
      default:
        return id;
    }
  }

  String _prettyTag(String raw) {
    final value = raw.replaceAll('_', ' ').trim();
    if (value.isEmpty) return raw;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.user,
    required this.nickname,
    required this.liveProfileLabel,
    required this.liveProfileReason,
    required this.healthLabel,
    required this.liveProfileColor,
    required this.healthColor,
  });

  final User? user;
  final String nickname;
  final String liveProfileLabel;
  final String liveProfileReason;
  final String healthLabel;
  final Color liveProfileColor;
  final Color healthColor;

  @override
  Widget build(BuildContext context) {
    final photo = user?.photoURL;
    final title = (nickname.trim().isEmpty || nickname == '-')
        ? (user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!.trim()
              : 'Usuário')
        : nickname;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            liveProfileColor.withValues(alpha: 0.26),
            const Color(0xFF0F0F1A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: liveProfileColor.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white10,
                backgroundImage: (photo != null && photo.isNotEmpty)
                    ? NetworkImage(photo)
                    : null,
                child: (photo == null || photo.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white70, size: 34)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'Sem email',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SoftPill(
                          label: liveProfileLabel,
                          color: liveProfileColor,
                        ),
                        _SoftPill(
                          label: 'Saúde: $healthLabel',
                          color: healthColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              liveProfileReason,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, height: 1.35),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

class _InlineHeader extends StatelessWidget {
  const _InlineHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white60,
                  height: 1.3,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _RichInfoRow extends StatelessWidget {
  const _RichInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final fg = outlined ? Colors.white70 : color;
    final bg = outlined
        ? Colors.white.withValues(alpha: 0.05)
        : color.withValues(alpha: 0.14);
    final bd = outlined ? Colors.white12 : color.withValues(alpha: 0.24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ContextPreviewGrid extends StatelessWidget {
  const _ContextPreviewGrid({
    required this.summaryFormatter,
    required this.mutableAnswers,
  });

  final ProfileMutableSummaryFormatter summaryFormatter;
  final Map<String, String> mutableAnswers;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, String key})>[
      (icon: Icons.home_rounded, title: 'Casa e família', key: 'living_with'),
      (
        icon: Icons.work_rounded,
        title: 'Trabalho / estudos',
        key: 'study_work',
      ),
      (
        icon: Icons.psychology_rounded,
        title: 'Mente e carga',
        key: 'stress_level',
      ),
      (
        icon: Icons.account_balance_wallet_rounded,
        title: 'Finanças',
        key: 'financial_situation',
      ),
      (icon: Icons.flag_rounded, title: 'Prioridade atual', key: 'goal'),
      (
        icon: Icons.people_alt_rounded,
        title: 'Rede emocional',
        key: 'emotional_support',
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final value = summaryFormatter.formatValue(mutableAnswers[item.key]);
        return SizedBox(
          width: 150,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: Colors.white70, size: 18),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onOpenLifeJourney,
    required this.onOpenHealth,
    required this.onRefresh,
  });

  final VoidCallback onOpenLifeJourney;
  final VoidCallback onOpenHealth;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _QuickActionTile(
          icon: Icons.timeline_rounded,
          title: 'Linha da Vida',
          subtitle: 'Ver marcos e desbloqueios',
          onTap: onOpenLifeJourney,
        ),
        _QuickActionTile(
          icon: Icons.watch_rounded,
          title: 'Saúde',
          subtitle: 'Conectar ou revisar sync',
          onTap: onOpenHealth,
        ),
        _QuickActionTile(
          icon: Icons.refresh_rounded,
          title: 'Atualizar',
          subtitle: 'Recarregar seus dados',
          onTap: onRefresh,
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 166,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white60,
                  height: 1.3,
                  fontSize: 12,
                ),
              ),
            ],
          ),
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
  final ProfileMutableAnswersService _mutableService =
      const ProfileMutableAnswersService();

  @override
  void initState() {
    super.initState();
    _values = Map<String, String>.from(widget.initialValues);
  }

  List<Question> get _questions {
    final map = <String, Question>{for (final q in lifeQuestions) q.id: q};
    return profileMutableQuestionIds
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

    setState(() => _values[q.id] = _isoToBr(iso));
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
      if (dt.year != year || dt.month != month || dt.day != day) return null;
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  String _isoToBr(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().padLeft(4, '0')}';
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

    final map = <String, String>{};
    for (final q in _questions) {
      final value = _storeValue(q);
      if (value.isNotEmpty) {
        map[q.id] = value;
      }
    }

    await _mutableService.saveMany(map);
    final prefs = await SharedPreferences.getInstance();
    for (final q in _questions) {
      if (!map.containsKey(q.id)) {
        await prefs.remove('${widget.uid}:${q.id}');
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
              'Aqui você atualiza rotina, trabalho, finanças, relações e prioridades atuais. Isso ajuda o app a não ficar preso só na sua primeira versão.',
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
