import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/player_profile_repository.dart';

class PlayerSetupScreen extends ConsumerStatefulWidget {
  const PlayerSetupScreen({super.key});
  @override
  ConsumerState<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends ConsumerState<PlayerSetupScreen> {
  final _name = TextEditingController();
  String? _error;
  bool _saving = false, _filled = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save({bool generated = false}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(playerProfileProvider.notifier)
          .update(name: generated ? null : _name.text, onboarded: true);
      if (mounted) context.go('/welcome');
    } catch (error) {
      if (mounted)
        setState(
          () =>
              _error =
                  error is FormatException
                      ? error.message
                      : 'Unable to save your player. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your player')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: profile.when(
            loading: () => const CircularProgressIndicator(),
            error:
                (_, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Your saved profile could not be read. It has been preserved.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed:
                          () =>
                              ref
                                  .read(playerProfileProvider.notifier)
                                  .retryLoad(),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: _confirmProfileRepair,
                      child: const Text('Create a replacement profile'),
                    ),
                  ],
                ),
            data: (player) {
              if (!_filled) {
                _name.text = player.displayName;
                _filled = true;
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(player.avatar, style: const TextStyle(fontSize: 56)),
                    const Text(
                      'Meet your player! Keep this name or choose your own.',
                    ),
                    TextField(
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: 'Player name',
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Continue'),
                    ),
                    TextButton(
                      onPressed: _saving ? null : () => _save(generated: true),
                      child: const Text('Keep generated name'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmProfileRepair() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Replace unreadable profile?'),
            content: const Text(
              'This creates a new player ID. Existing game records remain '
              'preserved with their previous ownership.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create replacement'),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await ref.read(playerProfileProvider.notifier).replaceCorruptProfile();
    }
  }
}
