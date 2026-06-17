import 'package:flutter/material.dart';
import '../models/online_models.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/match_service.dart';
import 'friends_screen.dart';
import 'online_game_screen.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _nameCtrl = TextEditingController();
  UserProfile? _profile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _profile = AuthService.instance.current;
    if (_profile == null) _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final saved = await AuthService.instance.savedDisplayName();
    if (saved != null && mounted) _nameCtrl.text = saved;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final p = await AuthService.instance.signIn(name);
      if (mounted) setState(() => _profile = p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi đăng nhập: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _go(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final matchId = await action();
      if (!mounted) return;
      if (matchId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy phòng')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineGameScreen(matchId: matchId),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createRoom() =>
      _go(() async => (await MatchService.instance.createRoom()).matchId);

  Future<void> _quickMatch() =>
      _go(() async => MatchService.instance.quickMatch());

  Future<void> _joinRoom() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vào phòng'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Mã phòng (6 ký tự)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Vào'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    await _go(() => MatchService.instance.joinRoom(code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Chơi online',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: !AuthService.instance.isAvailable
          ? _buildUnavailable()
          : _profile == null
              ? _buildNameForm()
              : _buildLobby(),
    );
  }

  Widget _buildUnavailable() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Chế độ online chưa được bật.\n\n'
              'Cần cấu hình Firebase (xem FIREBASE_SETUP.md) rồi đặt '
              'kFirebaseEnabled = true.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, size: 72, color: Color(0xFF1A237E)),
          const SizedBox(height: 16),
          const Text('Nhập tên hiển thị để bắt đầu',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            maxLength: 20,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _signIn(),
            decoration: const InputDecoration(
              labelText: 'Tên của bạn',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
              onPressed: _busy ? null : _signIn,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Tiếp tục', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby() {
    final p = _profile!;
    return Column(
      children: [
        _buildInviteBanner(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE8EAF6),
          child: Column(
            children: [
              Text('Xin chào, ${p.displayName}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Mã kết bạn: ${p.friendCode}',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        Expanded(
          child: AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _LobbyButton(
                  icon: Icons.shuffle,
                  color: const Color(0xFF42A5F5),
                  label: 'Tìm trận ngẫu nhiên',
                  subtitle: 'Ghép với người chơi đang online',
                  onTap: _quickMatch,
                ),
                _LobbyButton(
                  icon: Icons.add_circle_outline,
                  color: const Color(0xFF66BB6A),
                  label: 'Tạo phòng',
                  subtitle: 'Tạo mã phòng để mời bạn',
                  onTap: _createRoom,
                ),
                _LobbyButton(
                  icon: Icons.meeting_room_outlined,
                  color: const Color(0xFFFFA726),
                  label: 'Vào phòng',
                  subtitle: 'Nhập mã phòng của bạn bè',
                  onTap: _joinRoom,
                ),
                _LobbyButton(
                  icon: Icons.people_outline,
                  color: const Color(0xFFAB47BC),
                  label: 'Bạn bè',
                  subtitle: 'Kết bạn và mời chơi trực tiếp',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }

  Widget _buildInviteBanner() {
    return StreamBuilder<List<GameInvite>>(
      stream: FriendService.instance.watchInvites(),
      builder: (context, snap) {
        final invites = snap.data ?? [];
        if (invites.isEmpty) return const SizedBox.shrink();
        final inv = invites.first;
        return Material(
          color: const Color(0xFF66BB6A),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.sports_esports, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${inv.fromName} mời bạn chơi!',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () async {
                    await FriendService.instance.deleteInvite(inv.id);
                  },
                  child: const Text('Từ chối',
                      style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF66BB6A),
                  ),
                  onPressed: () async {
                    await FriendService.instance.deleteInvite(inv.id);
                    final ok =
                        await MatchService.instance.joinMatch(inv.matchId);
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OnlineGameScreen(matchId: inv.matchId),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lời mời đã hết hạn')),
                      );
                    }
                  },
                  child: const Text('Chấp nhận'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LobbyButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _LobbyButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(40),
          child: Icon(icon, color: color),
        ),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
