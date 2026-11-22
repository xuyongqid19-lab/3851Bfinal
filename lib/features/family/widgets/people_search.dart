import '../data/directory_repository.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/family_service.dart';
import '../models/identity.dart';
import 'tags.dart';

/// Search state lives outside the canvas. Request generations reject stale replies.
class FamilyPeopleSearch extends StatefulWidget {
  const FamilyPeopleSearch(
      {super.key,
      required this.api,
      required this.groupId,
      required this.onSelected,
      this.onClear});
  final FamilyService api;
  final String groupId;
  final Future<void> Function(FamilyPerson) onSelected;
  final VoidCallback? onClear;
  @override
  State<FamilyPeopleSearch> createState() => _FamilyPeopleSearchState();
}

class _FamilyPeopleSearchState extends State<FamilyPeopleSearch> {
  final input = TextEditingController();
  Timer? timer;
  int generation = 0;
  bool busy = false, chosen = false;
  String? error;
  List<FamilyPerson> results = [];
  int? next;
  @override
  void dispose() {
    generation++;
    timer?.cancel();
    input.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FamilyPeopleSearch old) {
    super.didUpdateWidget(old);
    if (old.groupId != widget.groupId) {
      generation++;
      timer?.cancel();
      input.clear();
      results = [];
      chosen = false;
      next = null;
      busy = false;
      error = null;
    }
  }

  void changed(String _) {
    timer?.cancel();
    generation++;
    setState(() {
      results = [];
      chosen = false;
      error = null;
      next = null;
      busy = false;
    });
    if (input.text.trim().isNotEmpty) {
      timer = Timer(const Duration(milliseconds: 300), () => search());
    } else {
      widget.onClear?.call();
    }
  }

  Future<void> search({int offset = 0}) async {
    final g = ++generation;
    setState(() => busy = true);
    try {
      final page = await FamilyDirectoryRepository(widget.api)
          .search(widget.groupId, input.text, offset: offset);
      if (!mounted || g != generation) return;
      setState(() {
        results = offset == 0 ? page.items : [...results, ...page.items];
        next = page.nextOffset;
        error = null;
      });
    } catch (e) {
      if (mounted && g == generation) {
        setState(() {
          error = e.toString();
          results = [];
          next = null;
        });
      }
    } finally {
      if (mounted && g == generation) setState(() => busy = false);
    }
  }

  Future<void> select(FamilyPerson p) async {
    timer?.cancel();
    final g = ++generation;
    setState(() => busy = true);
    try {
      await widget.onSelected(p);
      if (mounted && g == generation) {
        setState(() {
          results = [];
          next = null;
          error = null;
          chosen = true;
        });
      }
    } catch (e) {
      if (mounted && g == generation) {
        setState(() {
          error = e.toString();
          results = [];
          next = null;
        });
      }
    } finally {
      if (mounted && g == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: input,
            maxLength: 100,
            onChanged: changed,
            decoration: InputDecoration(
                labelText: 'Search by name',
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      input.clear();
                      changed('');
                    },
                    icon: const Icon(Icons.close)))),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Row(children: [
            Expanded(child: Text(error!)),
            TextButton(
                onPressed: () => search(), child: const Text('Retry search'))
          ]),
        if (!chosen &&
            !busy &&
            error == null &&
            input.text.trim().isNotEmpty &&
            results.isEmpty)
          const Text(
              'No matching people. Search only includes this connected tree.'),
        if (results.isNotEmpty)
          ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: ListView(shrinkWrap: true, children: [
                for (final p in results)
                  Semantics(
                      button: true,
                      label: 'Locate ${p.name} in ${p.familyName}',
                      child: InkWell(
                          onTap: busy ? null : () => select(p),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 4),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        flex: 2,
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(p.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(
                                                  '${p.familyName}${p.demo ? ' · Demo data' : ''}',
                                                  style: const TextStyle(
                                                      fontSize: 12))
                                            ])),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        flex: 3,
                                        child: FamilyTagRow([
                                          ...p.groupTags,
                                          ...p.personalTags
                                        ]))
                                  ])))),
                if (next != null)
                  TextButton(
                      onPressed: busy ? null : () => search(offset: next!),
                      child: const Text('More results'))
              ]))
      ]);
}
