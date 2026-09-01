import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/friendship.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive.dart';
import '../game/widgets/skribbl_avatar.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    
    setState(() => _searching = true);
    try {
      final results = await ref.read(userServiceProvider).searchUsers(q);
      if (mounted) setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔔 Get friend count for header
    final myUid = ref.watch(currentUserProvider.select((u) => u?.uid));
    final friendsCount = myUid == null ? 0 : ref.watch(friendshipsProvider(myUid)).when(
      data: (fs) => fs.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return PageShell(
      showHeader: true,
      showSidebar: true,
      scrollable: false,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(context.fs(16, max: 32)),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: context.fs(24, max: 48), color: const Color(0xFF4D4DFF)),
                Gap(context.fs(12, max: 20), horizontal: true),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Friends Arena',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: context.ff(20, max: 32),
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      Text(
                        '($friendsCount/99 friends)', 
                        style: TextStyle(fontSize: context.ff(10, max: 14), fontWeight: FontWeight.w800, color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
                NeubrutalistButton(
                  label: 'ADD NEW',
                  color: const Color(0xFFFFFF00),
                  onPressed: () {
                    _searchResults = [];
                    _searchCtrl.clear();
                    _showAddFriendDialog(context);
                  },
                ),
              ],
            ),
          ),

          // ── Tab Bar ───────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.fs(16, max: 32)),
            child: NeubrutalistContainer(
              padding: EdgeInsets.zero,
              color: Theme.of(context).cardColor,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF4D4DFF),
                indicatorWeight: 4,
                labelColor: const Color(0xFF4D4DFF),
                unselectedLabelColor: Theme.of(context).hintColor,
                labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: context.ff(12, max: 16)),
                tabs: const [
                  Tab(text: 'MY FRIENDS'),
                  Tab(text: 'REQUESTS'),
                ],
              ),
            ),
          ),

          Gap(context.fs(16, max: 32)),

          // ── Tab Content ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FriendsList(),
                _RequestsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Search Players', style: TextStyle(fontWeight: FontWeight.w900)),
          content: SizedBox( // Use SizedBox with fixed width to avoid IntrinsicWidth issues
            width: context.fw(320, max: 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Search by Username or Catcher ID (e.g. CATCHER#1234)', style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(hintText: 'Search...'),
                        onSubmitted: (_) async {
                          await _doSearch();
                          setDialogState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        await _doSearch();
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_searching)
                  const Center(child: CircularProgressIndicator())
                else if (_searchResults.isEmpty && _searchCtrl.text.isNotEmpty)
                  const Text('No players found.', style: TextStyle(color: Colors.black54))
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: context.screenHeight * 0.4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (ctx, i) {
                        final u = _searchResults[i];
                        if (u.uid == ref.read(currentUserProvider)?.uid) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: NeubrutalistContainer(
                            padding: const EdgeInsets.all(8),
                            shadowOffset: 2,
                            child: Row(
                              children: [
                                SkribblAvatar(config: AvatarConfig.fromMap(u.avatarConfig), size: 30),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text(u.catcherId, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                                  ],
                                )),
                                IconButton(
                                  icon: const Icon(Icons.person_add, color: Color(0xFF4D4DFF)),
                                  onPressed: () => _sendRequest(u.uid, u.displayName),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')),
          ],
        ),
      ),
    );
  }

  Future<void> _sendRequest(String targetUid, String name) async {
    final myUid = ref.read(currentUserProvider)?.uid;
    if (myUid == null) return;
    
    try {
      await ref.read(friendServiceProvider).sendFriendRequest(myUid, targetUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request sent to $name!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }
}

class _FriendsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 Performance: Only watch uid to avoid rebuilds on coin/stat changes
    final myUid = ref.watch(currentUserProvider.select((u) => u?.uid));
    if (myUid == null) return const SizedBox.shrink();

    final profilesAsync = ref.watch(friendProfilesProvider(myUid));

    return profilesAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) {
          return const _EmptyState(
            icon: Icons.person_add_outlined,
            title: 'No friends currently',
            subtitle: 'Add players to challenge them to private matches!',
          );
        }

        final online = profiles.where((p) => p.isOnline).toList();
        final offline = profiles.where((p) => !p.isOnline).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            if (online.isNotEmpty) ...[
              const Text('ONLINE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.green)),
              const SizedBox(height: 12),
              ...online.map((u) => _FriendTile(user: u)),
              const SizedBox(height: 24),
            ],
            if (offline.isNotEmpty) ...[
              const Text('OFFLINE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),
              ...offline.map((u) => _FriendTile(user: u)),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Error loading friends.')),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  final AppUser user;
  const _FriendTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider)?.uid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeubrutalistContainer(
        padding: const EdgeInsets.all(12),
        shadowOffset: 4,
        child: Row(
          children: [
            Stack(
              children: [
                SkribblAvatar(config: AvatarConfig.fromMap(user.avatarConfig), size: 40),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: user.isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(
                        user.isOnline ? '🟢 ${user.currentActivity}' : '⚪ Offline', 
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: user.isOnline ? Colors.green : Colors.black38)
                      ),
                    ],
                  ),
                ),
            IconButton(
              icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
              onPressed: () {
                if (myUid != null) {
                  _confirmRemove(context, ref, myUid, user.uid, user.displayName);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, String myUid, String otherUid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Friend?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to remove $name from your friends list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('STAY')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('REMOVE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final ids = [myUid, otherUid]..sort();
      final friendshipId = ids.join('_');
      await ref.read(friendServiceProvider).removeFriend(friendshipId);
    }
  }
}

class _RequestsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 Performance: Only watch uid
    final myUid = ref.watch(currentUserProvider.select((u) => u?.uid));
    if (myUid == null) return const SizedBox.shrink();

    final requestsAsync = ref.watch(pendingRequestsProvider(myUid));

    return requestsAsync.when(
      data: (friendships) {
        final incoming = friendships.where((f) => f.requestedBy != myUid).toList();
        final outgoing = friendships.where((f) => f.requestedBy == myUid).toList();

        if (incoming.isEmpty && outgoing.isEmpty) {
          return const _EmptyState(
            icon: Icons.mail_outline,
            title: 'No pending requests',
            subtitle: 'New friend requests will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            if (incoming.isNotEmpty) ...[
              const Text('INCOMING', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),
              ...incoming.map((f) => _RequestTile(otherId: f.requestedBy, friendshipId: f.id, isIncoming: true)),
              const SizedBox(height: 24),
            ],
            if (outgoing.isNotEmpty) ...[
              const Text('SENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),
              ...outgoing.map((f) => _RequestTile(otherId: f.getOtherId(myUid), friendshipId: f.id, isIncoming: false)),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final String otherId;
  final String friendshipId;
  final bool isIncoming;
  const _RequestTile({required this.otherId, required this.friendshipId, required this.isIncoming});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserAsync = ref.watch(userStreamProvider(otherId));

    return otherUserAsync.when(
      data: (u) {
        if (u == null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NeubrutalistContainer(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: Text('User data missing for $otherId', style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NeubrutalistContainer(
            padding: const EdgeInsets.all(12),
            shadowOffset: 2,
            child: Row(
              children: [
                SkribblAvatar(config: AvatarConfig.fromMap(u.avatarConfig), size: 30),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(u.catcherId, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38)),
                  ],
                )),
                if (isIncoming) ...[
                  _AcceptButton(friendshipId: friendshipId, name: u.displayName),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 24),
                    onPressed: () async {
                      try {
                        await ref.read(friendServiceProvider).rejectFriendRequest(friendshipId);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    tooltip: 'Decline',
                  ),
                ] else
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref.read(friendServiceProvider).rejectFriendRequest(friendshipId);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    child: const Text('CANCEL REQUEST', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NeubrutalistContainer(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('Fetching profile...', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ],
          ),
        ),
      ),
      error: (e, __) => Text('Error: $e'),
    );
  }
}

class _AcceptButton extends ConsumerStatefulWidget {
  final String friendshipId;
  final String name;
  const _AcceptButton({required this.friendshipId, required this.name});

  @override
  ConsumerState<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends ConsumerState<_AcceptButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)));

    return IconButton(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 24),
      onPressed: () async {
        setState(() => _loading = true);
        try {
          await ref.read(friendServiceProvider).acceptFriendRequest(widget.friendshipId);
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Accepted ${widget.name}\'s request!')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
          }
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      },
      tooltip: 'Accept',
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.black12),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black26),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black12),
            ),
          ],
        ),
      ),
    );
  }
}
