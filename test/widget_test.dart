import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetium/api.dart';
import 'package:poetium/main.dart';

class FakePoetiumRepository implements PoetiumRepository {
  final user = const UserAccount(
    id: '1',
    name: 'Ada Yilmaz',
    username: 'adadizeleri',
    email: 'ada@poetium.com',
  );
  final followedUserIds = <String>{};
  final poems = <Poem>[
    Poem(
      id: '1',
      authorId: '2',
      title: 'Kiyida',
      body: 'Bir dalga koydum cebime.',
      author: 'Leyla Keskin',
      visibility: 'Herkese açık',
      scores: {'İmge': 5, 'Ritim': 4, 'Duygu': 5, 'Özgünlük': 4},
      ratings: 18,
    ),
  ];
  bool resetRequested = false;

  @override
  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> verifyEmail(String token) async {}

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => AuthSession(token: 'test-token', user: user);

  @override
  Future<void> forgotPassword(String email) async {
    resetRequested = true;
  }

  @override
  Future<List<Poem>> fetchPoems(String token) async => List.of(poems);

  @override
  Future<List<Poem>> fetchLikedPoems(String token) async => List.of(poems);

  @override
  Future<List<Poem>> fetchUserPoems(String token, String userId) async {
    return poems
        .where((poem) => poem.authorId == userId)
        .toList();
  }

  @override
  Future<List<Poem>> fetchFollowingFeed(String token) async {
    return poems
        .where((poem) => followedUserIds.contains(poem.authorId))
        .toList();
  }

  @override
  Future<List<UserProfile>> fetchUsers(String token) async => const [
    UserProfile(id: '2', name: 'Leyla Keskin', username: 'leyladizeleri'),
  ];

  @override
  Future<UserAccount> updateProfileImage(String token, String? dataUrl) async =>
      UserAccount(
        id: user.id,
        name: user.name,
        username: user.username,
        email: user.email,
        avatarUrl: dataUrl,
      );

  @override
  Future<void> followUser(String token, String userId) async {
    followedUserIds.add(userId);
  }

  @override
  Future<void> unfollowUser(String token, String userId) async {
    followedUserIds.remove(userId);
  }

  @override
  Future<List<UserProfile>> fetchFollowers(String token, String userId) async {
    if (userId == '1') {
      return const [UserProfile(id: '3', name: 'Naz Demir', username: 'nazpuanlar')];
    }
    if (userId == '2' && followedUserIds.contains('2')) {
      return const [UserProfile(id: '1', name: 'Ada Yilmaz', username: 'adadizeleri')];
    }
    return const [];
  }

  @override
  Future<List<UserProfile>> fetchFollowing(String token, String userId) async {
    if (userId == '1') {
      return followedUserIds.contains('2')
          ? const [UserProfile(id: '2', name: 'Leyla Keskin', username: 'leyladizeleri')]
          : const [];
    }
    return const [];
  }

  @override
  Future<Poem> createPoem({
    required String token,
    required String title,
    required String body,
    required String visibility,
    List<String> recipientIds = const [],
  }) async {
    final poem = Poem(
      id: '2',
      authorId: '1',
      title: title,
      body: body,
      author: user.name,
      visibility: visibility == 'public' ? 'Herkese açık' : 'Seçili kişiler',
      scores: {'İmge': 0, 'Ritim': 0, 'Duygu': 0, 'Özgünlük': 0},
      ratings: 0,
    );
    poems.insert(0, poem);
    return poem;
  }

  @override
  Future<Poem> ratePoem({
    required String token,
    required String poemId,
    required Map<String, int> scores,
  }) async => poems.firstWhere((poem) => poem.id == poemId);

  @override
  Future<List<RatingDetail>> fetchRatingDetails({
    required String token,
    required String poemId,
  }) async => const [
    RatingDetail(
      userId: '3',
      username: 'nazpuanlar',
      name: 'Naz Demir',
      totalScore: 4.4,
      scores: {
        'Duygusal Etki': 5,
        'Özgünlük': 4,
        'İmge & Mecaz': 5,
        'Dil & Sözcük Seçimi': 4,
        'Ahenk & Akış': 4,
        'Bütünlük & Yapı': 5,
        'Şiir Tekniği': 3,
        'Derinlik': 4,
      },
    ),
  ];

  @override
  Future<int> likePoem(String token, String poemId) async => 1;

  @override
  Future<int> unlikePoem(String token, String poemId) async => 0;

  @override
  Future<Map<String, dynamic>> fetchLikeStatus(String token, String poemId) async => {'like_count': 0, 'is_liked': false};

  @override
    Future<Comment> addComment(String token, String poemId, String content, {String? parentId}) async => Comment(
        id: '1',
        userId: '1',
      parentId: parentId,
        username: user.username,
        name: user.name,
        content: content,
        createdAt: DateTime.now(),
      );

  @override
  Future<List<Comment>> fetchComments(String token, String poemId) async => const [];

  @override
  Future<void> deleteComment(String token, String commentId) async {}

  @override
  Future<Archive> archivePoem(
    String token,
    String poemId, {
    String title = '',
    String category = '',
    String notes = '',
    String tags = '',
    String source = 'saved',
  }) async => Archive(
        id: '1',
        poemId: poemId,
        poemTitle: 'Demo',
        poemBody: 'Demo',
        authorName: 'Ada Yilmaz',
        authorUsername: 'adadizeleri',
        archiveTitle: title,
        category: '',
        notes: notes,
        tags: tags,
        source: source,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  Future<List<Archive>> fetchArchives(String token) async => const [];

  @override
  Future<Archive> updateArchive(
    String token,
    String archiveId, {
    required String title,
    required String category,
    required String notes,
    required String tags,
  }) async => Archive(
        id: archiveId,
        poemId: '1',
        poemTitle: 'Demo',
        poemBody: 'Demo',
        authorName: 'Ada Yilmaz',
        authorUsername: 'adadizeleri',
        archiveTitle: title,
        category: '',
        notes: notes,
        tags: tags,
        source: 'saved',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  Future<void> deleteArchive(String token, String archiveId) async {}
}

void main() {
  test('uses backend total score for poem average', () {
    final poem = Poem.fromJson({
      'id': '7',
      'author_id': '2',
      'title': 'Toplam',
      'body': 'Bir dize.',
      'author_name': 'Leyla Keskin',
      'visibility': 'public',
      'ratings': 3,
      'author_username': 'leyladizeleri',
      'total_score': 4.65,
      'image': 2,
      'rhythm': 3,
      'emotion': 4,
      'originality': 5,
    });

    expect(poem.ratings, 3);
    expect(poem.author, '@leyladizeleri');
    expect(poem.totalScore, 4.65);
    expect(poem.average, 4.65);
  });

  testWidgets('shows Google configuration requirement from registration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PoetiumApp(repository: FakePoetiumRepository()));

    await tester.ensureVisible(find.byKey(const Key('switch-to-register')));
    await tester.tap(find.byKey(const Key('switch-to-register')));
    await tester.pumpAndSettle();

    expect(find.text('Google ile devam et'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('google-auth')));
    await tester.tap(find.byKey(const Key('google-auth')));
    await tester.pumpAndSettle();

    expect(
      find.text('Google OAuth istemci kimliği yapılandırılmalı.'),
      findsOneWidget,
    );
  });

  testWidgets('registers, publishes a poem, and shows it on profile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PoetiumApp(repository: FakePoetiumRepository()));

    await tester.ensureVisible(find.byKey(const Key('switch-to-register')));
    await tester.tap(find.byKey(const Key('switch-to-register')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('register-name')),
      'Ada Yilmaz',
    );
    await tester.enterText(
      find.byKey(const Key('register-username')),
      'adadizeleri',
    );
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@poetium.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'siir123');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('E-postanı doğrula'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('verification-token')), 'test-token');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-email')), 'ada@poetium.com');
    await tester.enterText(find.byKey(const Key('auth-password')), 'siir123');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Keşfet'), findsWidgets);
    expect(find.text('Kiyida'), findsOneWidget);

    await tester.tap(find.text('Yaz'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Başlık'), 'Golge');
    await tester.enterText(
      find.widgetWithText(TextField, 'Dizelerini buraya bırak...'),
      'Bir golge dustu kagida.',
    );
    await tester.ensureVisible(find.text('Yayınla'));
    await tester.tap(find.text('Yayınla'));
    await tester.pumpAndSettle();

    expect(find.text('YAYINLARIM'), findsOneWidget);
    expect(find.text('@adadizeleri'), findsWidgets);
    expect(find.text('Golge'), findsOneWidget);
  });

  testWidgets(
    'shows a clear warning when trying to log in with an unregistered email',
    (WidgetTester tester) async {
      final repository = _FailingRepository();
      await tester.pumpWidget(PoetiumApp(repository: repository));

      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'yeni@poetium.com',
      );
      await tester.enterText(find.byKey(const Key('auth-password')), '123456');
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Bu e-posta kayıtlı değil. Kayıt ol veya e-posta adresini kontrol et.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('lets a user follow another poet from the selection list', (
    WidgetTester tester,
  ) async {
    final repository = FakePoetiumRepository();
    await tester.pumpWidget(PoetiumApp(repository: repository));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@poetium.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'siir123');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Yaz'));
    await tester.tap(find.text('Yaz'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Seçtiklerim'));
    await tester.tap(find.text('Seçtiklerim'));
    await tester.pumpAndSettle();

    final followButton = find.text('Takip et');
    expect(followButton, findsOneWidget);
    await tester.tap(followButton);
    await tester.pumpAndSettle();

    expect(find.text('Takipten çık'), findsOneWidget);
    expect(repository.followedUserIds, contains('2'));
  });

  testWidgets('shows poems written by followed poets in the discover feed', (
    WidgetTester tester,
  ) async {
    final repository = FakePoetiumRepository();
    repository.followedUserIds.add('2');
    repository.poems.insert(
      0,
      Poem(
        id: '99',
        authorId: '2',
        title: 'Takipteki şiir',
        body: 'Yolunu bekliyorum.',
        author: '@leyladizeleri',
        visibility: 'Herkese açık',
        scores: {'İmge': 5, 'Ritim': 4, 'Duygu': 5, 'Özgünlük': 4},
        ratings: 1,
      ),
    );

    await tester.pumpWidget(PoetiumApp(repository: repository));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@poetium.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'siir123');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Takipteki şiir'), findsOneWidget);
    expect(await repository.fetchFollowingFeed('test-token'), isNotEmpty);
  });

  testWidgets('shows follower and following lists from the profile screen', (
    WidgetTester tester,
  ) async {
    final repository = FakePoetiumRepository();
    repository.followedUserIds.add('2');
    await tester.pumpWidget(PoetiumApp(repository: repository));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@poetium.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'siir123');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Takipçi'));
    await tester.pumpAndSettle();
    expect(find.text('Takipçiler'), findsOneWidget);
    expect(find.text('@nazpuanlar'), findsOneWidget);

    Navigator.of(tester.element(find.text('Takipçiler'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Takip'));
    await tester.pumpAndSettle();
    expect(find.text('Takip edilenler'), findsOneWidget);
    expect(find.text('@leyladizeleri'), findsOneWidget);
  });

  testWidgets('lets a user unfollow from the profile list modal', (
    WidgetTester tester,
  ) async {
    final repository = FakePoetiumRepository();
    repository.followedUserIds.add('2');
    await tester.pumpWidget(PoetiumApp(repository: repository));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@poetium.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'siir123');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Takip'));
    await tester.pumpAndSettle();

    expect(find.text('Takipten çık'), findsOneWidget);
    await tester.tap(find.text('Takipten çık'));
    await tester.pumpAndSettle();

    expect(repository.followedUserIds, isNot(contains('2')));
  });

  testWidgets('opens another user profile from the followed people search list', (
    WidgetTester tester,
  ) async {
    final repository = FakePoetiumRepository();
    repository.followedUserIds.add('2');
    await tester.pumpWidget(PoetiumApp(repository: repository));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@poetium.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'siir123');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Takip'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'leyl');
    await tester.pumpAndSettle();
    await tester.tap(find.text('@leyladizeleri'));
    await tester.pumpAndSettle();

    expect(find.text('@leyladizeleri'), findsWidgets);
    expect(find.text('Leyla Keskin'), findsWidgets);
    expect(find.text('Takipten çık'), findsOneWidget);

    await tester.tap(find.text('Takipten çık'));
    await tester.pumpAndSettle();

    expect(repository.followedUserIds, isNot(contains('2')));
  });

  testWidgets('shows the weighted poetry evaluation criteria', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RatingSheet(
          poem: Poem(
            id: '1',
            authorId: '2',
            title: 'Kiyida',
            body: 'Bir dalga koydum cebime.',
            author: 'Leyla Keskin',
            visibility: 'Herkese açık',
            scores: {'İmge': 5, 'Ritim': 4, 'Duygu': 5, 'Özgünlük': 4},
            ratings: 18,
          ),
        ),
      ),
    );

    expect(find.text('Duygusal Etki'), findsOneWidget);
    expect(find.text('%20'), findsNWidgets(2));
    expect(find.text('Özgünlük'), findsOneWidget);
    expect(find.text('İmge & Mecaz'), findsOneWidget);
  });

  testWidgets('opens rating details from the rating count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PoetiumApp(repository: FakePoetiumRepository()));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@poetium.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'siir123');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('18 değerlendirme'));
    await tester.pumpAndSettle();

    expect(find.text('Değerlendirmeler'), findsOneWidget);
    expect(find.text('@nazpuanlar'), findsOneWidget);
    expect(find.text('Naz Demir'), findsOneWidget);
    expect(find.text('Duygusal Etki'), findsOneWidget);
    expect(find.text('5/5'), findsWidgets);
  });

  testWidgets(
    'shows an email-check notification after password reset request',
    (WidgetTester tester) async {
      final repository = FakePoetiumRepository();
      await tester.pumpWidget(PoetiumApp(repository: repository));

      await tester.tap(find.text('Şifremi unuttum'));
      await tester.pumpAndSettle();

      expect(find.text('Şifreni yenile'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'ada@poetium.com',
      );
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Şifre yenileme talebi alındı. E-posta kutunu kontrol et.'),
        findsOneWidget,
      );
      expect(repository.resetRequested, isTrue);
    },
  );
}

class _FailingRepository implements PoetiumRepository {
  @override
  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<void> verifyEmail(String token) async {}

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    throw const ApiException(
      'Bu e-posta kayıtlı değil. Kayıt ol veya e-posta adresini kontrol et.',
    );
  }

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<List<Poem>> fetchPoems(String token) async => const [];

  @override
  Future<List<Poem>> fetchLikedPoems(String token) async => const [];

  @override
  Future<List<Poem>> fetchUserPoems(String token, String userId) async => const [];

  @override
  Future<List<Poem>> fetchFollowingFeed(String token) async => const [];

  @override
  Future<List<UserProfile>> fetchUsers(String token) async => const [];

  @override
  Future<UserAccount> updateProfileImage(String token, String? dataUrl) async =>
      throw const ApiException('Kullanıcı bulunamadı.');

  @override
  Future<Poem> createPoem({
    required String token,
    required String title,
    required String body,
    required String visibility,
    List<String> recipientIds = const [],
  }) async => throw UnimplementedError();

  @override
  Future<Poem> ratePoem({
    required String token,
    required String poemId,
    required Map<String, int> scores,
  }) async => throw UnimplementedError();

  @override
  Future<List<RatingDetail>> fetchRatingDetails({
    required String token,
    required String poemId,
  }) async => const [];

  @override
  Future<void> followUser(String token, String userId) async {}

  @override
  Future<void> unfollowUser(String token, String userId) async {}

  @override
  Future<List<UserProfile>> fetchFollowers(String token, String userId) async => const [];

  @override
  Future<List<UserProfile>> fetchFollowing(String token, String userId) async => const [];

  @override
  Future<int> likePoem(String token, String poemId) async => 0;

  @override
  Future<int> unlikePoem(String token, String poemId) async => 0;

  @override
  Future<Map<String, dynamic>> fetchLikeStatus(String token, String poemId) async => {'like_count': 0, 'is_liked': false};

  @override
    Future<Comment> addComment(String token, String poemId, String content, {String? parentId}) async => Comment(
        id: '1',
        userId: '1',
      parentId: parentId,
        username: 'demo',
        name: 'Demo',
        content: content,
        createdAt: DateTime.now(),
      );

  @override
  Future<List<Comment>> fetchComments(String token, String poemId) async => const [];

  @override
  Future<void> deleteComment(String token, String commentId) async {}

  @override
  Future<Archive> archivePoem(
    String token,
    String poemId, {
    String title = '',
    String category = '',
    String notes = '',
    String tags = '',
    String source = 'saved',
  }) async => Archive(
        id: '1',
        poemId: poemId,
        poemTitle: 'Demo',
        poemBody: 'Demo',
        authorName: 'Demo',
        authorUsername: 'demo',
        archiveTitle: title,
        category: '',
        notes: notes,
        tags: tags,
        source: source,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  Future<List<Archive>> fetchArchives(String token) async => const [];

  @override
  Future<Archive> updateArchive(
    String token,
    String archiveId, {
    required String title,
    required String category,
    required String notes,
    required String tags,
  }) async => Archive(
        id: archiveId,
        poemId: '1',
        poemTitle: 'Demo',
        poemBody: 'Demo',
        authorName: 'Demo',
        authorUsername: 'demo',
        archiveTitle: title,
        category: '',
        notes: notes,
        tags: tags,
        source: 'saved',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  Future<void> deleteArchive(String token, String archiveId) async {}
}
