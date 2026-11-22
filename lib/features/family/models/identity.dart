import 'package:flutter/material.dart';
import '../../../models/family_group.dart';

class FamilyTag {
  const FamilyTag(this.label, this.value, this.colorId);
  final String label, value, colorId;
  factory FamilyTag.fromJson(FamilyJson j) => FamilyTag(
      j['label'] as String, j['value'] as String? ?? '', j['color'] as String);
  FamilyJson toJson() => {'label': label, 'value': value, 'color': colorId};
  String get text => value.isEmpty ? label : '$label: $value';
  Color get color {
    final index = int.tryParse(colorId.replaceFirst('c', '')) ?? 1;
    return familyPalette[index.clamp(1, 30) - 1].$2;
  }
}

List<FamilyTag> familyTags(dynamic data) => (data as List? ?? [])
    .map((e) => FamilyTag.fromJson(Map<String, dynamic>.from(e as Map)))
    .toList();
const familyPalette = <(String, Color)>[
  ('Ruby', Color(0xFFB71C1C)),
  ('Coral', Color(0xFFFF7043)),
  ('Rose', Color(0xFFF48FB1)),
  ('Pink', Color(0xFFAD1457)),
  ('Magenta', Color(0xFFD500F9)),
  ('Purple', Color(0xFF6A1B9A)),
  ('Lavender', Color(0xFFD1C4E9)),
  ('Indigo', Color(0xFF283593)),
  ('Royal blue', Color(0xFF2962FF)),
  ('Sky', Color(0xFF81D4FA)),
  ('Navy', Color(0xFF003049)),
  ('Cyan', Color(0xFF00BCD4)),
  ('Turquoise', Color(0xFF40E0D0)),
  ('Teal', Color(0xFF00695C)),
  ('Mint', Color(0xFFB9F6CA)),
  ('Forest', Color(0xFF1B5E20)),
  ('Green', Color(0xFF66BB6A)),
  ('Lime', Color(0xFFCDDC39)),
  ('Olive', Color(0xFF827717)),
  ('Lemon', Color(0xFFFFF176)),
  ('Amber', Color(0xFFFFB300)),
  ('Orange', Color(0xFFEF6C00)),
  ('Peach', Color(0xFFFFCCBC)),
  ('Terracotta', Color(0xFFA84325)),
  ('Brown', Color(0xFF5D4037)),
  ('Sand', Color(0xFFD7CCC8)),
  ('Slate', Color(0xFF455A64)),
  ('Silver', Color(0xFFCFD8DC)),
  ('Charcoal', Color(0xFF212121)),
  ('White', Color(0xFFFAFAFA)),
];

class FamilyPerson {
  const FamilyPerson(
      {required this.id,
      required this.groupId,
      required this.name,
      required this.familyName,
      required this.groupTags,
      required this.personalTags,
      this.demo = false});
  final String id, groupId, name, familyName;
  final List<FamilyTag> groupTags, personalTags;
  final bool demo;
  factory FamilyPerson.fromJson(FamilyJson j) => FamilyPerson(
      id: j['id'],
      groupId: j['groupId'],
      name: j['name'],
      familyName: j['familyName'],
      groupTags: familyTags(j['familyTags']),
      personalTags: familyTags(j['personalTags']),
      demo: j['demo'] == true);
}
