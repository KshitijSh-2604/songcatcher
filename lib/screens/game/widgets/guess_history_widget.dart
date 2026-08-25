import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../utils/responsive.dart';

class GuessHistoryWidget extends StatefulWidget {
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
  State<GuessHistoryWidget> createState() => _GuessHistoryWidgetState();
}

class _GuessHistoryWidgetState extends State<GuessHistoryWidget> {
  late Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(GuessHistoryWidget old) {
    super.didUpdateWidget(old);
    if (old.roomId != widget.roomId || old.roundNumber != widget.roundNumber) {
      _stream = _buildStream();
    }
  }

  Stream<QuerySnapshot> _buildStream() {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('guesses')
        .where('roundNumber', isEqualTo: widget.roundNumber)
        .orderBy('timestamp')
        .limit(50)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final guess = data['guess'] as String? ?? '';
            final correct = data['correct'] as bool? ?? false;
            final displayName = data['displayName'] as String? ?? 'Player';
            final isMe = data['userId'] == widget.userId;

            if (correct) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NeubrutalistContainer(
                  color: const Color(0xFFFFFF00),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        '$displayName',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black),
                      ),
                      const Text(
                        'guessed it!',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: NeubrutalistContainer(
                  color: isMe 
                      ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5E5EFF) : const Color(0xFF0001BB))
                      : Theme.of(context).cardColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shadowOffset: 2,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: isMe ? 'You: ' : '$displayName: ',
                          style: TextStyle(
                            color: isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                          text: guess,
                          style: TextStyle(
                            color: isMe ? Colors.white.withOpacity(0.9) : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
