import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:global_village_app/models/profile_model.dart';
import 'package:global_village_app/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProfileData oldProfile() {
  return ProfileData(
    name: 'Old Name',
    username: 'old_name',
    age: 30,
    birthDate: DateTime(1990, 1, 1),
    email: 'old@example.com',
    phone: '+1 555 0100',
    community: 'Riverside',
    address: '1 Old Street',
    googlePhotoUrl: 'https://example.com/old.png',
    interestTags: const ['Hiking', 'Music'],
    customInterestCategories: const {'Chess': 'Mind'},
  );
}

void main() {
  tearDown(() {
    AuthService.httpClientOverride = null;
  });

  group('profileFromAuthUser', () {
    test('present but empty server fields clear the old fallback values', () {
      final profile = profileFromAuthUser(
        const <String, dynamic>{
          'fullName': 'Old Name',
          'username': 'old_name',
          'email': 'old@example.com',
          'phone': '',
          'community': '',
          'address': '',
          'birthDate': null,
          'interests': <String>[],
          'customCategories': <String, String>{},
          'googlePhotoUrl': null,
        },
        fallback: oldProfile(),
      );

      expect(profile.phone, isEmpty);
      expect(profile.community, isEmpty);
      expect(profile.address, isEmpty);
      expect(profile.birthDate, isNull);
      expect(profile.age, 0);
      expect(profile.interestTags, isEmpty);
      expect(profile.customInterestCategories, isEmpty);
      expect(profile.googlePhotoUrl, isEmpty);
    });

    test('missing keys still fall back to the previous values', () {
      final profile = profileFromAuthUser(
        const <String, dynamic>{'fullName': 'Old Name'},
        fallback: oldProfile(),
      );

      expect(profile.phone, '+1 555 0100');
      expect(profile.community, 'Riverside');
      expect(profile.address, '1 Old Street');
      expect(profile.birthDate, DateTime(1990, 1, 1));
      expect(profile.interestTags, const ['Hiking', 'Music']);
      expect(profile.username, 'old_name');
    });

    test('maps a Google photo URL and legacy interest', () {
      final profile = profileFromAuthUser(const <String, dynamic>{
        'fullName': 'Google User',
        'interest': 'Yoga',
        'googlePhotoUrl': 'https://example.com/me.png',
      });

      expect(profile.interestTags, const ['Yoga']);
      expect(profile.googlePhotoUrl, 'https://example.com/me.png');
    });
  });

  test('emptyProfile has no demo personal data', () {
    final profile = emptyProfile();
    expect(profile.name, isEmpty);
    expect(profile.username, isEmpty);
    expect(profile.email, isEmpty);
    expect(profile.phone, isEmpty);
    expect(profile.interestTags, isEmpty);
    expect(profile.birthDate, isNull);
  });

  test('updateProfile omits birthDate when the user has none', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'token'});
    Map<String, dynamic>? sent;
    AuthService.httpClientOverride = MockClient((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'user': {
            'id': 'u-1',
            'fullName': 'No Birthday',
            'username': 'nobirthday',
            'email': 'n@example.com',
            'phone': '',
            'community': '',
            'address': '',
            'interests': <String>[],
            'customCategories': <String, String>{},
          }
        }),
        200,
      );
    });

    try {
      await AuthService.updateProfile(
        fullName: 'No Birthday',
        username: 'nobirthday',
        birthDate: null,
        phone: '',
        community: '',
        address: '',
        interests: const [],
        customCategories: const {},
      );
    } finally {
      AuthService.httpClientOverride = null;
    }

    expect(sent, isNotNull);
    expect(sent!.containsKey('birthDate'), isFalse);
    expect(sent!['phone'], '');
  });

  test('clearSession resets the shared profile so accounts never mix',
      () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'token'});
    currentProfile.value = oldProfile();

    await AuthService.clearSession();

    expect(currentProfile.value.name, isEmpty);
    expect(currentProfile.value.email, isEmpty);
    expect(currentProfile.value.phone, isEmpty);
  });
}
