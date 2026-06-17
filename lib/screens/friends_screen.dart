import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/online_models.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/match_service.dart';
import 'online_game_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _codeCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _adding = true);
    final friend = await FriendService.instance.addFriendByCode(code);
    if (!mounted) return;
    setState(() => _adding = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(friend == null
          ? 'Không tìm thấy mã này'
          : 'Đã kết bạn với ${friend.displayName}'),
    ));
    if (friend != null) _codeCtrl.clear();
  }

  Future<void> _invite(String friendUid) async {
    final matchId = await MatchService.instance.createFriendMatch();
    await FriendService.instance.sendInvite(friendUid, matchId);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(matchId: matchId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myCode = AuthService.instance.current?.friendCode ?? '';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Bạn bè',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Mã kết bạn của tôi
          Container(
            width: double.infinity,
            color: const Color(0xFFE8EAF6),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Mã kết bạn của bạn',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: myCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép mã')),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(myCode,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: Color(0xFF1A237E))),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy, color: Color(0xFF1A237E)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Thêm bạn bằng mã
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Nhập mã bạn bè',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _adding ? null : _addFriend,
                  child: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Kết bạn'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildFriendList()),
        ],
      ),
    );
  }

  Widget _buildFriendList() {
    return StreamBuilder<List<String>>(
      stream: FriendService.instance.watchFriendIds(),
      builder: (context, snap) {
        final ids = snap.data ?? [];
        if (ids.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Chưa có bạn nào.\nChia sẻ mã của bạn để kết bạn!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        return ListView.separated(
          itemCount: ids.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _FriendTile(
            uid: ids[i],
            onInvite: () => _invite(ids[i]),
          ),
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String uid;
  final VoidCallback onInvite;
  const _FriendTile({required this.uid, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile>(
      stream: FriendService.instance.watchUser(uid),
      builder: (context, snap) {
        final p = snap.data;
        final online = p?.online ?? false;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: online
                ? const Color(0xFF66BB6A)
                : Colors.grey.shade400,
            child: Text((p?.displayName ?? '?').characters.first.toUpperCase(),
                style: const TextStyle(color: Colors.white)),
          ),
          title: Text(p?.displayName ?? 'Đang tải...'),
          subtitle: Text(online ? 'Đang online' : 'Ngoại tuyến',
              style: TextStyle(
                  color: online ? const Color(0xFF66BB6A) : Colors.grey,
                  fontSize: 12)),
          trailing: ElevatedButton.icon(
            onPressed: online ? onInvite : null,
            icon: const Icon(Icons.sports_esports, size: 18),
            label: const Text('Mời'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
