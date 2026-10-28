import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _SettingsColors {
  static const page = Color(0xFF100C14);
  static const panel = Color(0xFF202033);
  static const card = Color(0xFF2A2947);
  static const iconBg = Color(0xFF49313E);
  static const divider = Color(0xFF3A3854);
  static const cream = Color(0xFFFFF7EC);
  static const body = Color(0xFFC8C4D2);
  static const muted = Color(0xFF8D899D);
  static const orange = Color(0xFFFF6842);
  static const gold = Color(0xFFFFE026);
  static const green = Color(0xFF39C985);
  static const switchOff = Color(0xFF5E5D79);
  static const sliderTrack = Color(0xFF17162C);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEffects = true;
  bool _marketMusic = true;
  bool _hapticFeedback = true;
  bool _gameReminders = false;
  double _volume = .72;

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SettingsColors.page,
      body: SafeArea(
        minimum: const EdgeInsets.only(right: 2),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: ColoredBox(
                  key: const Key('settings-panel'),
                  color: _SettingsColors.panel,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 34, 14, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        const _SectionLabel(
                          key: Key('sound-section-label'),
                          text: 'SOUND & FEEL',
                        ),
                        const SizedBox(height: 7),
                        _buildSoundCard(),
                        const SizedBox(height: 13),
                        const _SectionLabel(
                          key: Key('privacy-section-label'),
                          text: 'GAMEPLAY & PRIVACY',
                        ),
                        const SizedBox(height: 6),
                        _buildGameplayCard(),
                        const SizedBox(height: 12),
                        const _PrivacyNote(),
                      ],
                    ),
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
      key: const Key('settings-header'),
      height: 45,
      child: Row(
        children: [
          Material(
            color: _SettingsColors.card,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const Key('settings-back'),
              onTap: _goBack,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 44,
                height: 45,
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: _SettingsColors.body,
                  size: 20,
                  semanticLabel: 'Back',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: _SettingsColors.cream,
                    fontSize: 17,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tune your game your way',
                  style: TextStyle(
                    color: _SettingsColors.muted,
                    fontSize: 9,
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

  Widget _buildSoundCard() {
    return Container(
      key: const Key('sound-settings-card'),
      height: 231,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _SettingsColors.card,
        borderRadius: BorderRadius.circular(15),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF33314F)),
      ),
      child: Column(
        children: [
          _ToggleRow(
            icon: Icons.volume_up_outlined,
            title: 'Sound effects',
            subtitle: 'Catches, combos and hazards',
            value: _soundEffects,
            onChanged: (value) => setState(() => _soundEffects = value),
          ),
          const _InsetDivider(),
          _ToggleRow(
            icon: Icons.music_note_rounded,
            title: 'Market music',
            subtitle: 'Background soundtrack',
            value: _marketMusic,
            onChanged: (value) => setState(() => _marketMusic = value),
          ),
          const _InsetDivider(),
          _ToggleRow(
            icon: Icons.vibration_rounded,
            title: 'Haptic feedback',
            subtitle: 'Vibrate on catches and misses',
            value: _hapticFeedback,
            onChanged: (value) => setState(() => _hapticFeedback = value),
          ),
          const _InsetDivider(),
          SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Master volume',
                        style: TextStyle(
                          color: _SettingsColors.body,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${(_volume * 100).round()}%',
                      style: const TextStyle(
                        color: _SettingsColors.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                _VolumeSlider(
                  value: _volume,
                  onChanged: (value) => setState(() => _volume = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameplayCard() {
    return Container(
      key: const Key('gameplay-settings-card'),
      height: 211,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _SettingsColors.card,
        borderRadius: BorderRadius.circular(15),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF33314F)),
      ),
      child: Column(
        children: [
          _ToggleRow(
            icon: Icons.notifications_none_rounded,
            title: 'Game reminders',
            subtitle: 'Daily battle and streak alerts',
            value: _gameReminders,
            onChanged: (value) => setState(() => _gameReminders = value),
          ),
          const _InsetDivider(),
          const _ChoiceRow(
            icon: Icons.camera_alt_outlined,
            iconColor: _SettingsColors.gold,
            title: 'Camera & face tracking',
            subtitle: 'On-device processing',
            value: 'Allowed',
          ),
          const _InsetDivider(),
          const _ChoiceRow(
            icon: Icons.language_rounded,
            iconColor: _SettingsColors.gold,
            title: 'Language',
            subtitle: 'App display language',
            value: 'English',
          ),
          const _InsetDivider(),
          const _ChoiceRow(
            icon: Icons.accessibility_new_rounded,
            iconColor: _SettingsColors.gold,
            title: 'Accessibility',
            subtitle: 'Motion, contrast and captions',
            value: 'Default',
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: _SettingsColors.orange,
            fontSize: 9,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.icon, this.color = _SettingsColors.orange});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _SettingsColors.iconBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _SettingIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(child: _SettingCopy(title: title, subtitle: subtitle)),
          _CompactSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _SettingIcon(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: _SettingCopy(title: title, subtitle: subtitle)),
          Text(
            value,
            style: const TextStyle(
              color: _SettingsColors.body,
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 9),
          const Icon(
            Icons.chevron_right_rounded,
            color: _SettingsColors.muted,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _SettingCopy extends StatelessWidget {
  const _SettingCopy({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _SettingsColors.cream,
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _SettingsColors.muted,
            fontSize: 8,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 44),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: _SettingsColors.divider),
      ),
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  const _CompactSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 24,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? _SettingsColors.orange : _SettingsColors.switchOff,
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: const SizedBox.square(
              dimension: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(double dx) {
          onChanged((dx / constraints.maxWidth).clamp(0.0, 1.0));
        }

        return Semantics(
          slider: true,
          value: '${(value * 100).round()} percent',
          child: GestureDetector(
            key: const Key('master-volume-slider'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => update(details.localPosition.dx),
            onHorizontalDragUpdate:
                (details) => update(details.localPosition.dx),
            child: SizedBox(
              height: 18,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: _SettingsColors.sliderTrack,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: _SettingsColors.orange,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Positioned(
                    left: value * (constraints.maxWidth - 18),
                    child: Container(
                      width: 18,
                      height: 18,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _SettingsColors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _SettingsColors.orange.withValues(alpha: .4),
                            blurRadius: 7,
                          ),
                        ],
                      ),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: _SettingsColors.cream,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: Key('camera-privacy-note'),
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: _SettingsColors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Camera video is never recorded or uploaded.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _SettingsColors.muted,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
