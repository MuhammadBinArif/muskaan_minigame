import 'package:flutter/material.dart';
import '../../data/player_profile_repository.dart';
import '../../../game/data/records_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:muskaan_minigame/features/ads/ad_service.dart';
import 'package:muskaan_minigame/shared/widgets/app_bottom_nav.dart';
import 'package:muskaan_minigame/features/progression/application/progression_service.dart';
import 'package:muskaan_minigame/features/progression/domain/player_progression.dart';

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
  static const List<String> _avatarOptions = <String>[
    '🥷',
    '🧑🏽‍🦱',
    '👨🏾',
    '👩🏽',
    '👩🏻',
  ];

  late final TextEditingController _nameController;
  bool _editingName = false;
  int get _selectedAvatar => _avatarOptions.indexOf(
    ref.watch(playerProfileProvider).asData?.value.avatar ?? '',
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(playerProfileProvider).asData?.value.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _toggleNameEditing() async {
    if (!_editingName) {
      _nameController.text =
          ref.read(playerProfileProvider).requireValue.displayName;
      setState(() => _editingName = true);
      return;
    }
    try {
      await ref
          .read(playerProfileProvider.notifier)
          .update(name: _nameController.text);
      if (mounted) setState(() => _editingName = false);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Unable to save name. Please try again.',
            ),
          ),
        );
    }
  }

  Future<void> _selectAvatar(int index) async {
    await _saveAvatar(_avatarOptions[index]);
  }

  Future<void> _saveAvatar(String symbol) async {
    try {
      await ref.read(playerProfileProvider.notifier).update(avatar: symbol);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save avatar. Please try again.'),
          ),
        );
    }
  }

  Future<void> _openAvatarStudio() async {
    final profile = ref.read(playerProfileProvider).requireValue;
    PlayerProgression progression;
    try {
      progression = await ref
          .read(progressionServiceProvider)
          .synchronize(profile.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Avatar options could not be loaded. Please try again.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Avatar Studio',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final cosmetic in progression.cosmetics)
                            _CosmeticChoice(
                              cosmetic: cosmetic,
                              selected: profile.avatar == cosmetic.item.symbol,
                              onTap:
                                  cosmetic.unlocked
                                      ? () async {
                                        if (!await ref
                                            .read(progressionServiceProvider)
                                            .canEquip(
                                              profile.id,
                                              cosmetic.item.symbol,
                                            )) {
                                          return;
                                        }
                                        await _saveAvatar(cosmetic.item.symbol);
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      }
                                      : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _saveAvatar(_avatarOptions.first);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Reset avatar'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProfileProvider);
    if (!profile.hasValue)
      return Scaffold(
        body: Center(
          child:
              profile.isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                    'Your profile could not be read. Saved data has been preserved. Restart to retry.',
                  ),
        ),
      );
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
                                const SizedBox(height: 12),
                                _buildPlayerProgressCard(),
                                const SizedBox(height: 12),
                                _buildDailyChallengesCard(),
                                const SizedBox(height: 12),
                                _buildSmileAnalyticsCard(),
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
          _AvatarPortrait(
            symbol:
                ref.watch(playerProfileProvider).asData?.value.avatar ?? '🥷',
            size: 64,
            selected: true,
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
                  'Local player',
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
                  'Build your own game history',
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
                    ref
                            .watch(playerProfileProvider)
                            .asData
                            ?.value
                            .displayName ??
                        'Player unavailable',
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
    final profile = ref.watch(playerProfileProvider).asData?.value;
    final records =
        (ref.watch(allRecordsStreamProvider).asData?.value ?? [])
            .where((r) => profile != null && r.playerId == profile.id)
            .toList();
    final best = records.fold<int>(
      0,
      (best, r) => r.score > best ? r.score : best,
    );
    final combo = records.fold<int>(
      0,
      (best, r) => r.bestCombo > best ? r.bestCombo : best,
    );
    final values = <(String, String)>[
      ('$best', 'Best score'),
      ('x$combo', 'Best combo'),
      ('${records.length}', 'Rounds'),
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
            child: Semantics(
              button: true,
              label: 'Open avatar studio',
              child: InkWell(
                onTap: _openAvatarStudio,
                child: Container(
                  key: const Key('open-avatar-studio'),
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

  Widget _buildSmileAnalyticsCard() {
    return Semantics(
      button: true,
      label: 'Open Smile Analytics',
      child: Material(
        color: _ProfileColors.card,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          key: const Key('open-smile-analytics'),
          onTap: () => context.push('/smile-analytics'),
          borderRadius: BorderRadius.circular(13),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.insights_rounded, color: _ProfileColors.gold),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smile Analytics',
                        style: TextStyle(
                          color: _ProfileColors.cream,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Explore your private measured-round history',
                        style: TextStyle(
                          color: _ProfileColors.muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: _ProfileColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard() {
    return Material(
      key: const Key('profile-achievement-card'),
      color: _ProfileColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push('/achievements'),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 57,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color(0x1AFFD83D),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Icon(
                    Icons.star_border_rounded,
                    size: 18,
                    color: _ProfileColors.gold,
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
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
                        'View verified badges and progress',
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
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: _ProfileColors.muted,
                ),
              ],
            ),
          ),
        ),
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

  Widget _buildDailyChallengesCard() => Material(
    color: _ProfileColors.card,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      key: const Key('open-daily-challenges'),
      onTap: () => context.push('/challenges'),
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Text('🔥', style: TextStyle(fontSize: 23)),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Challenges',
                    style: TextStyle(
                      color: _ProfileColors.cream,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Build your verified activity streak',
                    style: TextStyle(color: _ProfileColors.muted, fontSize: 9),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _ProfileColors.muted),
          ],
        ),
      ),
    ),
  );

  Widget _buildPlayerProgressCard() => Material(
    color: _ProfileColors.card,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      key: const Key('open-player-progress'),
      onTap: () => context.push('/player-progress'),
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: _ProfileColors.gold),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Player Progress',
                    style: TextStyle(
                      color: _ProfileColors.cream,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Levels, XP and cosmetic unlocks',
                    style: TextStyle(color: _ProfileColors.muted, fontSize: 9),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _ProfileColors.muted),
          ],
        ),
      ),
    ),
  );
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
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(fontSize: size * .55, height: 1),
          ),
        ),
      ),
    );
  }
}

class _CosmeticChoice extends StatelessWidget {
  const _CosmeticChoice({
    required this.cosmetic,
    required this.selected,
    required this.onTap,
  });
  final CosmeticProgress cosmetic;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: cosmetic.unlocked,
    label:
        '${cosmetic.item.name}, ${cosmetic.unlocked ? 'unlocked' : 'locked'}, ${ProgressionService.rules.requirement(cosmetic)}, ${ProgressionService.rules.progress(cosmetic)}',
    child: Tooltip(
      message: 'Choose avatar ${cosmeticCatalog.indexOf(cosmetic.item) + 1}',
      child: SizedBox(
        width: 105,
        child: Material(
          color: selected ? const Color(0x33FFD83D) : const Color(0x11000000),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Text(
                        cosmetic.item.symbol,
                        style: TextStyle(
                          fontSize: 34,
                          color: cosmetic.unlocked ? null : Colors.grey,
                        ),
                      ),
                      if (!cosmetic.unlocked)
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(Icons.lock, size: 16),
                        ),
                    ],
                  ),
                  Text(
                    cosmetic.item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  Text(
                    cosmetic.unlocked
                        ? cosmetic.item.isDefault
                            ? 'Default'
                            : 'Unlocked'
                        : '${ProgressionService.rules.requirement(cosmetic)}\n${ProgressionService.rules.progress(cosmetic)}',
                    maxLines: 3,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9),
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
              widthFactor: 0,
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
