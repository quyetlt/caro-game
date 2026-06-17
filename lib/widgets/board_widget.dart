import 'package:flutter/material.dart';
import '../models/game_state.dart';

class BoardWidget extends StatefulWidget {
  final GameState gameState;
  final Function(int row, int col) onTap;

  const BoardWidget({super.key, required this.gameState, required this.onTap});

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cạnh vuông = cạnh ngắn nhất của vùng trống → bàn cờ luôn vuông,
        // không bị kéo dài kẻ dọc xuống phần thừa bên dưới.
        final side = constraints.biggest.shortestSide;
        final cellSize = side / GameState.boardSize;
        return InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 3.0,
          child: Center(
            child: SizedBox(
              width: side,
              height: side,
              child: GestureDetector(
                onTapDown: (details) {
                  final col = (details.localPosition.dx / cellSize).floor();
                  final row = (details.localPosition.dy / cellSize).floor();
                  if (row >= 0 && row < GameState.boardSize &&
                      col >= 0 && col < GameState.boardSize) {
                    widget.onTap(row, col);
                  }
                },
                child: CustomPaint(
                  painter: _BoardPainter(widget.gameState),
                  size: Size.square(side),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  final GameState state;

  _BoardPainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    final n = GameState.boardSize;
    final cell = size.width / n;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFECEFF1),
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= n; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), gridPaint);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), gridPaint);
    }

    // Pieces
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final player = state.board[r][c];
        if (player == null) continue;

        final isWinCell = state.winningCells?.any((w) => w[0] == r && w[1] == c) ?? false;
        final center = Offset(c * cell + cell / 2, r * cell + cell / 2);
        final radius = cell * 0.35;

        if (player == Player.X) {
          _drawX(canvas, center, radius, isWinCell);
        } else {
          _drawO(canvas, center, radius, isWinCell);
        }
      }
    }

    // Last move indicator
    if (state.moveHistory.isNotEmpty) {
      final last = state.moveHistory.last;
      final center = Offset(last[1] * cell + cell / 2, last[0] * cell + cell / 2);
      canvas.drawCircle(
        center,
        cell * 0.08,
        Paint()..color = Colors.black54,
      );
    }
  }

  void _drawX(Canvas canvas, Offset center, double radius, bool highlight) {
    final paint = Paint()
      ..color = highlight ? const Color(0xFF1565C0) : const Color(0xFF1E88E5)
      ..strokeWidth = highlight ? 3 : 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final r = radius * 0.8;
    canvas.drawLine(
      Offset(center.dx - r, center.dy - r),
      Offset(center.dx + r, center.dy + r),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + r, center.dy - r),
      Offset(center.dx - r, center.dy + r),
      paint,
    );

    if (highlight) {
      canvas.drawRect(
        Rect.fromCenter(center: center, width: radius * 2.5, height: radius * 2.5),
        Paint()
          ..color = const Color(0x221565C0)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawO(Canvas canvas, Offset center, double radius, bool highlight) {
    final paint = Paint()
      ..color = highlight ? const Color(0xFFC62828) : const Color(0xFFE53935)
      ..strokeWidth = highlight ? 3 : 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius * 0.8, paint);

    if (highlight) {
      canvas.drawRect(
        Rect.fromCenter(center: center, width: radius * 2.5, height: radius * 2.5),
        Paint()
          ..color = const Color(0x22C62828)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
