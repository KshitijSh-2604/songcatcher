import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/room_provider.dart';
import '../../../utils/responsive.dart';
import '../../../services/game_service.dart'; // 🆕 Add import

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
    final collection = widget.roundNumber == 0 ? 'lobby_guesses' : 'guesses';
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection(collection)
        .orderBy('timestamp')
        .limit(100)
        .snapshots();
  }

  void _showReactionPicker(BuildContext context, String messageId, Offset messagePos, Size messageSize) {
    final emojis = ['👌', '😂', '🤣', '❤️', '😭', '🤓', '💀', '😦', '😎', '🤖'];
    
    // 🆕 Use an OverlayEntry for precise positioning above the message
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => entry.remove(),
        child: Stack(
          children: [
            Positioned(
              // Position above the message bubble
              top: (messagePos.dy - 60).clamp(80.0, MediaQuery.of(context).size.height - 100),
              // Try to align horizontally with the message, but keep it on screen
              left: (messagePos.dx).clamp(20.0, MediaQuery.of(context).size.width - 320),
              child: Material(
                color: Colors.transparent,
                child: NeubrutalistContainer(
                  color: Colors.white, 
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  shadowOffset: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min, 
                    children: emojis.map((e) => GestureDetector(
                      onTap: () {
                        final isLobby = widget.roundNumber == 0;
                        GameService().addReaction(
                          roomId: widget.roomId,
                          userId: widget.userId,
                          messageId: messageId,
                          emoji: e,
                          isLobby: isLobby,
                        );
                        entry.remove();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.02),
                          shape: BoxShape.circle,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(entry);
  }

  Widget _buildAnnouncement(String text) {
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
            text,
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

  Widget _buildCorrectGuess(String name) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.fs(6, max: 12)),
      child: NeubrutalistContainer(
        color: const Color(0xFF00FF00),
        padding: EdgeInsets.symmetric(vertical: context.fs(6, max: 12), horizontal: context.fs(10, max: 16)),
        child: Column(
          children: [
            Text(
              name,
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
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final guess = data['guess'] as String? ?? '';
                  final correct = data['correct'] as bool? ?? false;
                  final isChat = data['isChat'] as bool? ?? false; // 🆕
                  final isAnnouncement = data['isAnnouncement'] as bool? ?? false;
                  final displayName = data['displayName'] as String? ?? 'Player';
                  final reactions = Map<String, String>.from(data['reactions'] ?? {}); // 🆕
                  final isMe = data['userId'] == widget.userId;

                  if (isAnnouncement) {
                    return _buildAnnouncement(guess);
                  }

                  if (correct) {
                    return _buildCorrectGuess(displayName);
                  }

                  final bool isFromCorrectGuesser = isChat; // Messages from those who already guessed
                  
                  return Padding(
                    padding: EdgeInsets.only(bottom: context.fs(4, max: 8)),
                    child: Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Builder(builder: (ctx) {
                        return GestureDetector(
                          onLongPress: () {
                            final RenderBox box = ctx.findRenderObject() as RenderBox;
                            final Offset position = box.localToGlobal(Offset.zero);
                            _showReactionPicker(context, doc.id, position, box.size);
                          },
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              NeubrutalistContainer(
                                color: isMe 
                                    ? (isFromCorrectGuesser ? Colors.green.shade700 : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5E5EFF) : const Color(0xFF0001BB)))
                                    : (isFromCorrectGuesser ? Colors.green.shade100 : Theme.of(context).cardColor),
                                padding: EdgeInsets.symmetric(horizontal: context.fs(10, max: 16), vertical: context.fs(6, max: 10)),
                                shadowOffset: 2,
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: isMe ? 'You: ' : '$displayName: ',
                                        style: TextStyle(
                                          color: isMe ? Colors.white : (isFromCorrectGuesser ? Colors.green.shade900 : Theme.of(context).textTheme.bodyLarge?.color),
                                          fontWeight: FontWeight.w900,
                                          fontSize: context.ff(11, max: 13),
                                        ),
                                      ),
                                      TextSpan(
                                        text: guess,
                                        style: TextStyle(
                                          color: isMe ? Colors.white.withOpacity(0.9) : (isFromCorrectGuesser ? Colors.green.shade800 : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8)),
                                          fontWeight: FontWeight.w600,
                                          fontSize: context.ff(11, max: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (reactions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: () {
                                      // 🆕 Stack identical reactions
                                      final Map<String, int> counts = {};
                                      for (var e in reactions.values) {
                                        counts[e] = (counts[e] ?? 0) + 1;
                                      }

                                      return counts.entries.map((entry) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.black, width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(entry.key, style: const TextStyle(fontSize: 14)),
                                            if (entry.value > 1) ...[
                                              const SizedBox(width: 4),
                                              Text(
                                                '${entry.value}', 
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black),
                                              ),
                                            ],
                                          ],
                                        ),
                                      )).toList();
                                    }(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
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
