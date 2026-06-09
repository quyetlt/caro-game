import 'package:flutter/material.dart';
import 'dart:async';
import '../models/game_state.dart';
import '../ai/minimax_ai.dart';
import '../widgets/board_widget.dart';

class GameScreen extends StatefulWidget {
  final GameMode mode;
  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _gameState;
  late MinimaxAI _ai;
  bool _aiThinking = false;

  @override
  void initState() {
    super.initState();
    _gameState = GameState(mode: widget.mode);
    _ai = MinimaxAI(aiPlayer: Player.O);
    _gameState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _gameState.removeListener(_onStateChanged);
    _gameState.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
    if (_gameState.status != GameStatus.playing) {
      _showResultDialog();
      return;
    }
    if (widget.mode == GameMode.vsAI &&
        _gameState.currentPlayer == Player.O &&
        !_aiThinking) {
      _doAIMove();
    }
  }

  Future<void> _doAIMove() async {
    setState(() => _aiThinking = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final move = _ai.getBestMove(_gameState.board);
    _gameState.makeMove(move[0], move[1]);
    if (mounted) setState(() => _aiThinking = false);
  }

  void _onTap(int row, int col) {
    if (_aiThinking) return;
    if (widget.mode == GameMode.vsAI && _gameState.currentPlayer == Player.O) return;
    _gameState.makeMove(row, col);
  }

  void _showResultDialog() {
    String msg;
    Color color;
    switch (_gameState.status) {
      case GameStatus.xWon:
        msg = widget.mode == GameMode.vsAI ? 'Bạn thắng! 🎉' : 'X thắng! 🎉';
        color = const Color(0xFF1E88E5);
      case GameStatus.oWon:
        msg = widget.mode == GameMode.vsAI ? 'AI thắng! 🤖' : 'O thắng! 🎉';
        color = const Color(0xFFE53935);
      case GameStatus.draw:
        msg = 'Hòa! 🤝';
        color = Colors.grey;
      case GameStatus.playing:
        return;
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(msg, textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScoreChip(label: 'X', score: _gameState.scoreX, color: const Color(0xFF1E88E5)),
              const SizedBox(width: 12),
              const Text('vs', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 12),
              _ScoreChip(label: 'O', score: _gameState.scoreO, color: const Color(0xFFE53935)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Thoát'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _gameState.reset();
              },
              child: const Text('Chơi lại'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isXTurn = _gameState.currentPlayer == Player.X;
    final statusText = _gameState.status == GameStatus.playing
        ? (_aiThinking
            ? 'AI đang suy nghĩ...'
            : (widget.mode == GameMode.vsAI
                ? (isXTurn ? 'Lượt của bạn (X)' : 'Lượt của AI (O)')
                : (isXTurn ? 'Lượt X' : 'Lượt O')))
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Text(
          widget.mode == GameMode.vsAI ? 'Chơi với AI' : 'Hai người chơi',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _aiThinking ? null : () => _gameState.undoMove(),
            tooltip: 'Đánh lại',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _aiThinking ? null : () => _gameState.reset(),
            tooltip: 'Chơi lại',
          ),
        ],
      ),
      body: Column(
        children: [
          // Score bar
          Container(
            color: const Color(0xFF1A237E),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ScoreChip(
                  label: widget.mode == GameMode.vsAI ? 'Bạn (X)' : 'X',
                  score: _gameState.scoreX,
                  color: const Color(0xFF42A5F5),
                  active: _gameState.currentPlayer == Player.X,
                ),
                Column(
                  children: [
                    if (_aiThinking)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    else
                      const Icon(Icons.circle, color: Colors.white30, size: 8),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                _ScoreChip(
                  label: widget.mode == GameMode.vsAI ? 'AI (O)' : 'O',
                  score: _gameState.scoreO,
                  color: const Color(0xFFEF5350),
                  active: _gameState.currentPlayer == Player.O,
                ),
              ],
            ),
          ),
          // Board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: BoardWidget(
                gameState: _gameState,
                onTap: _onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool active;

  const _ScoreChip({
    required this.label,
    required this.score,
    required this.color,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withAlpha(60) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text('$score', style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
