import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:muskaan_minigame/features/ads/ad_service.dart';
import 'package:muskaan_minigame/shared/widgets/app_bottom_nav.dart';
import '../../domain/profile_avatar.dart';
import 'avatar_studio_screen.dart' show AvatarPainter;

class _ProfileColors {
  static const page = Color(0xFF100C14);
  static const panelTop = Color(0xFF211F32);
  static const panelBottom = Color(0xFF1C1A2B);
  static const card = Color(0xFF2A2945);
  static const cardDark = Color(0xFF24233B);
  static const identityTop = Color(0xFF3B3440);
  static const identityBottom = Color(0xFF29283E);
  static const orange = Color(0xFFFF6332);
  static const gold = Color(0xFFFFD83D);
  static const cream = Color(0xFFFFF7EC);
  static const body = Color(0xFFC9C5D4);
  static const muted = Color(0xFF8D899E);
  static const track = Color(0xFF19172D);
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    this.isNewUser = false,
    this.showAchievementToast = false,
  });

  final bool isNewUser;
  final bool showAchievementToast;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const List<String> _avatarOptions = ProfileAvatar.options;

  late final TextEditingController _nameController;
  bool _editingName = false;
  int _selectedAvatar = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.isNewUser ? 'PlayerName' : 'Arjun Khan',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleNameEditing() {
    setState(() => _editingName = !_editingName);
  }

  Future<void> _selectAvatar(int index) async {
    final repository = ref.read(profileAvatarRepositoryProvider);
    if (repository is! WritableProfileAvatarRepository) return;
    try {
      await repository.selectAvatar(ProfileAvatar(_avatarOptions[index]));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save avatar. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ref.watch(profileAvatarProvider).asData?.value;
    final savedIndex = _avatarOptions.indexOf(avatar?.symbol ?? '');
    if (savedIndex >= 0) _selectedAvatar = savedIndex;
    return Scaffold(
      backgroundColor: _ProfileColors.page,
      body: SafeArea(
        minimum: const EdgeInsets.fromLTRB(9, 6, 8, 0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: DecoratedBox(
                key: const Key('profile-panel'),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _ProfileColors.panelTop,
                      _ProfileColors.panelBottom,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 42, 14, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(),
                                const SizedBox(height: 11),
                                _buildIdentityCard(),
                                const SizedBox(height: 12),
                                _buildStats(),
                                const SizedBox(height: 12),
                                _buildAvatarCard(),
                                const SizedBox(height: 12),
                                _buildAchievementCard(),
                                if (ref
                                    .read(adServiceProvider)
                                    .privacyOptionsRequired) ...[
                                  const SizedBox(height: 8),
                                  _buildPrivacyButton(),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const AppBottomNav(currentIndex: 4, compact: true),
                      ],
                    ),
                    if (widget.showAchievementToast)
                      const Positioned(
                        top: 10,
                        left: 18,
                        right: 18,
                        child: _AchievementToast(),
                      ),
                  ],
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
      key: const Key('profile-header'),
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLAYER HUB',
                  style: TextStyle(
                    color: _ProfileColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'My Profile',
                  style: TextStyle(
                    color: _ProfileColors.cream,
                    fontSize: 17,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: _ProfileColors.card,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const Key('profile-settings'),
              onTap: () => context.push('/settings'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF44415F)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.settings_outlined,
                  color: _ProfileColors.body,
                  size: 18,
                  semanticLabel: 'Settings',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Container(
      key: const Key('profile-identity-card'),
      height: 109,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ProfileColors.identityTop, _ProfileColors.identityBottom],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _ProfileColors.orange.withValues(alpha: .58)),
      ),
      child: Row(
        children: [
          KeyedSubtree(
            key: Key('profile-selected-avatar-$_selectedAvatar'),
            child: _AvatarPortrait(
              symbol: _avatarOptions[_selectedAvatar],
              size: 64,
              selected: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNameRow(),
                const SizedBox(height: 5),
                const Text(
                  'Street Snacker · Level 12',
                  style: TextStyle(
                    color: _ProfileColors.body,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 11),
                const _XpProgress(),
                const SizedBox(height: 5),
                const Text(
                  '360 XP to level 13',
                  style: TextStyle(
                    color: _ProfileColors.muted,
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameRow() {
    return Row(
      children: [
        Expanded(
          child:
              _editingName
                  ? SizedBox(
                    height: 26,
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      cursorColor: _ProfileColors.orange,
                      style: const TextStyle(
                        color: _ProfileColors.cream,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 3),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: _ProfileColors.orange),
                        ),
                      ),
                    ),
                  )
                  : Text(
                    _nameController.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ProfileColors.cream,
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleNameEditing,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 28,
              height: 28,
              child: Icon(
                _editingName ? Icons.check : Icons.edit_outlined,
                color:
                    _editingName ? _ProfileColors.gold : _ProfileColors.muted,
                size: 15,
                semanticLabel: _editingName ? 'Save name' : 'Edit name',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final values =
        widget.isNewUser
            ? const <(String, String)>[
              ('—', 'Best score'),
              ('—', 'Best combo'),
              ('—', 'Hot streak'),
            ]
            : const <(String, String)>[
              ('12,480', 'Best score'),
              ('x8', 'Best combo'),
              ('7 days', 'Hot streak'),
            ];

    return SizedBox(
      key: const Key('profile-stats'),
      height: 55,
      child: Row(
        children: [
          for (int i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _ProfileColors.card,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFF34334F)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      values[i].$1,
                      style: const TextStyle(
                        color: _ProfileColors.gold,
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      values[i].$2,
                      style: const TextStyle(
                        color: _ProfileColors.muted,
                        fontSize: 8,
                        height: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarCard() {
    return Container(
      key: const Key('profile-avatar-card'),
      height: 188,
      padding: const EdgeInsets.fromLTRB(13, 15, 13, 12),
      decoration: BoxDecoration(
        color: _ProfileColors.card,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Make it yours',
                  style: TextStyle(
                    color: _ProfileColors.cream,
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.palette_outlined,
                color: _ProfileColors.orange,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Pick a look or build your own avatar',
            style: TextStyle(
              color: _ProfileColors.muted,
              fontSize: 9,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 61,
            child: Row(
              children: [
                for (int i = 0; i < _avatarOptions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectAvatar(i),
                      child: _AvatarPortrait(
                        symbol: _avatarOptions[i],
                        size: 61,
                        selected: i == _selectedAvatar,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 11),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('open-avatar-studio'),
                onTap: () async {
                  final selected = await context.push<int>('/avatar-studio');
                  if (mounted && selected != null) {
                    await _selectAvatar(selected.clamp(0, 3));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ProfileColors.orange),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        color: _ProfileColors.orange,
                        size: 17,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'OPEN AVATAR STUDIO',
                        style: TextStyle(
                          color: _ProfileColors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard() {
    return Container(
      key: const Key('profile-achievement-card'),
      height: 57,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _ProfileColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _ProfileColors.gold.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.star_border_rounded,
              size: 18,
              color: _ProfileColors.gold,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Achievements',
                  style: TextStyle(
                    color: _ProfileColors.cream,
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '14 of 30 unlocked',
                  style: TextStyle(
                    color: _ProfileColors.muted,
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: _ProfileColors.muted,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyButton() {
    return TextButton(
      onPressed: () async {
        final shown = await ref.read(adServiceProvider).showPrivacyOptions();
        if (!shown && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Privacy choices are unavailable. Please try again.',
              ),
            ),
          );
        }
      },
      child: const Text('Advertising privacy choices'),
    );
  }
}

class _AvatarPortrait extends StatelessWidget {
  const _AvatarPortrait({
    required this.symbol,
    required this.size,
    required this.selected,
  });

  final String symbol;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                selected
                    ? const [Color(0xFFFFD16A), Color(0xFFFF7A52)]
                    : const [Color(0xFFFFE08B), Color(0xFF8D6DEB)],
          ),
          border: Border.all(
            color: selected ? _ProfileColors.orange : const Color(0xFFE7DEFF),
            width: selected ? 3 : 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ClipOval(
            child: CustomPaint(
              painter: AvatarPainter(
                hairStyle: ProfileAvatar.options.indexOf(symbol).clamp(0, 3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _XpProgress extends StatelessWidget {
  const _XpProgress();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: _ProfileColors.track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: .72,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_ProfileColors.orange, _ProfileColors.gold],
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

class _AchievementToast extends StatelessWidget {
  const _AchievementToast();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _ProfileColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ProfileColors.gold.withValues(alpha: .5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.emoji_events, color: _ProfileColors.gold, size: 22),
          SizedBox(width: 10),
          Text(
            'Achievement unlocked · 100 Catches',
            style: TextStyle(
              color: _ProfileColors.cream,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
