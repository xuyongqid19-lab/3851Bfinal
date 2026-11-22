import 'package:flutter/material.dart';
import '../models/identity.dart';

const familyVisibilityNotice =
    'Names and display tags are visible to members of all families connected to this family tree. Personal introductions and private records stay within your own family.';

class FamilyTagRow extends StatelessWidget {
  const FamilyTagRow(this.tags, {super.key});
  final List<FamilyTag> tags;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final t in tags)
          Semantics(
              label: t.text,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                      color: t.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black26)),
                  child: Text(t.text,
                      style: TextStyle(
                          color: t.color.computeLuminance() > .179
                              ? Colors.black
                              : Colors.white,
                          fontSize: 13))))
      ]);
}

class FamilyTagEditor extends StatelessWidget {
  const FamilyTagEditor(
      {super.key,
      required this.title,
      required this.tags,
      required this.onChanged,
      this.enabled = true});
  final String title;
  final List<FamilyTag> tags;
  final ValueChanged<List<FamilyTag>> onChanged;
  final bool enabled;
  Future<void> edit(BuildContext context, [int? index]) async {
    final old = index == null ? null : tags[index];
    final label = TextEditingController(text: old?.label),
        value = TextEditingController(text: old?.value);
    var color = old?.colorId ?? 'c1';
    String? error;
    final route = DialogRoute<FamilyTag>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                    scrollable: true,
                    constraints: const BoxConstraints(maxWidth: 600),
                    title: Text(index == null ? 'Add tag' : 'Edit tag'),
                    content: SizedBox(
                        width: 480,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                  controller: label,
                                  maxLength: 30,
                                  decoration: const InputDecoration(
                                      labelText: 'Tag label')),
                              TextField(
                                  controller: value,
                                  maxLength: 60,
                                  decoration: const InputDecoration(
                                      labelText: 'Tag value (optional)')),
                              const Text(
                                  'For a personal Name tag, your family real name is used. Gender is optional. Choose a colour:'),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                for (var i = 0; i < familyPalette.length; i++)
                                  ChoiceChip(
                                      label: Text(familyPalette[i].$1),
                                      selected: color == 'c${i + 1}',
                                      avatar: CircleAvatar(
                                          backgroundColor: familyPalette[i].$2,
                                          radius: 9,
                                          child: color == 'c${i + 1}'
                                              ? Icon(Icons.check,
                                                  size: 14,
                                                  color: familyPalette[i]
                                                              .$2
                                                              .computeLuminance() >
                                                          .179
                                                      ? Colors.black
                                                      : Colors.white)
                                              : null),
                                      onSelected: (_) =>
                                          set(() => color = 'c${i + 1}'))
                              ]),
                              if (error != null)
                                Text(error!,
                                    style: const TextStyle(color: Colors.red)),
                            ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () {
                            final name = label.text.trim();
                            if (name.isEmpty ||
                                tags.indexed.any((p) =>
                                    p.$1 != index &&
                                    p.$2.label.toLowerCase() ==
                                        name.toLowerCase())) {
                              set(() => error = 'Enter a unique tag label.');
                              return;
                            }
                            Navigator.pop(
                                ctx, FamilyTag(name, value.text.trim(), color));
                          },
                          child: const Text('Save tag'))
                    ])));
    final result = await Navigator.of(context).push(route);
    await route.completed;
    label.dispose();
    value.dispose();
    if (!context.mounted) return;
    if (result != null) {
      final next = [...tags];
      if (index == null) {
        next.add(result);
      } else {
        next[index] = result;
      }
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$title (optional, up to 5)',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        for (var i = 0; i < tags.length; i++)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: FamilyTagRow([tags[i]])),
                IconButton(
                    tooltip: 'Move tag up',
                    onPressed: !enabled || i == 0
                        ? null
                        : () {
                            final a = [...tags];
                            final t = a.removeAt(i);
                            a.insert(i - 1, t);
                            onChanged(a);
                          },
                    icon: const Icon(Icons.arrow_upward)),
                IconButton(
                    tooltip: 'Edit tag',
                    onPressed: enabled ? () => edit(context, i) : null,
                    icon: const Icon(Icons.edit_outlined)),
                IconButton(
                    tooltip: 'Remove tag',
                    onPressed: enabled
                        ? () => onChanged([...tags]..removeAt(i))
                        : null,
                    icon: const Icon(Icons.close))
              ])),
        if (tags.length < 5)
          OutlinedButton.icon(
              onPressed: enabled ? () => edit(context) : null,
              icon: const Icon(Icons.add),
              label:
                  Text('Add ${title.toLowerCase().replaceAll('tags', 'tag')}'))
      ]));
}
