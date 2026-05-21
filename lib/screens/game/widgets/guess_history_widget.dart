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
          .limit(15)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🎧',
                    style: TextStyle(fontSize: 32)),
                SizedBox(height: 8),
                Text(
                  'Play the clip and start guessing!',
                  style: TextStyle(
                      color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          );
        }

        final docs = snap.data!.docs;
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data =
            docs[i].data() as Map<String, dynamic>;
            final guess = data['guess'] as String? ?? '';
            final correct = data['correct'] as bool? ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    correct
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: correct
                        ? Colors.greenAccent
                        : Colors.redAccent.withOpacity(0.7),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: correct
                            ? Colors.green.withOpacity(0.12)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: correct
                              ? Colors.green.withOpacity(0.3)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        guess,
                        style: TextStyle(
                          color: correct
                              ? Colors.greenAccent
                              : Colors.white60,
                          fontSize: 14,
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