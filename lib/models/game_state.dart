import 'package:flutter/foundation.dart';

enum Player { X, O }

enum GameMode { vsAI, twoPlayer }

enum GameStatus { playing, xWon, oWon, draw }

class GameState extends ChangeNotifier {
  static const int boardSize = 15;
  static const int winCount = 5;

  final List<List<Player?>> board;
  Player currentPlayer;
  GameStatus status;
  GameMode mode;
  List<List<int>>? winningCells;
  int scoreX;
  int scoreO;
  List<List<int>> moveHistory;

  GameState({this.mode = GameMode.vsAI})
      : board = List.generate(boardSize, (_) => List.filled(boardSize, null)),
        currentPlayer = Player.X,
        status = GameStatus.playing,
        winningCells = null,
        scoreX = 0,
        scoreO = 0,
        moveHistory = [];

  void reset() {
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        board[r][c] = null;
      }
    }
    currentPlayer = Player.X;
    status = GameStatus.playing;
    winningCells = null;
    moveHistory = [];
    notifyListeners();
  }

  bool makeMove(int row, int col) {
    if (status != GameStatus.playing) return false;
    if (board[row][col] != null) return false;

    board[row][col] = currentPlayer;
    moveHistory.add([row, col]);

    final winning = _checkWin(row, col, currentPlayer);
    if (winning != null) {
      winningCells = winning;
      status = currentPlayer == Player.X ? GameStatus.xWon : GameStatus.oWon;
      if (status == GameStatus.xWon) scoreX++;
      if (status == GameStatus.oWon) scoreO++;
    } else if (_isDraw()) {
      status = GameStatus.draw;
    } else {
      currentPlayer = currentPlayer == Player.X ? Player.O : Player.X;
    }

    notifyListeners();
    return true;
  }

  bool undoMove() {
    if (moveHistory.isEmpty) return false;
    if (mode == GameMode.vsAI && moveHistory.length < 2) return false;

    final steps = mode == GameMode.vsAI ? 2 : 1;
    for (int i = 0; i < steps && moveHistory.isNotEmpty; i++) {
      final last = moveHistory.removeLast();
      board[last[0]][last[1]] = null;
    }
    currentPlayer = Player.X;
    for (int i = 0; i < moveHistory.length; i++) {
      currentPlayer = currentPlayer == Player.X ? Player.O : Player.X;
    }
    status = GameStatus.playing;
    winningCells = null;
    notifyListeners();
    return true;
  }

  List<List<int>>? _checkWin(int row, int col, Player player) {
    final directions = [
      [0, 1], [1, 0], [1, 1], [1, -1],
    ];
    for (final dir in directions) {
      final cells = _getLine(row, col, dir[0], dir[1], player);
      if (cells != null) return cells;
    }
    return null;
  }

  List<List<int>>? _getLine(int row, int col, int dr, int dc, Player player) {
    final cells = <List<int>>[[row, col]];
    for (final sign in [-1, 1]) {
      int r = row + sign * dr;
      int c = col + sign * dc;
      while (_inBounds(r, c) && board[r][c] == player) {
        cells.add([r, c]);
        r += sign * dr;
        c += sign * dc;
      }
    }
    if (cells.length >= winCount) return cells;
    return null;
  }

  bool _isDraw() {
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] == null) return false;
      }
    }
    return true;
  }

  bool _inBounds(int r, int c) =>
      r >= 0 && r < boardSize && c >= 0 && c < boardSize;
}
