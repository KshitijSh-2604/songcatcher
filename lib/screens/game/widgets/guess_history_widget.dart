import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GuessHistoryWidget extends StatelessWidget {
  final String roomId;
  final String userId;

  const GuessHistoryWidget({
    super.key,
    required this.roomId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('guesses')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Your guesses will appear here',
              style: TextStyle(color: Colors.white38),
            ),
          );
        }

        final guesses = snap.data!.docs;
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: guesses.length,
          itemBuilder: (_, i) {
            final data = guesses[i].data() as Map<String, dynamic>;
            final guess = data['guess'] as String? ?? '';
            final correct = data['correct'] as bool? ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: correct
                    ? Colors.green.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: correct
                      ? Colors.green.withOpacity(0.4)
                      : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    correct ? Icons.check_circle : Icons.cancel,
                    color: correct ? Colors.greenAccent : Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      guess,
                      style: TextStyle(
                        color: correct ? Colors.greenAccent : Colors.white70,
                        decoration: correct
                            ? TextDecoration.none
                            : TextDecoration.none,
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