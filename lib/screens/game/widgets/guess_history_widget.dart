import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/room_provider.dart';
import '../../../utils/responsive.dart';

class GuessHistoryWidget extends ConsumerStatefulWidget {
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
  ConsumerState<GuessHistoryWidget> createState() => _GuessHistoryWidgetState();
}

class _GuessHistoryWidgetState extends ConsumerState<GuessHistoryWidget> {
  late Stream<QuerySnapshot> _stream;
  final ScrollController _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Stream<QuerySnapshot> _buildStream() {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('guesses')
        .orderBy('timestamp')
        .limit(100)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        
        // 📜 Auto-scroll on new message
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(context.fs(8, max: 12)),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final guess = data['guess'] as String? ?? '';
                  final correct = data['correct'] as bool? ?? false;
                  final isAnnouncement = data['isAnnouncement'] as bool? ?? false;
                  final displayName = data['displayName'] as String? ?? 'Player';
                  final isMe = data['userId'] == widget.userId;

                  if (isAnnouncement) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: context.fs(8, max: 16)),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: context.fs(12, max: 20), vertical: context.fs(4, max: 8)),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black, offset: Offset(context.fs(2, max: 3), context.fs(2, max: 3))),
                            ],
                          ),
                          child: Text(
                            guess,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: context.ff(11, max: 14),
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (correct) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: context.fs(6, max: 12)),
                      child: NeubrutalistContainer(
                        color: const Color(0xFF00FF00),
                        padding: EdgeInsets.symmetric(vertical: context.fs(6, max: 12), horizontal: context.fs(10, max: 16)),
                        child: Column(
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: context.ff(12, max: 14), color: Colors.black),
                            ),
                            Text(
                              'guessed it!',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: context.ff(11, max: 14), color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: context.fs(4, max: 8)),
                    child: Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: NeubrutalistContainer(
                        color: isMe 
                            ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5E5EFF) : const Color(0xFF0001BB))
                            : Theme.of(context).cardColor,
                        padding: EdgeInsets.symmetric(horizontal: context.fs(10, max: 16), vertical: context.fs(6, max: 10)),
                        shadowOffset: 2,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: isMe ? 'You: ' : '$displayName: ',
                                style: TextStyle(
                                  color: isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: context.ff(11, max: 13),
                                ),
                              ),
                              TextSpan(
                                text: guess,
                                style: TextStyle(
                                  color: isMe ? Colors.white.withOpacity(0.9) : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.ff(11, max: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // ✍️ Typing Indicator
            Consumer(builder: (context, ref, _) {
              final players = ref.watch(playersProvider(widget.roomId)).valueOrNull ?? [];
              final typingPlayers = players.where((p) => p.isTyping && p.id != widget.userId).toList();
              
              if (typingPlayers.isEmpty) return const SizedBox.shrink();
              
              final String text = typingPlayers.length > 2 
                ? '${typingPlayers.length} people are typing...'
                : typingPlayers.length == 2
                  ? '${typingPlayers[0].displayName} and ${typingPlayers[1].displayName} are typing...'
                  : '${typingPlayers[0].displayName} is typing...';

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).hintColor.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
