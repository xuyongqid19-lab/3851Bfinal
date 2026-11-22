import 'package:flutter/material.dart';
import '../../../services/family_service.dart';
import '../../../models/family_group.dart';
import '../../../pages/family_tree_page.dart';

class FamilyNotificationsPage extends StatefulWidget {
  const FamilyNotificationsPage({super.key, required this.api});
  final FamilyService api;
  @override
  State<FamilyNotificationsPage> createState() =>
      _FamilyNotificationsPageState();
}

class _FamilyNotificationsPageState extends State<FamilyNotificationsPage> {
  List<FamilyJson> items = [];
  String? error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await widget.api.request('GET', '/family-notifications');
      if (mounted) {
        setState(() {
          items = (d['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> read(FamilyJson n, bool value) async {
    try {
      await widget.api.request(
          'PUT', '/family-notifications/${n['id']}', {'isRead': value});
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Family notifications'), actions: [
        IconButton(
            tooltip: 'Refresh notifications',
            onPressed: load,
            icon: const Icon(Icons.refresh))
      ]),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (error != null) Text(error!),
                    if (items.isEmpty && error == null)
                      const Text('No notifications yet.'),
                    for (final n in items)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n['message'],
                                        style: TextStyle(
                                            fontWeight: n['isRead'] == true
                                                ? FontWeight.normal
                                                : FontWeight.bold)),
                                    Text(n['createdAt']),
                                    Wrap(spacing: 8, children: [
                                      TextButton(
                                          onPressed: () async {
                                            await read(n, true);
                                            if (context.mounted) {
                                              await Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          FamilyTreePage(
                                                              api: widget.api,
                                                              groupId: n[
                                                                  'groupId'])));
                                              if (mounted) await load();
                                            }
                                          },
                                          child:
                                              const Text('View current tree')),
                                      TextButton(
                                          onPressed: () =>
                                              read(n, n['isRead'] != true),
                                          child: Text(n['isRead'] == true
                                              ? 'Mark unread'
                                              : 'Mark read'))
                                    ])
                                  ])))
                  ])));
}
