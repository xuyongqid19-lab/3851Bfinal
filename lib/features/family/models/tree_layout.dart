import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/family_tree.dart';

/// Uniform row geometry is recomputed when expansion or text scaling changes.
/// The subtree intervals retain all edges and never overlap sibling cards.
class FamilyTreeLayout {
  FamilyTreeLayout(FamilyTreeSnapshot tree,
      {double textScale = 1, Set<String> expanded = const {}}) {
    rowHeight = 64 * textScale;
    headerHeight = 156 * textScale;
    final count = tree.nodes.fold<int>(
        0,
        (n, g) => math.max(
            n,
            expanded.contains(g['id'])
                ? (g['people'] as List? ?? []).length
                : math.min(5, (g['people'] as List? ?? []).length)));
    nodeSize = Size(300 * textScale,
        headerHeight + (count == 0 ? 0 : count * rowHeight + 52 * textScale));
    final children = <String, List<String>>{};
    for (final n in tree.outline) {
      if (n['parent'] != null) {
        children.putIfAbsent(n['parent'], () => []).add(n['id']);
      }
    }
    double leaf = 0;
    double place(String id, int depth) {
      final ys = [
        for (final c in children[id] ?? <String>[]) place(c, depth + 1)
      ];
      final y = ys.isEmpty
          ? leaf++ * (nodeSize.height + 44)
          : (ys.first + ys.last) / 2;
      positions[id] = Offset(40 + depth * (nodeSize.width + 100), 40 + y);
      return y;
    }

    if (tree.nodes.isNotEmpty) place(tree.groupId, 0);
    size = Size(
        positions.values.fold(0.0, (v, p) => math.max(v, p.dx)) +
            nodeSize.width +
            40,
        positions.values.fold(0.0, (v, p) => math.max(v, p.dy)) +
            nodeSize.height +
            40);
  }
  final positions = <String, Offset>{};
  late final Size nodeSize, size;
  late final double rowHeight, headerHeight;
  Offset personCenter(String groupId, int index) =>
      positions[groupId]! +
      Offset(nodeSize.width / 2, headerHeight + (index + .5) * rowHeight);
}

class FamilyConnectionsPainter extends CustomPainter {
  FamilyConnectionsPainter(this.tree, this.layout);
  final FamilyTreeSnapshot tree;
  final FamilyTreeLayout layout;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = const Color(0xFF456A91)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final n in tree.outline.where((n) => n['parent'] != null)) {
      final a = layout.positions[n['parent']]! +
              Offset(layout.nodeSize.width, layout.headerHeight / 2),
          b = layout.positions[n['id']]! + Offset(0, layout.headerHeight / 2),
          mid = (a.dx + b.dx) / 2;
      canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(mid, a.dy)
            ..lineTo(mid, b.dy)
            ..lineTo(b.dx, b.dy),
          pen);
    }
  }

  @override
  bool shouldRepaint(covariant FamilyConnectionsPainter old) =>
      old.tree != tree || old.layout != layout;
}
