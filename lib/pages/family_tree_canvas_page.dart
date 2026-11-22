import '../features/family/data/directory_repository.dart';
import '../features/family/models/tree_layout.dart';
export '../features/family/models/tree_layout.dart' show FamilyTreeLayout;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/family_group.dart';
import '../models/family_tree.dart';
import '../services/family_service.dart';
import '../features/family/models/identity.dart';
import '../features/family/widgets/people_search.dart';
import '../features/family/widgets/tags.dart';
import 'family_page.dart';

class FamilyTreeCanvasPage extends StatefulWidget {
  const FamilyTreeCanvasPage(
      {super.key, required this.api, required this.initial, this.focusPerson});
  final FamilyService api;
  final FamilyTreeSnapshot initial;
  final FamilyPerson? focusPerson;
  @override
  State<FamilyTreeCanvasPage> createState() => _FamilyTreeCanvasPageState();
}

class _FamilyTreeCanvasPageState extends State<FamilyTreeCanvasPage>
    with SingleTickerProviderStateMixin {
  final transform = TransformationController();
  late final animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350));
  Animation<Matrix4>? movement;
  late FamilyTreeSnapshot tree = widget.initial;
  FamilyTreeLayout? layout;
  Size viewport = Size.zero;
  String? error;
  bool loading = false;
  FamilyPerson? selected;
  final expanded = <String>{};
  int generation = 0, searchEpoch = 0;
  @override
  void initState() {
    super.initState();
    animation.addListener(() => transform.value = movement!.value);
    if (widget.focusPerson != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) locate(widget.focusPerson!).catchError((Object _) {});
      });
    }
  }

  @override
  void dispose() {
    generation++;
    animation.dispose();
    transform.dispose();
    super.dispose();
  }

  void fit() {
    animation.stop();
    final l = layout;
    if (l == null || viewport.isEmpty) return;
    final s = math
        .min(viewport.width / l.size.width, viewport.height / l.size.height)
        .clamp(.01, 1.0);
    transform.value = Matrix4.identity()
      ..translateByDouble((viewport.width - l.size.width * s) / 2,
          (viewport.height - l.size.height * s) / 2, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  void zoom(double s) {
    animation.stop();
    final centre = Offset(viewport.width / 2, viewport.height / 2),
        point = transform.toScene(centre);
    s = s.clamp(.01, 3);
    transform.value = Matrix4.identity()
      ..translateByDouble(
          centre.dx - point.dx * s, centre.dy - point.dy * s, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  void focus() {
    final p = selected, l = layout;
    if (p == null || l == null || viewport.isEmpty) return;
    final node = tree.nodes.where((n) => n['id'] == p.groupId).firstOrNull;
    if (node == null) return;
    final i =
        (node['people'] as List? ?? []).indexWhere((m) => m['id'] == p.id);
    if (i < 0) return;
    final target = l.personCenter(p.groupId, i);
    final matrix = Matrix4.identity()
      ..translateByDouble(viewport.width / 2 - target.dx,
          viewport.height / 2 - target.dy, 0, 1);
    movement = Matrix4Tween(begin: transform.value.clone(), end: matrix)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
    animation.forward(from: 0);
  }

  Future<void> refresh() async {
    final g = ++generation;
    setState(() {
      loading = true;
      error = null;
      selected = null;
      searchEpoch++;
    });
    try {
      final d =
          await widget.api.request('GET', '/families/${tree.groupId}/tree');
      if (!mounted || g != generation) return;
      setState(() {
        tree = FamilyTreeSnapshot(d);
        layout = null;
      });
    } catch (e) {
      if (mounted && g == generation) setState(() => error = e.toString());
    } finally {
      if (mounted && g == generation) setState(() => loading = false);
    }
  }

  Future<void> locate(FamilyPerson p) async {
    final g = ++generation;
    try {
      final repository = FamilyDirectoryRepository(widget.api);
      final resolved = await repository.resolve(tree.groupId, p);
      final fresh = await repository.tree(tree.groupId);
      if (!mounted || g != generation) return;
      final node = fresh.nodes.where((n) => n['id'] == p.groupId).firstOrNull;
      if (node == null ||
          !(node['people'] as List? ?? []).any((n) => n['id'] == p.id)) {
        throw const FamilyApiException(
            'This person is no longer in the connected tree.');
      }
      setState(() {
        tree = fresh;
        selected = resolved;
        expanded.add(p.groupId);
        layout = null;
        error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus();
      });
    } catch (e) {
      if (mounted && g == generation) {
        setState(() {
          selected = null;
          error = e.toString();
          searchEpoch++;
        });
      }
      rethrow;
    }
  }

  Future<void> details(FamilyJson n) async {
    final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                scrollable: true,
                constraints: const BoxConstraints(maxWidth: 600),
                title: Text(n['name']),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (n['demo'] == true)
                        const Text('Demo data - Fictional members'),
                      for (final e in tree.connections
                          .where((e) => e['a'] == n['id'] || e['b'] == n['id']))
                        Text(
                            '${tree.name(e['a'] == n['id'] ? e['b'] : e['a'])}: ${e['label']}'),
                      Text(n['canOpen'] == true
                          ? 'You belong to this family and can open its details.'
                          : 'Connected group only. Private records stay separate.')
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Close')),
                  if (n['canOpen'] == true)
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Open family'))
                ]));
    if (open == true && mounted) {
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) =>
                  FamilyGroupPage(api: widget.api, groupId: n['id'])));
      if (mounted) await refresh();
    }
  }

  Widget nodeCard(FamilyJson n, double textScale) {
    final all = n['people'] as List? ?? [],
        people = expanded.contains(n['id']) ? all : all.take(5).toList(),
        l = layout!;
    return Card(
        margin: EdgeInsets.zero,
        color: n['id'] == selected?.groupId || n['id'] == tree.groupId
            ? const Color(0xFFDCEBFF)
            : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF71889F), width: 2)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              height: l.headerHeight,
              child: Semantics(
                  button: true,
                  label:
                      '${n['name']}. ${n['id'] == tree.groupId ? 'Selected family.' : 'Connected family.'} View details',
                  excludeSemantics: true,
                  child: InkWell(
                      onTap: () => details(n),
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n['name'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(
                                    n['demo'] == true
                                        ? 'Demo data - Fictional'
                                        : n['id'] == tree.groupId
                                            ? 'Selected family'
                                            : n['label'] ?? 'Connected family',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                const Spacer(),
                                const Text('Tap for details',
                                    style: TextStyle(fontSize: 12))
                              ]))))),
          for (final m in people)
            SizedBox(
                height: l.rowHeight,
                child: Material(
                    color:
                        selected?.id == m['id'] && selected?.groupId == n['id']
                            ? const Color(0xFFFFE082)
                            : Colors.transparent,
                    child: InkWell(
                        key: ValueKey('person-${n['id']}-${m['id']}'),
                        onTap: () => locate(FamilyPerson.fromJson({
                              ...Map<String, dynamic>.from(m as Map),
                              'groupId': n['id'],
                              'familyName': n['name'],
                              'familyTags': n['familyTags'] ?? [],
                              'personalTags': m['tags'] ?? []
                            })).catchError((Object _) {}),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(m['name'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 16))))))),
          if (all.isNotEmpty)
            SizedBox(
                height: 52 * textScale,
                child: TextButton(
                    onPressed: all.length > 5
                        ? () {
                            setState(() {
                              expanded.contains(n['id'])
                                  ? expanded.remove(n['id'])
                                  : expanded.add(n['id']);
                              selected = null;
                              layout = null;
                            });
                          }
                        : null,
                    child: Text(all.length > 5
                        ? (expanded.contains(n['id'])
                            ? 'Show fewer members'
                            : 'Show all ${all.length} members')
                        : '${all.length} members'))),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    if (layout == null || layout!.nodeSize.width != 300 * scale) {
      layout = FamilyTreeLayout(tree, textScale: scale, expanded: expanded);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (selected != null) {
            focus();
          } else {
            fit();
          }
        }
      });
    }
    final l = layout!;
    return Scaffold(
        appBar: AppBar(title: const Text('Large family tree'), actions: [
          IconButton(
              tooltip: 'Refresh tree',
              onPressed: loading ? null : refresh,
              icon: const Icon(Icons.refresh))
        ]),
        body: SafeArea(
            child: Column(children: [
          ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .48),
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(children: [
                        if (error == null)
                          FamilyPeopleSearch(
                              key: ValueKey(searchEpoch),
                              api: widget.api,
                              groupId: tree.groupId,
                              onSelected: locate,
                              onClear: () => setState(() => selected = null)),
                        Text(
                            error == null
                                ? '${tree.nodes.length} families - Drag to move. Lines show connections, not ancestry.'
                                : 'Unable to load this tree.',
                            textAlign: TextAlign.center),
                        if (selected != null)
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(children: [
                                Text(
                                    '${selected!.name} - ${selected!.familyName}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                FamilyTagRow([
                                  ...selected!.groupTags,
                                  ...selected!.personalTags
                                ])
                              ])),
                        Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                  onPressed: loading || error != null
                                      ? null
                                      : () => zoom(
                                          transform.value.getMaxScaleOnAxis() *
                                              1.3),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Zoom in')),
                              OutlinedButton.icon(
                                  onPressed: loading || error != null
                                      ? null
                                      : () => zoom(
                                          transform.value.getMaxScaleOnAxis() /
                                              1.3),
                                  icon: const Icon(Icons.remove),
                                  label: const Text('Zoom out')),
                              FilledButton.icon(
                                  onPressed: loading || error != null
                                      ? null
                                      : () {
                                          setState(() => selected = null);
                                          fit();
                                        },
                                  icon: const Icon(Icons.fit_screen),
                                  label: const Text('Show all')),
                              OutlinedButton(
                                  onPressed: loading || error != null
                                      ? null
                                      : () => zoom(1),
                                  child: const Text('100%'))
                            ])
                      ])))),
          Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(error!),
                                    FilledButton(
                                        onPressed: refresh,
                                        child: const Text('Retry'))
                                  ])))
                      : LayoutBuilder(builder: (context, c) {
                          if (viewport != c.biggest) {
                            viewport = c.biggest;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                if (selected != null) {
                                  focus();
                                } else {
                                  fit();
                                }
                              }
                            });
                          }
                          return ColoredBox(
                              color: const Color(0xFFF0F5FA),
                              child: InteractiveViewer(
                                  key: const ValueKey('tree-canvas'),
                                  transformationController: transform,
                                  constrained: false,
                                  alignment: Alignment.topLeft,
                                  boundaryMargin: const EdgeInsets.all(200000),
                                  minScale: .01,
                                  maxScale: 3,
                                  child: SizedBox(
                                      width: l.size.width,
                                      height: l.size.height,
                                      child: Stack(children: [
                                        Positioned.fill(
                                            child: CustomPaint(
                                                painter:
                                                    FamilyConnectionsPainter(
                                                        tree, l))),
                                        for (final n in tree.outline)
                                          Positioned(
                                              left: l.positions[n['id']]!.dx,
                                              top: l.positions[n['id']]!.dy,
                                              width: l.nodeSize.width,
                                              height: l.nodeSize.height,
                                              child: nodeCard(n, scale))
                                      ]))));
                        })),
        ])));
  }
}
