import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_manager.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() => _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  List<NotificationInboxItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final list = await NotificationManager.getNotifications();

    // Mark all loaded as read
    for (final item in list) {
      if (!item.read) {
        await NotificationManager.markAsRead(item.id);
        item.read = true;
      }
    }

    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNotification(String id) async {
    await NotificationManager.deleteNotification(id);
    setState(() {
      _notifications.removeWhere((item) => item.id == id);
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF263238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Smazat vše?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Opravdu si přeješ vymazat celou historii oznámení?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušit', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Smazat vše', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationManager.clearAll();
      setState(() {
        _notifications.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Historie oznámení byla vymazána.'), backgroundColor: Color(0xFF263238)),
        );
      }
    }
  }

  Future<void> _reportAndBlock(String senderUid, String messageBody, String notificationId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF263238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Nahlásit a zablokovat?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Zvolte důvod nahlášení. Uživatel vám již nebude moci posílat další šťouchnutí.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'Spam'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Spam'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'Nevhodný text'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Nevhodný text'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );

    if (reason == null) return;

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    try {
      // 1. Zapsat report do Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'reported_uid': senderUid,
        'reporter_uid': myUid,
        'reason': reason,
        'message': messageBody,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Nastavit nudges_blocked: true v přátelích
      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(senderUid)
          .set({'nudges_blocked': true}, SetOptions(merge: true));

      // 3. Smazat oznámení z lokální historie
      await _deleteNotification(notificationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uživatel byl nahlášen ($reason) a šťouchání zablokováno.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při blokování: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return 'před ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'před ${diff.inHours} hod';
    } else {
      return '${dt.day}. ${dt.month}. v ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Oznámení',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: const Color(0xFF263238),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFBFFF00)),
              tooltip: 'Vymazat vše',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF5C9E00)))
            : _notifications.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: const Color(0xFF5C9E00),
                    onRefresh: _loadNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        return Dismissible(
                          key: Key(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
                          ),
                          onDismissed: (direction) => _deleteNotification(item.id),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                              border: Border.all(
                                color: item.read ? Colors.transparent : const Color(0xFFBFFF00).withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: item.read ? const Color(0xFFF1F5F9) : const Color(0xFFBFFF00).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.read ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                                  color: item.read ? Colors.black54 : const Color(0xFF5C9E00),
                                  size: 24,
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                        color: item.read ? Colors.black87 : const Color(0xFF263238),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDateTime(item.timestamp),
                                    style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      item.body,
                                      style: const TextStyle(color: Colors.black54, fontSize: 12.5, height: 1.4),
                                    ),
                                  ),
                                  if (item.senderUid != null && item.title.contains('Šťouchnutí'))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: () => _reportAndBlock(item.senderUid!, item.body, item.id),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 0),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: const Icon(Icons.report_problem_outlined, size: 14, color: Colors.redAccent),
                                          label: const Text(
                                            'Nahlásit / Blokovat',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                  )
                ],
              ),
              child: const Icon(Icons.notifications_off_outlined, size: 72, color: Colors.black26),
            ),
            const SizedBox(height: 20),
            const Text(
              'Žádná nová oznámení',
              style: TextStyle(fontSize: 18, color: Color(0xFF263238), fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Zde uvidíš historii všech svých splněných úkolů, her a zpráv od přátel.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
