import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../models/online_models.dart';
import '../services/auth_service.dart';
import '../services/match_service.dart';
import '../widgets/board_widget.dart';

class OnlineGameScreen extends StatefulWidget {
  final String matchId;
  const OnlineGameScreen({super.key, required this.matchId});

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final _gameState = GameState(mode: GameMode.twoPlayer);
  StreamSubscription<OnlineMatch>? _sub;
  Timer? _ticker;
  OnlineMatch? _match;
  String get _uid => AuthService.instance.current!.uid;

  @override
  void initState() {
    super.initState();
    _sub = MatchService.instance.watch(widget.matchId).listen(_onMatch);
    // Cập nhật đồng hồ đếm lượt mỗi giây.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _match?.status == MatchStatus.playing) setState(() {});
    });
  }

  /// Số giây còn lại của lượt hiện tại (null nếu chưa có dữ liệu).
  int? get _remaining {
    final m = _match;
    if (m == null || m.status != MatchStatus.playing) return null;
    final start = m.turnStartedAt;
    if (start == null) return null;
    final left =
        MatchService.turnSeconds - DateTime.now().difference(start).inSeconds;
    return left < 0 ? 0 : left;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    // Nếu rời khi ván chưa kết thúc → báo bỏ cuộc cho đối thủ.
    if (_match != null &&
        _match!.status != MatchStatus.finished) {
      MatchService.instance.leave(widget.matchId);
    }
    _gameState.dispose();
    super.dispose();
  }

  void _onMatch(OnlineMatch m) {
    // Dựng lại bàn cờ từ danh sách nước đi (server là nguồn dữ liệu chuẩn).
    _gameState.reset();
    for (final mv in m.moves) {
      _gameState.makeMove(mv.row, mv.col);
    }
    setState(() => _match = m);
  }

  void _onTap(int row, int col) {
    final m = _match;
    if (m == null || m.status != MatchStatus.playing) return;
    final mySymbol = m.symbolFor(_uid);
    if (mySymbol == null || m.turn != mySymbol) return; // chưa tới lượt
    MatchService.instance.makeMove(m, row, col);
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Chơi online',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: m == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(m),
    );
  }

  Widget _buildBody(OnlineMatch m) {
    if (!m.hasOpponent && m.status == MatchStatus.waiting) {
      return _WaitingView(match: m);
    }

    final mySymbol = m.symbolFor(_uid) ?? 'X';
    final myTurn = m.status == MatchStatus.playing && m.turn == mySymbol;
    final oppName = m.opponentNameFor(_uid) ?? 'Đối thủ';

    String status;
    if (m.status == MatchStatus.abandoned) {
      status = 'Đối thủ đã rời trận';
    } else if (m.status == MatchStatus.finished) {
      if (m.winner == 'draw') {
        status = 'Hòa! 🤝';
      } else {
        status = m.winner == mySymbol ? 'Bạn thắng! 🎉' : 'Bạn thua! 😢';
      }
    } else {
      final secs = _remaining;
      final clock = secs == null ? '' : ' · ${secs}s';
      status = myTurn
          ? 'Lượt của bạn$clock'
          : '$oppName đang suy nghĩ...$clock';
    }

    // Đối thủ hết giờ → cho phép tuyên bố thắng.
    final oppTimedOut = m.status == MatchStatus.playing &&
        !myTurn &&
        (_remaining ?? 1) <= 0;

    return Column(
      children: [
        Container(
          color: const Color(0xFF1A237E),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PlayerTag(
                name: 'Bạn ($mySymbol)',
                color: mySymbol == 'X'
                    ? const Color(0xFF42A5F5)
                    : const Color(0xFFEF5350),
                active: myTurn,
              ),
              Text(status,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              _PlayerTag(
                name: oppName,
                color: mySymbol == 'X'
                    ? const Color(0xFFEF5350)
                    : const Color(0xFF42A5F5),
                active: m.status == MatchStatus.playing && !myTurn,
              ),
            ],
          ),
        ),
        if (oppTimedOut)
          Material(
            color: const Color(0xFFFFF3E0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Đối thủ đã hết giờ',
                        style: TextStyle(color: Color(0xFFE65100))),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        MatchService.instance.claimTimeoutWin(widget.matchId),
                    child: const Text('Tuyên bố thắng'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: BoardWidget(gameState: _gameState, onTap: _onTap),
          ),
        ),
        if (m.status == MatchStatus.finished ||
            m.status == MatchStatus.abandoned)
          _buildEndBar(m),
      ],
    );
  }

  Widget _buildEndBar(OnlineMatch m) {
    final isHost = m.hostUid == _uid;
    final iWantRematch = isHost ? m.rematchHost : m.rematchGuest;
    final oppWantsRematch = isHost ? m.rematchGuest : m.rematchHost;
    final canRematch = m.status == MatchStatus.finished;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (oppWantsRematch && canRematch)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Đối thủ muốn chơi lại',
                  style: TextStyle(color: Color(0xFF66BB6A))),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Thoát'),
                ),
              ),
              const SizedBox(width: 12),
              if (canRematch)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: iWantRematch
                        ? null
                        : () => MatchService.instance
                            .requestRematch(widget.matchId),
                    child: Text(iWantRematch ? 'Đang chờ...' : 'Chơi lại'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  final OnlineMatch match;
  const _WaitingView({required this.match});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            match.mode == 'random'
                ? 'Đang tìm đối thủ...'
                : 'Đang chờ đối thủ tham gia...',
            style: const TextStyle(fontSize: 16),
          ),
          if (match.roomCode != null) ...[
            const SizedBox(height: 24),
            const Text('Mã phòng', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: match.roomCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép mã phòng')),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      match.roomCode!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.copy, size: 20, color: Color(0xFF1A237E)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Gửi mã này cho bạn để vào chơi',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _PlayerTag extends StatelessWidget {
  final String name;
  final Color color;
  final bool active;
  const _PlayerTag(
      {required this.name, required this.color, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color.withAlpha(60) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: active ? Border.all(color: color) : null,
      ),
      child: Text(name,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
