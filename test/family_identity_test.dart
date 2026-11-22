import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_village_app/features/family/models/identity.dart';
import 'package:global_village_app/features/family/widgets/tags.dart';
import 'package:global_village_app/features/family/widgets/people_search.dart';
import 'package:global_village_app/features/family/pages/notifications.dart';
import 'package:global_village_app/models/family_tree.dart';
import 'package:global_village_app/pages/family_tree_canvas_page.dart';
import 'family_tree_test.dart' as fixture;

Map<String, dynamic> person(int i) => {
      'id': 'person$i',
      'name': 'John Prince $i',
      'groupId': 'b',
      'familyName': 'Prince Family',
      'familyTags': [
        {'label': 'Prince', 'color': 'c7'}
      ],
      'personalTags': [
        {'label': 'Name', 'value': 'John Prince $i', 'color': 'c15'}
      ]
    };
FamilyTreeSnapshot tree() => FamilyTreeSnapshot({
      ...fixture.snapshot(),
      'nodes': [
        {'id': 'a', 'name': 'Home', 'canOpen': true, 'people': []},
        {
          'id': 'b',
          'name': 'Prince Family',
          'canOpen': false,
          'people': [
            for (var i = 0; i < 10; i++)
              {
                'id': 'person$i',
                'name': 'John Prince $i',
                'tags': person(i)['personalTags']
              }
          ]
        }
      ],
      'connections': [
        {'id': 'edge', 'a': 'a', 'b': 'b', 'label': 'Extended family'}
      ]
    });
void main() {
  test('palette has 30 distinct labelled colours and serialized IDs', () {
    expect(familyPalette.length, 30);
    expect(familyPalette.map((p) => p.$2).toSet().length, 30);
    for (var i = 0; i < 30; i++) {
      final t = FamilyTag('Label', 'Value', 'c${i + 1}');
      expect(t.color, familyPalette[i].$2);
      expect(FamilyTag.fromJson(t.toJson()).text, 'Label: Value');
    }
  });
  testWidgets(
      'search debounces input and preserves family before personal tags',
      (tester) async {
    var calls = 0;
    FamilyPerson? selected;
    final api = fixture.api((r) async {
      calls++;
      expect(r.url.queryParameters['q'], 'John');
      return fixture.response({
        'items': [person(0)],
        'nextOffset': null
      });
    });
    addTearDown(api.close);
    await fixture.show(
        tester,
        Scaffold(
            body: FamilyPeopleSearch(
                api: api,
                groupId: 'a',
                onSelected: (p) async {
                  selected = p;
                })));
    await tester.enterText(find.byType(TextField), 'John');
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.getTopLeft(find.text('John Prince 0')).dx,
        lessThan(tester.getTopLeft(find.text('Prince')).dx));
    await tester.tap(find.text('John Prince 0'));
    await tester.pumpAndSettle();
    expect(selected!.groupTags.first.label, 'Prince');
    expect(selected!.personalTags.first.label, 'Name');
    expect(tester.takeException(), null);
  });
  testWidgets('clearing a search discards a late response', (tester) async {
    final pending = Completer<void>();
    final api = fixture.api((_) async {
      await pending.future;
      return fixture.response({
        'items': [person(0)],
        'nextOffset': null
      });
    });
    addTearDown(api.close);
    await fixture.show(
        tester,
        Scaffold(
            body: FamilyPeopleSearch(
                api: api, groupId: 'a', onSelected: (_) async {})));
    await tester.enterText(find.byType(TextField), 'John');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byTooltip('Clear search'));
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('John Prince 0'), findsNothing);
  });
  for (final scale in [1.0, 1.5]) {
    testWidgets(
        'selection expands hidden member and centres exact row at text scale $scale',
        (tester) async {
      final api = fixture.api((r) async => fixture
          .response(r.url.path.contains('/people/') ? person(9) : tree().data));
      addTearDown(api.close);
      await fixture.show(
          tester,
          FamilyTreeCanvasPage(
              api: api,
              initial: tree(),
              focusPerson: FamilyPerson.fromJson(person(9))),
          scale: scale);
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('person-b-person9'));
      expect(row, findsOneWidget);
      final canvas = tester.getRect(find.byType(InteractiveViewer)),
          rect = tester.getRect(row);
      expect((canvas.center - rect.center).distance, lessThan(2));
      expect(tester.takeException(), null);
      await tester.ensureVisible(find.text('Show all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      expect(find.text('John Prince 9 - Prince Family'), findsNothing);
    });
  }
  testWidgets('rejected selection hides previously visible tree content',
      (tester) async {
    final api = fixture.api((r) async =>
        fixture.response({'error': 'Connection no longer exists'}, 404));
    addTearDown(api.close);
    await fixture.show(
        tester,
        FamilyTreeCanvasPage(
            api: api,
            initial: tree(),
            focusPerson: FamilyPerson.fromJson(person(9))));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
  testWidgets('tag editor shows all 30 colours and changes only its own list',
      (tester) async {
    List<FamilyTag> tags = [];
    await fixture.show(
        tester,
        Scaffold(
            body: StatefulBuilder(
                builder: (c, set) => SingleChildScrollView(
                    child: FamilyTagEditor(
                        title: 'Personal tags',
                        tags: tags,
                        onChanged: (v) => set(() => tags = v))))));
    await tester.tap(find.text('Add personal tag'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(30));
    await tester.enterText(find.widgetWithText(TextField, 'Tag label'), 'Name');
    await tester.enterText(
        find.widgetWithText(TextField, 'Tag value (optional)'), 'John');
    await tester.tap(find.text('Save tag'));
    await tester.pumpAndSettle();
    expect(tags.single.text, 'Name: John');
    expect(tester.takeException(), null);
  });
  testWidgets(
      'notification read and unread updates are sent as current-user actions',
      (tester) async {
    var read = false;
    final api = fixture.api((r) async {
      if (r.method == 'PUT') {
        read = !read;
        return fixture.response({'ok': true});
      }
      return fixture.response({
        'items': [
          {
            'id': 'event',
            'message': 'Families linked',
            'createdAt': '2026-11-10',
            'isRead': read,
            'groupId': 'a'
          }
        ],
        'unread': read ? 0 : 1
      });
    });
    addTearDown(api.close);
    await fixture.show(tester, FamilyNotificationsPage(api: api));
    await tester.tap(find.text('Mark read'));
    await tester.pumpAndSettle();
    expect(read, true);
    await tester.tap(find.text('Mark unread'));
    await tester.pumpAndSettle();
    expect(read, false);
  });
}

