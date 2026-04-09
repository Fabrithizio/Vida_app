// ============================================================================
// FILE: lib/features/always_on/presentation/widgets/always_on_floating_shell.dart
//
// O que este arquivo faz:
// - Mantém o botão do Sempre Ligado visível na shell principal do app
// - Permite arrastar o botão livremente para não cobrir áreas importantes
// - Preserva o estado do radar ao minimizar, evitando recarregar toda vez
// - Remove o atalho duplicado de Finanças do cabeçalho do painel
// - Deixa o sistema mais chamativo, com cara de radar vivo
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/always_on/presentation/pages/always_on_tab.dart';

class AlwaysOnFloatingShell extends StatefulWidget {
  const AlwaysOnFloatingShell({
    super.key,
    required this.onOpenFinanceRequested,
  });

  // Mantido para compatibilidade com a shell atual do app.
  final VoidCallback onOpenFinanceRequested;

  @override
  State<AlwaysOnFloatingShell> createState() => _AlwaysOnFloatingShellState();
}

class _AlwaysOnFloatingShellState extends State<AlwaysOnFloatingShell> {
  static const double _bubbleSize = 58;
  Offset? _bubbleOffset;
  bool _isOpen = false;
  bool _hasOpenedOnce = false;

  Offset _initialOffset(Size screen, EdgeInsets padding) {
    final left = screen.width - _bubbleSize - 12;
    final top = (screen.height * 0.56).clamp(
      padding.top + 20,
      screen.height - padding.bottom - _bubbleSize - 90,
    );
    return Offset(left, top.toDouble());
  }

  Offset _clampOffset(Offset raw, Size screen, EdgeInsets padding) {
    final minX = 8.0;
    final maxX = screen.width - _bubbleSize - 8;
    final minY = padding.top + 8;
    final maxY = screen.height - padding.bottom - _bubbleSize - 76;
    return Offset(
      raw.dx.clamp(minX, maxX).toDouble(),
      raw.dy.clamp(minY, maxY).toDouble(),
    );
  }

  void _ensureOffset(Size screen, EdgeInsets padding) {
    _bubbleOffset ??= _initialOffset(screen, padding);
    _bubbleOffset = _clampOffset(_bubbleOffset!, screen, padding);
  }

  void _open() {
    setState(() {
      _hasOpenedOnce = true;
      _isOpen = true;
    });
  }

  void _minimize() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
  }

  void _close() {
    _minimize();
  }

  void _updateBubblePosition(
    DragUpdateDetails details,
    Size screen,
    EdgeInsets padding,
  ) {
    final current = _bubbleOffset ?? _initialOffset(screen, padding);
    final next = current + details.delta;
    setState(() => _bubbleOffset = _clampOffset(next, screen, padding));
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    _ensureOffset(screen, padding);

    final panelWidth = screen.width > 500 ? 430.0 : screen.width - 20;
    final panelMaxHeight = screen.height * 0.76;

    return Stack(
      children: [
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _minimize,
              child: Container(color: Colors.black.withValues(alpha: 0.26)),
            ),
          ),
        Positioned(
          left: _bubbleOffset!.dx,
          top: _bubbleOffset!.dy,
          child: IgnorePointer(
            ignoring: _isOpen,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _isOpen ? 0 : 1,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                scale: _isOpen ? 0.84 : 1,
                child: _AlwaysOnBubble(
                  size: _bubbleSize,
                  onTap: _open,
                  onPanUpdate: (details) =>
                      _updateBubblePosition(details, screen, padding),
                ),
              ),
            ),
          ),
        ),
        if (_hasOpenedOnce)
          Positioned(
            right: 10,
            bottom: 12,
            width: panelWidth,
            height: panelMaxHeight,
            child: IgnorePointer(
              ignoring: !_isOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isOpen ? 1 : 0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.bottomRight,
                  scale: _isOpen ? 1 : 0.94,
                  child: _AlwaysOnExpandedPanel(
                    onMinimize: _minimize,
                    onClose: _close,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AlwaysOnBubble extends StatelessWidget {
  const _AlwaysOnBubble({
    required this.size,
    required this.onTap,
    required this.onPanUpdate,
  });

  final double size;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onPanUpdate: onPanUpdate,
      child: SizedBox(
        width: size + 12,
        height: size + 12,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size + 12,
              height: size + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E).withValues(alpha: 0.10),
              ),
            ),
            Container(
              width: size + 4,
              height: size + 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E).withValues(alpha: 0.16),
              ),
            ),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8BFF7C), Color(0xFF22C55E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.42),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.radar_rounded,
                color: Color(0xFF07110A),
                size: 28,
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF07110A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                child: const Text(
                  'Radar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlwaysOnExpandedPanel extends StatelessWidget {
  const _AlwaysOnExpandedPanel({
    required this.onMinimize,
    required this.onClose,
  });

  final VoidCallback onMinimize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF070D19),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 26,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF163425),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: Color(0xFF7CFC7A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sempre Ligado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Seu radar vivo sem sair da tela atual',
                          style: TextStyle(
                            color: Color(0xB3FFFFFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeaderIconButton(
                    icon: Icons.remove_rounded,
                    onTap: onMinimize,
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(icon: Icons.close_rounded, onTap: onClose),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                child: AlwaysOnTab(embedded: true, onMinimize: onMinimize),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
