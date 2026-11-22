import '../../../models/family_tree.dart';
import '../../../services/family_service.dart';
import '../models/identity.dart';

class FamilyPeoplePage {
  const FamilyPeoplePage(this.items, this.nextOffset);
  final List<FamilyPerson> items;
  final int? nextOffset;
}

/// Family-specific API contracts, separate from widgets and Auth/Chat services.
class FamilyDirectoryRepository {
  const FamilyDirectoryRepository(this.api);
  final FamilyService api;
  Future<FamilyPeoplePage> search(String groupId, String name,
      {int offset = 0}) async {
    final data = await api.request('GET',
        '/families/$groupId/tree/people?q=${Uri.encodeQueryComponent(name.trim())}&offset=$offset');
    return FamilyPeoplePage(
        (data['items'] as List)
            .map((p) =>
                FamilyPerson.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
        data['nextOffset'] as int?);
  }

  Future<FamilyPerson> resolve(String groupId, FamilyPerson person) async =>
      FamilyPerson.fromJson(await api.request('GET',
          '/families/$groupId/tree/people/${person.groupId}/${person.id}'));
  Future<FamilyTreeSnapshot> tree(String groupId) async =>
      FamilyTreeSnapshot(await api.request('GET', '/families/$groupId/tree'));
}
