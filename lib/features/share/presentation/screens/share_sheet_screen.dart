import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:muskaan_minigame/shared/widgets/soap_bubble.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color overlay = Color(0x8C000000); // black @ 55%
  static const Color sheetBg = Color(0xFF2D2D4A);
  static const Color sheetBorder = Color(0x0FFFFFFF); // white @ 6%
  static const Color dragHandle = Color(0xFF4D4D6A);

  static const Color previewBgStart = Color(0xFF1A1A2E);
  static const Color previewBgMid = Color(0xFF2D1A0E);
  static const Color previewBgEnd = Color(0xFF1A1A2E);
  static const Color previewBorder = Color(0x4DFF6B35); // orange @ 30%

  static const Color messageBg = Color(0xFF1A1A2E);

  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color mutedGrey = Color(0xFF817995);

  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);

  static const Color whatsapp = Color(0xFF25D366);
  static const Color instagram = Color(0xFFE1306C);
}

class AppTypography {
  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
  );
  static const TextStyle previewBrand = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    color: AppColors.accentOrange,
    letterSpacing: 3.0,
  );
  static const TextStyle previewScore = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AppColors.accentGold,
    height: 1.0,
    letterSpacing: 0.5,
  );
  static const TextStyle previewMeta = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.bodyGrey,
  );
  static const TextStyle previewUrl = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
  );
  static const TextStyle tileLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedGrey,
  );
  static const TextStyle message = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
    height: 1.5,
  );
  static const TextStyle close = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.mutedGrey,
  );
}

// ==========================================
// SHARE SHEET SCREEN
// ==========================================
class ShareSheetScreen extends StatefulWidget {
  /// Score to display and share. Passed in by the Results screen.
  final int score;

  /// Whether the round set a new personal best.
  final bool isNewBest;

  /// Best combo achieved (e.g. "x5").
  final String combo;

  const ShareSheetScreen({
    super.key,
    this.score = 8420,
    this.isNewBest = true,
    this.combo = 'x5',
  });

  @override
  State<ShareSheetScreen> createState() => _ShareSheetScreenState();
}

class _ShareSheetScreenState extends State<ShareSheetScreen>
    with SingleTickerProviderStateMixin {
  /// One-shot entry: slide the sheet up + fade the dim overlay in.
  late final AnimationController _entry;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  /// Compiled share message. Rebuilt only when widget params change.
  late final String _shareMessage;

  /// Dismisses the sheet. Falls back to `/results` when there is
  /// nothing in the router stack to pop (e.g. deep-linked entry).
  void _dismiss() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/results');
    }
  }

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _entry.forward();

    // Simple text template — no runtime string building in the build method.
    final score = _format(widget.score);
    _shareMessage =
        '🫧 Just scored $score on Muskaan Minigame! '
        '${widget.isNewBest ? "New personal best " : ""}'
        'with a ${widget.combo} combo 🔥 muskaanpk.app';
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  /// 8420 → "8,420". Simple, allocation-light.
  static String _format(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: _shareMessage));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ---- Dim overlay: taps dismiss the sheet ----
          Positioned.fill(
            child: FadeTransition(
              opacity: _fade,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                child: const ColoredBox(color: AppColors.overlay),
              ),
            ),
          ),

          // ---- Bottom sheet ----
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: _slide,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - _slide.value) * 500),
                  child: child,
                );
              },
              child: _buildSheet(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHEET
  // ---------------------------------------------------------------------------
  Widget _buildSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.sheetBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dragHandle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Share Your Score', style: AppTypography.title),
              const SizedBox(height: 16),

              _buildPreviewCard(),
              const SizedBox(height: 16),

              _buildShareGrid(),
              const SizedBox(height: 14),

              _buildMessagePreview(),
              const SizedBox(height: 8),

              _buildCloseButton(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PREVIEW CARD
  // ---------------------------------------------------------------------------
  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.previewBgStart,
            AppColors.previewBgMid,
            AppColors.previewBgEnd,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: AppColors.previewBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Gold radial glow at top-left
            Positioned(
              top: -20,
              left: -20,
              child: IgnorePointer(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accentGold.withValues(alpha: 0.20),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              ),
            ),

            Column(
              children: [
                const SoapBubbles.square(size: 44),
                const SizedBox(height: 6),
                const Text('MUSKAAN PK', style: AppTypography.previewBrand),
                const SizedBox(height: 4),
                Text(_format(widget.score), style: AppTypography.previewScore),
                const SizedBox(height: 4),
                Text(
                  _previewMetaLine(),
                  textAlign: TextAlign.center,
                  style: AppTypography.previewMeta,
                ),
                const SizedBox(height: 4),
                const Text('muskaanpk.app', style: AppTypography.previewUrl),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _previewMetaLine() {
    final parts = <String>[];
    if (widget.isNewBest) parts.add('⭐ New Best');
    parts.add('Combo ${widget.combo}');
    return parts.join('  •  ');
  }

  // ---------------------------------------------------------------------------
  // SHARE GRID
  // ---------------------------------------------------------------------------
  Widget _buildShareGrid() {
    final tiles = <_ShareTile>[
      _ShareTile(
        emoji: '💬',
        label: 'WhatsApp',
        accent: AppColors.whatsapp,
        onTap: () => _stubShare('WhatsApp'),
      ),
      _ShareTile(
        emoji: '📸',
        label: 'Instagram',
        accent: AppColors.instagram,
        onTap: () => _stubShare('Instagram'),
      ),
      _ShareTile(
        emoji: '📋',
        label: 'Copy',
        accent: AppColors.accentOrange,
        onTap: _copyMessage,
      ),
      _ShareTile(
        emoji: '⋯',
        label: 'More',
        accent: AppColors.mutedGrey,
        onTap: () => _stubShare('More'),
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: _entry,
              builder: (context, child) {
                // Stagger each tile by 60 ms.
                final start = 0.3 + i * 0.10;
                final local = ((_entry.value - start) / 0.4).clamp(0.0, 1.0);
                final curved = Curves.easeOutBack.transform(local);
                return Opacity(
                  opacity: curved.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - curved) * 8),
                    child: child,
                  ),
                );
              },
              child: _TileWidget(tile: tiles[i]),
            ),
          ),
        ],
      ],
    );
  }

  void _stubShare(String channel) {
    // Real deep links are wired in a later phase. For now, copy
    // the message so the button always does something useful.
    _copyMessage();
  }

  // ---------------------------------------------------------------------------
  // MESSAGE PREVIEW
  // ---------------------------------------------------------------------------
  Widget _buildMessagePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.messageBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(_shareMessage, style: AppTypography.message),
    );
  }

  // ---------------------------------------------------------------------------
  // CLOSE
  // ---------------------------------------------------------------------------
  Widget _buildCloseButton(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextButton(
        onPressed: _dismiss,
        child: const Text('CLOSE', style: AppTypography.close),
      ),
    );
  }
}

// ==========================================
// SHARE TILE MODEL
// ==========================================
class _ShareTile {
  final String emoji;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _ShareTile({
    required this.emoji,
    required this.label,
    required this.accent,
    required this.onTap,
  });
}

// ==========================================
// TILE WIDGET
// ==========================================
class _TileWidget extends StatelessWidget {
  final _ShareTile tile;
  const _TileWidget({required this.tile});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Share via ${tile.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: tile.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tile.accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tile.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    tile.emoji,
                    style: const TextStyle(fontSize: 20, height: 1.0),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tile.label,
                  style: AppTypography.tileLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
