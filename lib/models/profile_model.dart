import 'package:flutter/foundation.dart';

class ProfileData {
  final String name;
  final String username;
  final int age;
  final DateTime? birthDate;
  final String email;
  final String phone;
  final String community;
  final String address;
  final String googlePhotoUrl;
  final List<String> interestTags;
  final Map<String, String> customInterestCategories;

  const ProfileData({
    required this.name,
    required this.username,
    required this.age,
    this.birthDate,
    required this.email,
    required this.phone,
    this.community = '',
    this.address = '',
    this.googlePhotoUrl = '',
    this.interestTags = const [],
    this.customInterestCategories = const {},
  });

  /// 展示用年龄：有出生日期时按出生日期实时计算，否则用存量 age。
  int get displayAge => birthDate == null ? age : calculateAge(birthDate!);

  ProfileData copyWith({
    String? name,
    String? username,
    int? age,
    DateTime? birthDate,
    String? email,
    String? phone,
    String? community,
    String? address,
    String? googlePhotoUrl,
    List<String>? interestTags,
    Map<String, String>? customInterestCategories,
  }) {
    return ProfileData(
      name: name ?? this.name,
      username: username ?? this.username,
      age: age ?? this.age,
      birthDate: birthDate ?? this.birthDate,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      community: community ?? this.community,
      address: address ?? this.address,
      googlePhotoUrl: googlePhotoUrl ?? this.googlePhotoUrl,
      interestTags: interestTags ?? this.interestTags,
      customInterestCategories:
          customInterestCategories ?? this.customInterestCategories,
    );
  }
}

/// 根据出生年月日计算周岁年龄。
int calculateAge(DateTime birthDate, [DateTime? asOf]) {
  final now = asOf ?? DateTime.now();
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age < 0 ? 0 : age;
}

/// 格式化为 yyyy-MM-dd，便于展示与填写。
String formatBirthDate(DateTime birthDate) {
  final y = birthDate.year.toString().padLeft(4, '0');
  final m = birthDate.month.toString().padLeft(2, '0');
  final d = birthDate.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class MatchUser {
  final String id;
  final String name;
  final String? username;
  final String? email;
  final String? googlePhotoUrl;
  final String? authProvider;
  final int age;
  final String community;
  final List<String> interestTags;
  final Map<String, String> customInterestCategories;
  final double matchScore;

  const MatchUser({
    required this.id,
    required this.name,
    this.username,
    this.email,
    this.googlePhotoUrl,
    this.authProvider,
    required this.age,
    this.community = '',
    this.interestTags = const [],
    this.customInterestCategories = const {},
    this.matchScore = 0,
  });

  /// 头像用名字首字母。有 Google 头像时调用方可自行使用 [googlePhotoUrl]。
  String get avatarInitial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  /// /auth/match/candidates 返回的一条用户记录转成 MatchUser。
  factory MatchUser.fromJson(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString().trim() ?? '';
    final name = str('fullName');
    final username = str('username');
    final email = str('email');
    final photo = str('googlePhotoUrl');
    final provider = str('authProvider');
    DateTime? birth;
    final birthStr = str('birthDate');
    if (birthStr.isNotEmpty) {
      try {
        birth = DateTime.parse(birthStr);
      } catch (_) {
        birth = null;
      }
    }
    var interests = <String>[];
    final rawInterests = json['interests'];
    if (rawInterests is List) {
      interests = rawInterests
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(10)
          .toList();
    } else if (str('interest').isNotEmpty) {
      // 老用户只有单个 interest 字段。
      interests = [str('interest')];
    }
    var custom = <String, String>{};
    final rawCustom = json['customCategories'];
    if (rawCustom is Map) {
      rawCustom.forEach((k, v) {
        if (k is String && v is String && interests.contains(k)) custom[k] = v;
      });
    }
    return MatchUser(
      id: str('id'),
      name: name,
      username: username.isEmpty ? null : username,
      email: email.isEmpty ? null : email,
      googlePhotoUrl: photo.isEmpty ? null : photo,
      authProvider: provider.isEmpty ? null : provider,
      age: birth == null ? 0 : calculateAge(birth),
      community: str('community'),
      interestTags: interests,
      customInterestCategories: custom,
    );
  }

  MatchUser copyWith({double? matchScore}) {
    return MatchUser(
      id: id,
      name: name,
      username: username,
      email: email,
      googlePhotoUrl: googlePhotoUrl,
      authProvider: authProvider,
      age: age,
      community: community,
      interestTags: interestTags,
      customInterestCategories: customInterestCategories,
      matchScore: matchScore ?? this.matchScore,
    );
  }
}

final availableInterests = [
  'Hiking',
  'Photography',
  'Basketball',
  'Cooking',
  'Travel',
  'Yoga',
  'Gaming',
  'Music',
  'Art',
  'Running',
  'Swimming',
  'Cycling',
  'Reading',
  'Writing',
  'Dancing',
  'Movies',
  'Gardening',
  'Fishing',
  'Painting',
  'Singing',
];

/// 大类 -> 小标签映射。小标签可归属多个大类，用于“大类相同也加分”。
const interestCategories = {
  'Sports': ['Basketball', 'Yoga', 'Running', 'Swimming', 'Cycling'],
  'Outdoors': [
    'Hiking',
    'Travel',
    'Gardening',
    'Fishing',
    'Cycling',
    'Running'
  ],
  'Arts': [
    'Photography',
    'Music',
    'Art',
    'Dancing',
    'Movies',
    'Painting',
    'Singing'
  ],
  'Life': ['Cooking', 'Gardening', 'Travel', 'Movies', 'Photography'],
  'Mind': ['Gaming', 'Reading', 'Writing', 'Yoga', 'Photography'],
};

/// 单个标签归属的大类集合。预设标签查表，自定义标签查 customMap。
Set<String> categoriesOfTag(String tag, [Map<String, String>? customMap]) {
  final result = <String>{};
  interestCategories.forEach((big, smalls) {
    if (smalls.contains(tag)) result.add(big);
  });
  final custom = customMap?[tag];
  if (custom != null && custom.isNotEmpty) result.add(custom);
  return result;
}

/// 一组标签展开成大类集合。
Set<String> tagsToCategories(List<String> tags,
    [Map<String, String>? customMap]) {
  final result = <String>{};
  for (final tag in tags) {
    result.addAll(categoriesOfTag(tag, customMap));
  }
  return result;
}

/// 双方大类重合数（用于加分）。[customMapA]/[customMapB] 分别是双方自己的自定义标签归类。
int countSharedCategories(List<String> a, List<String> b,
    [Map<String, String>? customMapA, Map<String, String>? customMapB]) {
  final catsA = tagsToCategories(a, customMapA);
  final catsB = tagsToCategories(b, customMapB);
  return catsA.intersection(catsB).length;
}

final availableCommunities = [
  'Riverside',
  'Central Park',
  'Downtown',
  'Sunset Village',
  'Pine Ridge',
  'Lakeview',
  'Greenwood',
  'Oakville',
];

/// Map backend /auth/me user JSON to local ProfileData.
/// Backend shape: fullName, birthDate (YYYY-MM-DD), interests (list),
/// customCategories (map), username, email, phone, community, address.
///
/// Presence-aware fallback: a key that the server explicitly returns as empty
/// means the user cleared that field, so it must **not** be replaced by the
/// old local value. [fallback] is only used when a key is missing entirely.
ProfileData profileFromAuthUser(Map<String, dynamic> user,
    {ProfileData? fallback}) {
  String text(String key) => user[key]?.toString().trim() ?? '';
  final fb = fallback;

  final fullName = text('fullName');
  final hasUsername = user.containsKey('username');
  final username = text('username');
  final hasEmail = user.containsKey('email');
  final email = text('email');
  final hasPhone = user.containsKey('phone');
  final phone = text('phone');
  final hasCommunity = user.containsKey('community');
  final community = text('community');
  final hasAddress = user.containsKey('address');
  final address = text('address');
  final hasPhoto = user.containsKey('googlePhotoUrl');
  final googlePhotoUrl = text('googlePhotoUrl');

  final hasBirth = user.containsKey('birthDate');
  final birthStr = text('birthDate');
  DateTime? parsedBirth;
  if (birthStr.isNotEmpty) {
    try {
      parsedBirth = DateTime.parse(birthStr);
    } catch (_) {
      parsedBirth = null;
    }
  }
  // Present-but-empty means "no birth date"; only fall back when the key is absent.
  final resolvedBirth = hasBirth ? parsedBirth : fb?.birthDate;

  final hasInterests = user.containsKey('interests');
  var interests = <String>[];
  final rawInterests = user['interests'];
  if (rawInterests is List) {
    interests = rawInterests
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(10)
        .toList();
  } else if (!hasInterests &&
      user['interest'] is String &&
      (user['interest'] as String).trim().isNotEmpty) {
    // Legacy accounts only have the single interest field.
    interests = [(user['interest'] as String).trim()];
  }

  final hasCustom = user.containsKey('customCategories');
  var custom = <String, String>{};
  final rawCustom = user['customCategories'];
  if (rawCustom is Map) {
    rawCustom.forEach((k, v) {
      if (k is String && v is String && interests.contains(k)) {
        custom[k] = v;
      }
    });
  }

  // `interests` may also be filled from the legacy single `interest` field.
  final List<String> resolvedInterests = hasInterests || interests.isNotEmpty
      ? interests
      : (fb?.interestTags ?? const <String>[]);
  final Map<String, String> resolvedCustom = hasCustom
      ? custom
      : (fb?.customInterestCategories ?? const <String, String>{});

  return ProfileData(
    // Name is required by the backend, so an empty value keeps the fallback.
    name: fullName.isNotEmpty ? fullName : (fb?.name ?? ''),
    username: hasUsername ? username : (fb?.username ?? ''),
    age: resolvedBirth != null
        ? calculateAge(resolvedBirth)
        : (hasBirth ? 0 : (fb?.age ?? 0)),
    birthDate: resolvedBirth,
    email: hasEmail ? email : (fb?.email ?? ''),
    phone: hasPhone ? phone : (fb?.phone ?? ''),
    community: hasCommunity ? community : (fb?.community ?? ''),
    address: hasAddress ? address : (fb?.address ?? ''),
    googlePhotoUrl: hasPhoto ? googlePhotoUrl : (fb?.googlePhotoUrl ?? ''),
    interestTags: resolvedInterests,
    customInterestCategories: resolvedCustom,
  );
}

/// Neutral placeholder used before the real profile is loaded and after logout.
/// It intentionally contains no demo personal data.
ProfileData emptyProfile() => const ProfileData(
      name: '',
      username: '',
      age: 0,
      email: '',
      phone: '',
    );

/// Reset the shared profile so the next account never sees the previous one.
void resetCurrentProfile() {
  currentProfile.value = emptyProfile();
}

final ValueNotifier<ProfileData> currentProfile =
    ValueNotifier<ProfileData>(emptyProfile());

List<MatchUser> interestMatch(ProfileData profile, List<MatchUser> candidates) {
  final scored = candidates.map((user) {
    final shared = profile.interestTags
        .where((tag) => user.interestTags.contains(tag))
        .length;
    final max = profile.interestTags.isEmpty
        ? 1
        : (profile.interestTags.length + user.interestTags.length) ~/ 2;
    final ageDiff = (profile.displayAge - user.age).abs();
    final ageBonus = ageDiff <= 5 ? 0.2 : (ageDiff <= 10 ? 0.1 : 0);
    // 大类加分：不同小标签但同大类也加分，0.05/个大类，上限0.15
    final sharedCats = countSharedCategories(
      profile.interestTags,
      user.interestTags,
      profile.customInterestCategories,
      user.customInterestCategories,
    );
    final categoryBonus = (sharedCats * 0.05).clamp(0, 0.15);
    final score = (max > 0 ? shared / max : 0) + ageBonus + categoryBonus;
    return user.copyWith(
      matchScore: double.parse((score.clamp(0, 1) * 100).toStringAsFixed(0)),
    );
  }).toList();
  scored.sort(byMatchScore);
  return scored;
}

List<MatchUser> recommendMatch(
    ProfileData profile, List<MatchUser> candidates) {
  final scored = candidates.map((user) {
    double score = 0;
    if (user.community == profile.community) score += 0.4;
    final ageDiff = (profile.displayAge - user.age).abs();
    if (ageDiff <= 3) {
      score += 0.3;
    } else if (ageDiff <= 7) {
      score += 0.15;
    }
    final shared = profile.interestTags
        .where((tag) => user.interestTags.contains(tag))
        .length;
    // 小标签相同 +0.12，大类相同 +0.05/个（上限0.15）
    score += shared * 0.12;
    final sharedCats = countSharedCategories(
      profile.interestTags,
      user.interestTags,
      profile.customInterestCategories,
      user.customInterestCategories,
    );
    score += (sharedCats * 0.05).clamp(0, 0.15);
    return user.copyWith(
      matchScore: double.parse((score.clamp(0, 1) * 100).toStringAsFixed(0)),
    );
  }).toList();
  scored.sort(byMatchScore);
  return scored;
}

/// 分数降序，同分按名字，保证列表顺序稳定（List.sort 不稳定）。
int byMatchScore(MatchUser a, MatchUser b) {
  final byScore = b.matchScore.compareTo(a.matchScore);
  if (byScore != 0) return byScore;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
