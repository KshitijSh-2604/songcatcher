import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/player.dart';

class ScoreboardWidget extends StatelessWidget {
  final String roomId;
  const ScoreboardWidget({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: Row(
            children: [
              Text('🏆 ', style: TextStyle(fontSize: 14)),
              Text(
                'Scores',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
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
                return const Center(
                    child: CircularProgressIndicator());
              }

              final players = snap.data!.docs
                  .map((d) => Player.fromMap(
                  d.id, d.data() as Map<String, dynamic>))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: players.length,
                itemBuilder: (_, i) {
                  final p = players[i];
                  final medal = i == 0
                      ? '🥇'
                      : i == 1
                      ? '🥈'
                      : i == 2
                      ? '🥉'
                      : '  ${i + 1}';

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: i == 0
                            ? Colors.amber.withOpacity(0.08)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(medal,
                              style: const TextStyle(
                                  fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.displayName,
                              style: const TextStyle(
                                  fontSize: 12),
                              overflow:
                              TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${p.score}',
                            style: const TextStyle(
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
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