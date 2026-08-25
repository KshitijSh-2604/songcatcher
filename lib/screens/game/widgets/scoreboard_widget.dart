import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/player.dart';
import '../../../utils/responsive.dart';
import '../../../models/app_user.dart';
import '../../../providers/auth_provider.dart';

import 'skribbl_avatar.dart';

class ScoreboardWidget extends ConsumerWidget {
  final String roomId;
  const ScoreboardWidget({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart, color: Theme.of(context).textTheme.bodyLarge?.color),
                  const SizedBox(width: 8),
                  const Text(
                    'Top Catchers',
                    style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const Spacer(),
                  const _LiveBadge(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('RANK  PLAYER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Theme.of(context).hintColor)),
                  const Spacer(),
                  Text('TRIES  TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Theme.of(context).hintColor)),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Theme.of(context).dividerColor, thickness: 2),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .doc(roomId)
                .collection('players')
                .orderBy('score', descending: true)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final players = snap.data!.docs
                  .map((d) => Player.fromMap(d.id, d.data() as Map<String, dynamic>))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: players.length,
                itemBuilder: (_, i) {
                  final p = players[i];
                  final isMe = p.id == currentUser?.uid;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ScoreTile(
                      player: p,
                      rank: i + 1,
                      isMe: isMe,
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 100)).slideX(begin: 0.1),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScoreTile extends StatefulWidget {
  final Player player;
  final int rank;
  final bool isMe;

  const _ScoreTile({required this.player, required this.rank, required this.isMe});

  @override
  State<_ScoreTile> createState() => _ScoreTileState();
}

class _ScoreTileState extends State<_ScoreTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: _hovering ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
            child: NeubrutalistContainer(
              color: widget.isMe ? const Color(0xFFFFFF00) : Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shadowOffset: _hovering ? 6 : 3,
              child: Row(
                children: [
                  Text(
                    '#${widget.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 16,
                      color: widget.isMe ? Colors.black : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Center(
                      child: SkribblAvatar(
                        config: AvatarConfig.fromMap(widget.player.avatarConfig),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isMe ? 'You' : widget.player.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: 14,
                        color: widget.isMe ? Colors.black : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${widget.player.score}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 14,
                      color: widget.isMe ? Colors.black : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isMe)
            Positioned(
              top: -10,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF00),
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF00),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
    );
  }
}

class _HeaderItem extends StatelessWidget {
  final String label;
  final bool isActive;

  const _HeaderItem({required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Bricolage Grotesque',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: isActive ? const Color(0xFF0001BB) : const Color(0xFF454558),
      ),
    );
  }
}
