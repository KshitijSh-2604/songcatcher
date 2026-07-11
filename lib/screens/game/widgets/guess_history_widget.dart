import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
    // Only recreate the stream if the query parameters actually changed.
    // Recreating on every build is what causes the Firestore ca9 internal
    // assertion error on Flutter Web.
    if (old.roomId != widget.roomId ||
        old.roundNumber != widget.roundNumber) {
      _stream = _buildStream();
    }
  }

  Stream<QuerySnapshot> _buildStream() {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('guesses')
        .where('roundNumber', isEqualTo: widget.roundNumber)
        .orderBy('timestamp')   // ascending — newest at bottom
        .limit(50)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (_, snap) {
        // ── Error state ────────────────────────────────────────────────
        if (snap.hasError) {
          // Print to Flutter debug console so you can see the Firestore
          // index link (or any other error detail) without opening DevTools.
          debugPrint('[GuessHistoryWidget] Firestore error: ${snap.error}');
          debugPrint('[GuessHistoryWidget] Stack: ${snap.stackTrace}');

          return Center(
            child: Padding(
              padding: EdgeInsets.all(context.fs(16, max: 24)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: context.ff(22, max: 30)),
                  Gap(context.fs(8, max: 12)),
                  Text(
                    'Chat unavailable',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: context.ff(13, max: 16)),
                  ),
                  Gap(context.fs(4, max: 6)),
                  Text(
                    snap.error.toString(),
                    style: TextStyle(
                        color: Colors.white30,
                        fontSize: context.ff(10, max: 12)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // ── Loading state ──────────────────────────────────────────────
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ── Empty state ────────────────────────────────────────────────
        if (snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🎧',
                    style: TextStyle(fontSize: context.ff(26, max: 40))),
                Gap(context.fs(6, max: 10)),
                Text(
                  'Play the clip and start guessing!',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: context.ff(12, max: 15)),
                ),
              ],
            ),
          );
        }

        // ── Guess feed ────────────────────────────────────────────────
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.symmetric(
              horizontal: context.fs(12, max: 20),
              vertical: context.fs(8, max: 14)),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data        = docs[i].data() as Map<String, dynamic>;
            final guess       = data['guess']       as String? ?? '';
            final correct     = data['correct']     as bool?   ?? false;
            final displayName = data['displayName'] as String? ?? 'Player';
            final isMe        = data['userId'] == widget.userId;

            final bubbleText =
            correct ? '🎉 $displayName caught it!' : guess;

            return Padding(
              padding: EdgeInsets.only(bottom: context.fs(5, max: 8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: context.fs(3, max: 4)),
                    child: Icon(
                      correct
                          ? Icons.check_circle_rounded
                          : Icons.chat_bubble_outline_rounded,
                      color:
                      correct ? Colors.greenAccent : Colors.white38,
                      size: context.ff(16, max: 20),
                    ),
                  ),
                  SizedBox(width: context.fs(8, max: 12)),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.fs(12, max: 18),
                          vertical: context.fs(7, max: 10)),
                      decoration: BoxDecoration(
                        color: correct
                            ? Colors.green.withOpacity(0.14)
                            : (isMe
                            ? Colors.purpleAccent.withOpacity(0.08)
                            : Colors.white.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: correct
                              ? Colors.green.withOpacity(0.35)
                              : (isMe
                              ? Colors.purpleAccent.withOpacity(0.25)
                              : Colors.white12),
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
                                color: isMe
                                    ? Colors.purpleAccent
                                    : Colors.white54,
                                fontWeight: FontWeight.w600,
                                fontSize: context.ff(12, max: 15),
                              ),
                            ),
                            TextSpan(
                              text: guess,
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: context.ff(13, max: 16)),
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