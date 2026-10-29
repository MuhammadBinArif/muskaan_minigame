import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _AvatarStudioColors {
  static const page = Color(0xFF100C14);
  static const panel = Color(0xFF1F1F32);
  static const surface = Color(0xFF2A2947);
  static const surfaceDark = Color(0xFF1D1B35);
  static const border = Color(0xFF3A3859);
  static const cream = Color(0xFFFFF7EC);
  static const body = Color(0xFFC8C4D4);
  static const muted = Color(0xFF8D899E);
  static const orange = Color(0xFFFF6842);
  static const gold = Color(0xFFFFD24A);
}

class AvatarStudioScreen extends StatefulWidget {
  const AvatarStudioScreen({super.key});

  @override
  State<AvatarStudioScreen> createState() => _AvatarStudioScreenState();
}

class _AvatarStudioScreenState extends State<AvatarStudioScreen> {
  static const List<String> _tabs = <String>['Face', 'Hair', 'Style', 'Extras'];

  int _selectedTab = 1;
  int _selectedHair = 0;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  void _reset() {
    setState(() {
      _selectedTab = 1;
      _selectedHair = 0;
    });
  }

  void _save() {
    if (context.canPop()) {
      context.pop(_selectedHair);
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AvatarStudioColors.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(31),
                child: ColoredBox(
                  key: const Key('avatar-studio-panel'),
                  color: _AvatarStudioColors.panel,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 39,
                        left: 14,
                        right: 12,
                        child: _buildHeader(),
                      ),
                      Positioned(
                        top: 184,
                        left: 0,
                        right: 0,
                        child: _buildPreview(),
                      ),
                      const Positioned(
                        top: 423,
                        left: 0,
                        right: 0,
                        child: Center(child: _LivePreviewPill()),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 232,
                        child: _buildEditorSheet(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      key: const Key('avatar-studio-header'),
      height: 44,
      child: Row(
        children: [
          Material(
            color: _AvatarStudioColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const Key('avatar-studio-back'),
              onTap: _back,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: _AvatarStudioColors.body,
                  semanticLabel: 'Back',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 18,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Avatar Studio',
                      style: TextStyle(
                        color: _AvatarStudioColors.cream,
                        fontSize: 16,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 5),
                SizedBox(
                  height: 10,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Create your market look',
                      style: TextStyle(
                        color: _AvatarStudioColors.muted,
                        fontSize: 8,
                        height: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: const Color(0xFF453039),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const Key('avatar-studio-reset'),
              onTap: _reset,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 57,
                height: 36,
                child: Center(
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: _AvatarStudioColors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Center(
      child: SizedBox(
        key: const Key('avatar-preview-halo'),
        width: 176,
        height: 176,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _AvatarStudioColors.orange.withValues(alpha: .16),
            ),
            gradient: RadialGradient(
              colors: [
                _AvatarStudioColors.orange.withValues(alpha: .12),
                Colors.transparent,
              ],
              stops: const [.48, 1],
            ),
          ),
          child: Center(
            child: Container(
              key: const Key('avatar-preview'),
              width: 128,
              height: 128,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFB24E), Color(0xFFE956A8)],
                ),
              ),
              child: ClipOval(
                child: CustomPaint(
                  painter: AvatarPainter(hairStyle: _selectedHair),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorSheet() {
    return Container(
      key: const Key('avatar-editor-sheet'),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF34334F), Color(0xFF29283F)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _AvatarStudioColors.border),
      ),
      child: Column(
        children: [
          _buildTabs(),
          const SizedBox(height: 18),
          _buildOptions(),
          const SizedBox(height: 15),
          _buildSaveButton(),
          const SizedBox(height: 10),
          const Text(
            'You can change your look anytime from Profile',
            style: TextStyle(
              color: _AvatarStudioColors.muted,
              fontSize: 8,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      key: const Key('avatar-category-tabs'),
      height: 43,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _AvatarStudioColors.surfaceDark,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final selected = index == _selectedTab;
          return Expanded(
            child: GestureDetector(
              key: Key('avatar-tab-$index'),
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? _AvatarStudioColors.orange
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    color:
                        selected
                            ? _AvatarStudioColors.cream
                            : _AvatarStudioColors.muted,
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOptions() {
    return SizedBox(
      key: const Key('avatar-hair-options'),
      height: 58,
      child: Row(
        children: List.generate(4, (index) {
          final selected = index == _selectedHair;
          return Expanded(
            child: Align(
              alignment:
                  index == 0
                      ? Alignment.centerLeft
                      : index == 3
                      ? Alignment.centerRight
                      : Alignment.center,
              child: GestureDetector(
                key: Key('avatar-option-$index'),
                onTap: () => setState(() => _selectedHair = index),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      key:
                          selected
                              ? Key('avatar-option-$index-selected')
                              : null,
                      width: 58,
                      height: 58,
                      padding: EdgeInsets.all(selected ? 3 : 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _AvatarStudioColors.cream,
                        border: Border.all(
                          color:
                              selected
                                  ? _AvatarStudioColors.orange
                                  : const Color(0xFFE5D9D3),
                          width: selected ? 3 : 2,
                        ),
                      ),
                      child: ClipOval(
                        child: CustomPaint(
                          painter: AvatarPainter(hairStyle: index),
                        ),
                      ),
                    ),
                    if (selected)
                      const Positioned(
                        top: -3,
                        right: -3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _AvatarStudioColors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('save-avatar-button'),
        onTap: _save,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_AvatarStudioColors.orange, _AvatarStudioColors.gold],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _AvatarStudioColors.orange.withValues(alpha: .32),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'SAVE MY AVATAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LivePreviewPill extends StatelessWidget {
  const _LivePreviewPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('live-preview-pill'),
      width: 80,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _AvatarStudioColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF484665)),
      ),
      child: const Text(
        'Live preview',
        style: TextStyle(
          color: _AvatarStudioColors.body,
          fontSize: 8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class AvatarPainter extends CustomPainter {
  const AvatarPainter({required this.hairStyle});

  final int hairStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.scale(scale, scale);

    final background = Paint()..color = const Color(0xFFFFE49D);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), background);

    final shirt = Paint()..color = const Color(0xFFFF6243);
    canvas.drawOval(const Rect.fromLTWH(8, 72, 84, 52), shirt);

    final skin = Paint()..color = const Color(0xFFC97546);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 24, 44, 70),
        const Radius.circular(22),
      ),
      skin,
    );
    canvas.drawCircle(const Offset(27, 58), 6, skin);
    canvas.drawCircle(const Offset(73, 58), 6, skin);

    _paintHair(canvas);

    final eye = Paint()..color = const Color(0xFF2A1B15);
    canvas.drawCircle(const Offset(40, 58), 2.5, eye);
    canvas.drawCircle(const Offset(60, 58), 2.5, eye);

    final nose =
        Paint()
          ..color = const Color(0xFFA65134)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 61), const Offset(48, 68), nose);

    final smile =
        Paint()
          ..color = const Color(0xFF7F3E2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTWH(42, 68, 16, 9),
      .2,
      math.pi - .4,
      false,
      smile,
    );

    canvas.restore();
  }

  void _paintHair(Canvas canvas) {
    final colors = <Color>[
      const Color(0xFF241913),
      const Color(0xFF4B2A1D),
      const Color(0xFF171210),
      const Color(0xFFF3547C),
    ];
    final paint = Paint()..color = colors[hairStyle.clamp(0, 3)];

    switch (hairStyle) {
      case 1:
        canvas.drawArc(
          const Rect.fromLTWH(24, 17, 52, 43),
          math.pi,
          math.pi,
          true,
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 31, 44, 15),
            const Radius.circular(7),
          ),
          paint,
        );
        break;
      case 2:
        canvas.drawOval(const Rect.fromLTWH(23, 16, 54, 52), paint);
        final faceCut = Paint()..color = const Color(0xFFC97546);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(31, 33, 38, 50),
            const Radius.circular(18),
          ),
          faceCut,
        );
        canvas.drawRect(const Rect.fromLTWH(25, 48, 8, 34), paint);
        canvas.drawRect(const Rect.fromLTWH(67, 48, 8, 34), paint);
        break;
      case 3:
        canvas.drawArc(
          const Rect.fromLTWH(23, 16, 54, 43),
          math.pi,
          math.pi,
          true,
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(25, 31, 50, 13),
            const Radius.circular(6),
          ),
          paint,
        );
        break;
      default:
        canvas.drawArc(
          const Rect.fromLTWH(24, 16, 52, 48),
          math.pi,
          math.pi,
          true,
          paint,
        );
        canvas.drawRect(const Rect.fromLTWH(28, 34, 44, 14), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant AvatarPainter oldDelegate) =>
      oldDelegate.hairStyle != hairStyle;
}
