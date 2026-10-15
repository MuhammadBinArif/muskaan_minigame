import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared bottom navigation used by every top-level screen.
///
/// - Uses named routes only — no user-supplied path segments.
/// - Stateless; no data is stored or logged here.
class AppBottomNav extends StatelessWidget {
  /// 0 = Home, 1 = Challenges, 2 = Games, 3 = Smile, 4 = Profile
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  static const Color _bg = Color(0xFF14111E);
  static const Color _active = Color(0xFFFF6B35);
  static const Color _inactive = Color(0xFF6E6E6E);

  static const List<_NavSpec> _items = <_NavSpec>[
    _NavSpec(icon: Icons.home, label: 'Home', route: '/home'),
    _NavSpec(
      icon: Icons.emoji_events,
      label: 'Challenges',
      route: '/challenges',
    ),
    _NavSpec(icon: Icons.sports_esports, label: 'Games', route: '/games'),
    _NavSpec(icon: Icons.emoji_emotions, label: 'Smile', route: '/filmi-smile'),
    _NavSpec(icon: Icons.person, label: 'Profile', route: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List<Widget>.generate(_items.length, (i) {
          final item = _items[i];
          final isActive = i == currentIndex;
          final color = isActive ? _active : _inactive;
          return InkWell(
            onTap: () {
              // Named route only — safe against injection.
              if (!isActive) context.go(item.route);
            },
            child: Semantics(
              button: true,
              selected: isActive,
              label: item.label,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: color, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: _active,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavSpec {
  final IconData icon;
  final String label;
  final String route;
  const _NavSpec({
    required this.icon,
    required this.label,
    required this.route,
  });
}
