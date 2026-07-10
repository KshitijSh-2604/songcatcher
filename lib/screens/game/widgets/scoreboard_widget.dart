import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/player.dart';
import '../../../utils/responsive.dart';

class ScoreboardWidget extends StatelessWidget {
  final String roomId;
  const ScoreboardWidget({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              context.fs(10, max: 16), context.fs(12, max: 18), context.fs(10, max: 16), context.fs(6, max: 10)),
          child: Row(
            children: [
              Text('🏆 ', style: TextStyle(fontSize: context.ff(13, max: 16))),
              Text(
                'Scores',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.ff(13, max: 16)),
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
                return const Center(child: CircularProgressIndicator());
              }

              final players = snap.data!.docs
                  .map((d) => Player.fromMap(d.id, d.data() as Map<String, dynamic>))
                  .toList();

              return ListView.builder(
                padding: EdgeInsets.symmetric(vertical: context.fs(5, max: 8)),
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
                    padding: EdgeInsets.symmetric(
                        horizontal: context.fs(8, max: 14), vertical: context.fs(2, max: 4)),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.fs(8, max: 14), vertical: context.fs(7, max: 11)),
                      decoration: BoxDecoration(
                        color: i == 0 ? Colors.amber.withOpacity(0.08) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(context.fs(6, max: 10)),
                      ),
                      child: Row(
                        children: [
                          Text(medal, style: TextStyle(fontSize: context.ff(13, max: 16))),
                          SizedBox(width: context.fs(5, max: 8)),
                          Expanded(
                            child: Text(
                              p.displayName,
                              style: TextStyle(fontSize: context.ff(11, max: 14)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${p.score}',
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: context.ff(12, max: 15),
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