import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../utils/responsive.dart';

class GuessHistoryWidget extends StatelessWidget {
  final String roomId;
  final String userId;
  final int roundNumber;

  const GuessHistoryWidget({
    super.key,
    required this.roomId,
    required this.userId,
    required this.roundNumber,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Unified across all players — was previously filtered to userId only.
      // Now also scoped to the current round so old rounds' chat/answers
      // never leak into a fresh round.
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('guesses')
          .where('roundNumber', isEqualTo: roundNumber)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🎧', style: TextStyle(fontSize: context.ff(26, max: 40))),
                Gap(context.fs(6, max: 10)),
                Text(
                  'Play the clip and start guessing!',
                  style: TextStyle(color: Colors.white38, fontSize: context.ff(12, max: 15)),
                ),
              ],
            ),
          );
        }

        final docs = snap.data!.docs;
        return ListView.builder(
          reverse: true,
          padding: EdgeInsets.symmetric(horizontal: context.fs(12, max: 20), vertical: context.fs(8, max: 14)),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final guess = data['guess'] as String? ?? '';
            final correct = data['correct'] as bool? ?? false;
            final displayName = data['displayName'] as String? ?? 'Player';
            final isMe = data['userId'] == userId;

            // Correct guesses never reveal the answer to anyone — including
            // the guesser's own history entry — they show a "caught it"
            // banner instead. This is the masking behavior bug #3 asked for.
            final bubbleText = correct ? '🎉 $displayName caught it!' : guess;

            return Padding(
              padding: EdgeInsets.only(bottom: context.fs(5, max: 8)),
              child: Row(
                children: [
                  Icon(
                    correct ? Icons.check_circle_rounded : Icons.chat_bubble_outline_rounded,
                    color: correct ? Colors.greenAccent : Colors.white38,
                    size: context.ff(16, max: 20),
                  ),
                  SizedBox(width: context.fs(8, max: 12)),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: context.fs(12, max: 18), vertical: context.fs(7, max: 10)),
                      decoration: BoxDecoration(
                        color: correct
                            ? Colors.green.withOpacity(0.14)
                            : (isMe ? Colors.purpleAccent.withOpacity(0.08) : Colors.white.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: correct
                              ? Colors.green.withOpacity(0.35)
                              : (isMe ? Colors.purpleAccent.withOpacity(0.25) : Colors.white12),
                        ),
                      ),
                      child: correct
                          ? Text(
                        bubbleText,
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: context.ff(13, max: 16),
                        ),
                      )
                          : RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$displayName: ',
                              style: TextStyle(
                                color: isMe ? Colors.purpleAccent : Colors.white54,
                                fontWeight: FontWeight.w600,
                                fontSize: context.ff(12, max: 15),
                              ),
                            ),
                            TextSpan(
                              text: guess,
                              style: TextStyle(color: Colors.white70, fontSize: context.ff(13, max: 16)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}