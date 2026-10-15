import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';

// ============================================================
// THEME
// ============================================================
class _C {
  static const bgTop = Color(0xFF14122A);
  static const bgBot = Color(0xFF07060F);

  static const card = Color(0xFF1E1B33);
  static const cardSoft = Color(0xFF262243);
  static const border = Color(0x22FFFFFF);

  static const orange = Color(0xFFFF7A1A);
  static const orangeGlow = Color(0xFFFFB45C);
  static const gold = Color(0xFFFFD86B);
  static const green = Color(0xFF3DD68C);

  static const cream = Color(0xFFFDF5E6);
  static const textSoft = Color(0xFFC7C3D6);
  static const textDim = Color(0xFF8E8AA0);

  static const lockedBg = Color(0xFF14122A);
}

class _T {
  static const page = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: _C.cream,
  );
  static const name = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: _C.cream,
  );
  static const welcome = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: _C.cream,
  );
  static const handle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: _C.textDim,
  );
  static const levelPill = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: _C.gold,
    letterSpacing: 1.0,
  );
  static const statValue = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: _C.gold,
  );
  static const statLabel = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: _C.textDim,
    letterSpacing: 1.5,
  );
  static const sectionTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: _C.textSoft,
    letterSpacing: 1.2,
  );
  static const viewAll = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: _C.orange,
  );
  static const achLabel = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: _C.textDim,
  );
  static const progressLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: _C.textSoft,
  );
  static const progressValue = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: _C.gold,
  );
  static const tooltip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: _C.cream,
  );
  static const toast = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: _C.gold,
    letterSpacing: 1.5,
  );
  static const toastValue = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: _C.cream,
  );
}

// ============================================================
// SCREEN
// ============================================================
class ProfileScreen extends StatefulWidget {
  /// When true, the "New User" layout is shown (Screens 07).
  final bool isNewUser;

  /// When true, the achievement toast is shown (Screen 09).
  final bool showAchievementToast;

  const ProfileScreen({
    super.key,
    this.isNewUser = false,
    this.showAchievementToast = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editingName = false;
  late final TextEditingController _nameController;

  // Demo stats.
  static const int _bestScore = 9480;
  static const int _games = 47;
  static const int _winRate = 68;
  static const int _level = 12;
  static const int _levelProgress = 12;
  static const int _levelTotal = 13;
  static const int _currentXp = 2450;
  static const int _totalXp = 5000;

  // Achievements: title + emoji + unlocked.
  static const List<_Ach> _achievements = <_Ach>[
    _Ach(label: 'First Catch', emoji: '🎯', unlocked: true),
    _Ach(label: 'Combo Master', emoji: '⚡', unlocked: true),
    _Ach(label: '100 Catches', emoji: '🏆', unlocked: true),
    _Ach(label: 'Perfect Games', emoji: '🔒', unlocked: false),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.isNewUser ? 'PlayerName' : 'Blaven Name',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  void _toggleEdit() {
    setState(() => _editingName = !_editingName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgBot,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.bgTop, _C.bgBot],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // ---- Scrollable content ----
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildAvatarRow(),
                    const SizedBox(height: 16),
                    if (widget.isNewUser) ...[
                      _buildNewUserTooltip(),
                      const SizedBox(height: 20),
                    ],
                    _buildStats(),
                    const SizedBox(height: 20),
                    _buildAchievements(),
                    const SizedBox(height: 20),
                    _buildLevelProgress(),
                  ],
                ),
              ),

              // ---- Achievement toast ----
              if (widget.showAchievementToast)
                Positioned(
                  top: 8,
                  left: 20,
                  right: 20,
                  child: _AchievementToast(),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(child: Text('PROFILE', style: _T.page)),
        Semantics(
          button: true,
          label: 'Settings',
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _C.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.orange.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.settings, size: 16, color: _C.orange),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Avatar + name + level
  // ---------------------------------------------------------------------------
  Widget _buildAvatarRow() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_C.orangeGlow, _C.orange],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.orange.withValues(alpha: 0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                '🥷',
                style: TextStyle(fontSize: 52, height: 1.0),
              ),
            ),
            // Level badge
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.gold,
                border: Border.all(color: _C.bgBot, width: 3),
              ),
              child: Text(
                '$_level',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3B2A00),
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Name (editable when _editingName)
        _buildNameRow(),

        const SizedBox(height: 4),
        const Text('@player_123', style: _T.handle),
        const SizedBox(height: 8),
        _buildLevelPill(),
      ],
    );
  }

  Widget _buildNameRow() {
    if (widget.isNewUser && !_editingName) {
      return const Text('Welcome Blaven!', style: _T.welcome);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_editingName)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _C.cardSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.orange.withValues(alpha: 0.6)),
            ),
            child: IntrinsicWidth(
              child: TextField(
                controller: _nameController,
                autofocus: true,
                textAlign: TextAlign.center,
                cursorColor: _C.orange,
                style: _T.name,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
          )
        else
          Text(_nameController.text, style: _T.name),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: _editingName ? 'Save name' : 'Edit name',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _toggleEdit,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _editingName
                      ? _C.green.withValues(alpha: 0.15)
                      : _C.cardSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _editingName ? Icons.check : Icons.edit,
                  size: 14,
                  color: _editingName ? _C.green : _C.textSoft,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _C.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 10, height: 1.0)),
          const SizedBox(width: 6),
          Text(
            'LEVEL $_level  ·  $_levelProgress / $_levelTotal',
            style: _T.levelPill,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // New-user tooltip
  // ---------------------------------------------------------------------------
  Widget _buildNewUserTooltip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.cardSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 14, height: 1.0)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Catch your first gol gappa to begin your journey!',
              style: _T.tooltip,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------
  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStat(
            value: widget.isNewUser ? '—' : _fmt(_bestScore),
            label: 'BEST SCORE',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStat(
            value: widget.isNewUser ? '—' : '$_games',
            label: 'GAMES',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStat(
            value: widget.isNewUser ? '—' : '$_winRate%',
            label: 'WIN RATE',
          ),
        ),
      ],
    );
  }

  Widget _buildStat({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: _T.statValue),
          const SizedBox(height: 4),
          Text(label, style: _T.statLabel),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Achievements
  // ---------------------------------------------------------------------------
  Widget _buildAchievements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('ACHIEVEMENTS', style: _T.sectionTitle)),
            GestureDetector(
              onTap: () {},
              child: const Text('View All →', style: _T.viewAll),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(_achievements.length, (i) {
            final a = _achievements[i];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i < _achievements.length - 1 ? 8 : 0,
                ),
                child: _buildAchTile(a),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildAchTile(_Ach a) {
    final unlocked = a.unlocked;
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: unlocked ? _C.orange.withValues(alpha: 0.15) : _C.lockedBg,
            border: Border.all(
              color: unlocked ? _C.orange.withValues(alpha: 0.5) : _C.border,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: _C.orange.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            a.emoji,
            style: const TextStyle(fontSize: 20, height: 1.0),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          a.label,
          style: _T.achLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Level progress + daily streak
  // ---------------------------------------------------------------------------
  Widget _buildLevelProgress() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('LEVEL PROGRESS', style: _T.progressLabel),
              ),
              Text(
                '${_fmt(_currentXp)} / ${_fmt(_totalXp)} XP',
                style: _T.progressValue,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProgressBar(fraction: _currentXp / _totalXp),
          const SizedBox(height: 16),
          const Text('DAILY STREAK', style: _T.progressLabel),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final done = i < 3;
              return Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? _C.orange.withValues(alpha: 0.9) : _C.cardSoft,
                  border: Border.all(color: done ? _C.orangeGlow : _C.border),
                ),
                child: Text(
                  ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: done ? Colors.white : _C.textDim,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Achievement toast
// ============================================================
class _AchievementToast extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.cardSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.gold.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: _C.gold.withValues(alpha: 0.20), blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _C.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '🏆',
              style: TextStyle(fontSize: 18, height: 1.0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('ACHIEVEMENT UNLOCKED', style: _T.toast),
                SizedBox(height: 2),
                Text('100 Catches', style: _T.toastValue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Progress bar
// ============================================================
class _ProgressBar extends StatelessWidget {
  final double fraction;

  const _ProgressBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF14122A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(colors: [_C.orange, _C.gold]),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Data
// ============================================================
class _Ach {
  final String label;
  final String emoji;
  final bool unlocked;

  const _Ach({
    required this.label,
    required this.emoji,
    required this.unlocked,
  });
}
