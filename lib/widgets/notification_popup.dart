import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../utils/responsive.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPopup extends ConsumerWidget {
  const NotificationPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final invites = ref.watch(invitesProvider(user.uid)).valueOrNull ?? [];
    final friendRequests = ref.watch(pendingRequestsProvider(user.uid)).valueOrNull ?? [];
    final globalNotifs = ref.watch(globalNotificationsProvider).valueOrNull ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    final allItems = [
      ...invites.map((i) => _NotifItem(
        id: i['id'],
        title: 'Match Invite',
        body: '${i['fromName']} invited you to join Arena ${i['roomCode']}',
        timestamp: (i['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        color: const Color(0xFFFFFF00),
        isRead: i['status'] != 'pending',
        onTap: () {
          ref.read(friendServiceProvider).markInviteAsRead(i['id']);
          context.go('/lobby/${i['roomId']}');
          Navigator.pop(context);
        },
        onDelete: () => ref.read(friendServiceProvider).clearInvite(i['id']),
      )),
      ...friendRequests.where((f) => f.requestedBy != user.uid).map((f) => _NotifItem(
        id: f.id,
        title: 'Friend Request',
        body: 'You have a new incoming friend request.',
        timestamp: f.createdAt,
        color: const Color(0xFF4D4DFF),
        textColor: Colors.white,
        isRead: f.isRead,
        onTap: () {
          ref.read(friendServiceProvider).markFriendRequestAsRead(f.id);
          context.go('/friends');
          Navigator.pop(context);
        },
        // For friend requests, delete means reject
        onDelete: () => ref.read(friendServiceProvider).rejectFriendRequest(f.id),
      )),
      ...globalNotifs.map((g) {
        final ts = (g['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final isRead = userProfile?.lastReadGlobalNotificationAt != null && 
                       ts.isBefore(userProfile!.lastReadGlobalNotificationAt!);
        return _NotifItem(
          id: g['id'],
          title: g['title'] ?? 'System Update',
          body: g['body'] ?? '',
          timestamp: ts,
          color: const Color(0xFF00FF00),
          isRead: isRead,
          onTap: () {
            ref.read(userServiceProvider).updateLastReadGlobalNotification(user.uid);
            Navigator.pop(context);
          },
          // Global notifications can't be individual deleted by user usually, 
          // but we can hide them or leave empty. For now, omit delete or show warning.
        );
      }),
    ];

    allItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Material(
      color: Colors.transparent,
      child: NeubrutalistContainer(
        color: bgColor,
        padding: const EdgeInsets.all(16),
        width: context.isMobile ? MediaQuery.of(context).size.width * 0.9 : 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined, size: 20),
                const SizedBox(width: 8),
                const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const Spacer(),
                if (allItems.any((i) => !i.isRead))
                   TextButton(
                     onPressed: () {
                        // Mark all as read
                        for (var i in invites) ref.read(friendServiceProvider).markInviteAsRead(i['id']);
                        for (var f in friendRequests) if (f.requestedBy != user.uid) ref.read(friendServiceProvider).markFriendRequestAsRead(f.id);
                        ref.read(userServiceProvider).updateLastReadGlobalNotification(user.uid);
                     },
                     child: const Text('Mark all as read', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                   ),
              ],
            ),
            const Divider(height: 24, thickness: 2),
            if (allItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('No notifications yet.', style: TextStyle(color: Colors.black26, fontWeight: FontWeight.w700))),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: allItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => allItems[i],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotifItem extends StatelessWidget {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final Color color;
  final Color? textColor;
  final bool isRead;
  final VoidCallback onTap;
  final VoidCallback? onDelete; // 🆕 Added delete callback

  const _NotifItem({
    required this.id, required this.title, required this.body, 
    required this.timestamp, required this.color, this.textColor, 
    required this.isRead, required this.onTap, this.onDelete
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('MMM dd, hh:mm a').format(timestamp);
    
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: isRead ? 0.6 : 1.0,
            child: NeubrutalistContainer(
              color: color,
              padding: const EdgeInsets.all(12),
              shadowOffset: isRead ? 2 : 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textColor))),
                      Text(timeStr, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: (textColor ?? Colors.black).withOpacity(0.6))),
                      if (onDelete != null) const SizedBox(width: 24), // Space for delete icon
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: (textColor ?? Colors.black).withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onDelete != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onDelete,
              color: (textColor ?? Colors.black).withOpacity(0.4),
              tooltip: 'Remove',
            ),
          ),
      ],
    );
  }
}
