import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'online_lobby_screen.dart';
import '../models/game_state.dart';
import '../ai/minimax_ai.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _startVsAI(BuildContext context) async {
    final difficulty = await showModalBottomSheet<AIDifficulty>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Chọn độ khó',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final d in AIDifficulty.values)
              ListTile(
                leading: Icon(
                  switch (d) {
                    AIDifficulty.easy => Icons.sentiment_satisfied,
                    AIDifficulty.medium => Icons.sentiment_neutral,
                    AIDifficulty.hard => Icons.local_fire_department,
                  },
                  color: const Color(0xFF1A237E),
                ),
                title: Text(difficultyLabel(d)),
                onTap: () => Navigator.pop(context, d),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (difficulty == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GameScreen(mode: GameMode.vsAI, difficulty: difficulty),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF1565C0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withAlpha(80), width: 2),
                ),
                child: const Center(
                  child: Text(
                    'XO',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'CỜ CARO',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const Text(
                'Gomoku 5-in-a-row',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _MenuButton(
                      label: 'Chơi với AI',
                      icon: Icons.smart_toy_outlined,
                      color: const Color(0xFF42A5F5),
                      onTap: () => _startVsAI(context),
                    ),
                    const SizedBox(height: 16),
                    _MenuButton(
                      label: 'Chơi online',
                      icon: Icons.public,
                      color: const Color(0xFF66BB6A),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OnlineLobbyScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MenuButton(
                      label: 'Hai người (1 máy)',
                      icon: Icons.people_outline,
                      color: const Color(0xFFFFA726),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GameScreen(mode: GameMode.twoPlayer),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              const Text(
                'v1.0.0',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        onPressed: onTap,
      ),
    );
  }
}
