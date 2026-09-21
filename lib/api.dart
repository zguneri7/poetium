import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.avatarUrl,
  });
  final String id;
  final String name;
  final String username;
  final String email;
  final String? avatarUrl;

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    id: json['id'].toString(),
    name: json['name'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    avatarUrl: json['avatar_url'] as String?,
  );
}

class Poem {
  Poem({
    required this.id,
    required this.authorId,
    required this.title,
    required this.body,
    required this.author,
    required this.visibility,
    required this.scores,
    required this.ratings,
    double? totalScore,
  }) : totalScore =
           totalScore ??
           (scores.isEmpty
               ? 0
               : scores.values.reduce((a, b) => a + b) / scores.length);
  final String id;
  final String authorId;
  final String title;
  final String body;
  final String author;
  final String visibility;
  final Map<String, double> scores;
  final int ratings;
  final double totalScore;
  double get average => totalScore;

  factory Poem.fromJson(Map<String, dynamic> json) => Poem(
    id: json['id'].toString(),
    authorId: json['author_id'].toString(),
    title: json['title'] as String,
    body: json['body'] as String,
    author:
        '@${json['author_username'] as String? ?? json['author_name'] as String}',
    visibility: json['visibility'] == 'public'
        ? 'Herkese açık'
        : 'Seçili kişiler',
    ratings: (json['ratings'] as num).toInt(),
    scores: {
      'İmge': (json['image'] as num).toDouble(),
      'Ritim': (json['rhythm'] as num).toDouble(),
      'Duygu': (json['emotion'] as num).toDouble(),
      'Özgünlük': (json['originality'] as num).toDouble(),
    },
    totalScore: (json['total_score'] as num? ?? json['average'] as num? ?? 0)
        .toDouble(),
  );
}

class RatingDetail {
  const RatingDetail({
    required this.userId,
    required this.username,
    required this.name,
    required this.totalScore,
    required this.scores,
  });

  final String userId;
  final String username;
  final String name;
  final double totalScore;
  final Map<String, int> scores;

  factory RatingDetail.fromJson(Map<String, dynamic> json) => RatingDetail(
    userId: json['user_id'].toString(),
    username: json['username'] as String,
    name: json['name'] as String,
    totalScore: (json['total_score'] as num).toDouble(),
    scores: (json['scores'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    ),
  );
}

class AuthSession {
  const AuthSession({required this.token, required this.user});
  final String token;
  final UserAccount user;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'].toString(),
    name: json['name'] as String,
    username: json['username'] as String,
    avatarUrl: json['avatar_url'] as String?,
  );
}

class Comment {
  const Comment({
    required this.id,
    required this.userId,
    required this.parentId,
    required this.username,
    required this.name,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? parentId;
  final String username;
  final String name;
  final String content;
  final DateTime createdAt;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'].toString(),
    userId: json['user_id'].toString(),
    parentId: json['parent_id']?.toString(),
    username: json['username'] as String,
    name: json['name'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class Archive {
  const Archive({
    required this.id,
    required this.poemId,
    required this.poemTitle,
    required this.poemBody,
    required this.authorName,
    required this.authorUsername,
    required this.archiveTitle,
    required this.category,
    required this.notes,
    required this.tags,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String poemId;
  final String poemTitle;
  final String poemBody;
  final String authorName;
  final String authorUsername;
  final String archiveTitle;
  final String category;
  final String notes;
  final String tags;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Archive.fromJson(Map<String, dynamic> json) => Archive(
    id: json['id'].toString(),
    poemId: json['poem_id'].toString(),
    poemTitle: json['poem_title'] as String,
    poemBody: json['poem_body'] as String,
    authorName: json['author_name'] as String,
    authorUsername: json['author_username'] as String,
    archiveTitle: json['archive_title'] as String? ?? '',
    category: json['category'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    tags: json['tags'] as String? ?? '',
    source: json['source'] as String? ?? 'saved',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}

abstract class PoetiumRepository {
  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
  });
  Future<void> verifyEmail(String token);
  Future<AuthSession> login({required String email, required String password});
  Future<void> forgotPassword(String email);
  Future<List<Poem>> fetchPoems(String token);
  Future<List<Poem>> fetchLikedPoems(String token);
  Future<List<Poem>> fetchFollowingFeed(String token);
  Future<List<UserProfile>> fetchUsers(String token);
  Future<UserAccount> updateProfileImage(String token, String? dataUrl);
  Future<List<Poem>> fetchUserPoems(String token, String userId);
  Future<Poem> createPoem({
    required String token,
    required String title,
    required String body,
    required String visibility,
    List<String> recipientIds = const [],
  });

  Future<Poem> ratePoem({
    required String token,
    required String poemId,
    required Map<String, int> scores,
  });
  Future<List<RatingDetail>> fetchRatingDetails({
    required String token,
    required String poemId,
  });

  // Takip
  Future<void> followUser(String token, String userId);
  Future<void> unfollowUser(String token, String userId);
  Future<List<UserProfile>> fetchFollowers(String token, String userId);
  Future<List<UserProfile>> fetchFollowing(String token, String userId);

  // Beğeni
  Future<int> likePoem(String token, String poemId);
  Future<int> unlikePoem(String token, String poemId);
  Future<Map<String, dynamic>> fetchLikeStatus(String token, String poemId);

  // Yorum
  Future<Comment> addComment(
    String token,
    String poemId,
    String content, {
    String? parentId,
  });
  Future<List<Comment>> fetchComments(String token, String poemId);
  Future<void> deleteComment(String token, String commentId);

  // Arşiv
  Future<Archive> archivePoem(
    String token,
    String poemId, {
    String title = '',
    String category = '',
    String notes = '',
    String tags = '',
    String source = 'saved',
  });
  Future<List<Archive>> fetchArchives(String token);
  Future<Archive> updateArchive(
    String token,
    String archiveId, {
    required String title,
    required String category,
    required String notes,
    required String tags,
  });
  Future<void> deleteArchive(String token, String archiveId);
  Future<String> recognizeGemini({
    required String token,
    required String mimeType,
    required String imageBase64,
  });
}

class HttpPoetiumRepository implements PoetiumRepository {
  HttpPoetiumRepository({String? baseUrl, http.Client? client})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_URL',
            defaultValue: 'http://10.0.2.2:3000',
          ),
      client = client ?? http.Client();

  final String baseUrl;
  final http.Client client;

  @override
  Future<String> recognizeGemini({
    required String token,
    required String mimeType,
    required String imageBase64,
  }) async {
    final data = await request(
      'POST',
      '/ocr/gemini',
      token: token,
      body: {'mimeType': mimeType, 'imageBase64': imageBase64},
    );
    return data['text'] as String;
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    late http.Response response;
    try {
      response = switch (method) {
        'GET' => await client.get(uri, headers: headers),
        'POST' => await client.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        'PUT' => await client.put(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        'DELETE' => await client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported method: $method'),
      };
    } catch (_) {
      throw const ApiException('Sunucuya ulaşılamadı. Bağlantını kontrol et.');
    }
    final data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(data['message'] as String? ?? 'İşlem tamamlanamadı.');
    }
    return data;
  }

  AuthSession sessionFrom(Map<String, dynamic> data) => AuthSession(
    token: data['token'] as String,
    user: UserAccount.fromJson(data['user'] as Map<String, dynamic>),
  );

  @override
  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    await request(
      'POST',
      '/auth/register',
      body: {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      },
    );
  }

  @override
  Future<void> verifyEmail(String token) async {
    await request(
      'POST',
      '/auth/verify-email',
      body: {'token': token.trim()},
    );
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => sessionFrom(
    await request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    ),
  );

  @override
  Future<void> forgotPassword(String email) async {
    await request('POST', '/auth/forgot-password', body: {'email': email});
  }

  @override
  Future<List<UserProfile>> fetchUsers(String token) async {
    final data = await request('GET', '/users', token: token);
    return (data['users'] as List)
        .map((item) => UserProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UserAccount> updateProfileImage(String token, String? dataUrl) async {
    final data = await request(
      'PUT',
      '/me/profile-image',
      token: token,
      body: {'avatarUrl': dataUrl},
    );
    return UserAccount.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<List<Poem>> fetchPoems(String token) async {
    final data = await request('GET', '/poems', token: token);
    return (data['poems'] as List)
        .map((item) => Poem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Poem>> fetchLikedPoems(String token) async {
    final data = await request('GET', '/me/liked-poems', token: token);
    return (data['poems'] as List)
        .map((item) => Poem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Poem>> fetchUserPoems(String token, String userId) async {
    final data = await request('GET', '/users/$userId/poems', token: token);
    return (data['poems'] as List)
        .map((item) => Poem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Poem>> fetchFollowingFeed(String token) async {
    final data = await request('GET', '/feed', token: token);
    return (data['poems'] as List)
        .map((item) => Poem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Poem> createPoem({
    required String token,
    required String title,
    required String body,
    required String visibility,
    List<String> recipientIds = const [],
  }) async {
    final data = await request(
      'POST',
      '/poems',
      token: token,
      body: {
        'title': title,
        'body': body,
        'visibility': visibility,
        'recipientIds': recipientIds,
      },
    );
    return Poem.fromJson(data['poem'] as Map<String, dynamic>);
  }

  @override
  Future<Poem> ratePoem({
    required String token,
    required String poemId,
    required Map<String, int> scores,
  }) async {
    final data = await request(
      'PUT',
      '/poems/$poemId/rating',
      token: token,
      body: {'scores': scores},
    );
    return Poem.fromJson(data['poem'] as Map<String, dynamic>);
  }

  @override
  Future<List<RatingDetail>> fetchRatingDetails({
    required String token,
    required String poemId,
  }) async {
    final data = await request('GET', '/poems/$poemId/ratings', token: token);
    return (data['ratings'] as List)
        .map((item) => RatingDetail.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> followUser(String token, String userId) async {
    await request('POST', '/users/$userId/follow', token: token);
  }

  @override
  Future<void> unfollowUser(String token, String userId) async {
    await request('POST', '/users/$userId/unfollow', token: token);
  }

  @override
  Future<List<UserProfile>> fetchFollowers(String token, String userId) async {
    final data = await request('GET', '/users/$userId/followers', token: token);
    return (data['followers'] as List)
        .map((item) => UserProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<UserProfile>> fetchFollowing(String token, String userId) async {
    final data = await request('GET', '/users/$userId/following', token: token);
    return (data['following'] as List)
        .map((item) => UserProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> likePoem(String token, String poemId) async {
    final data = await request('POST', '/poems/$poemId/like', token: token);
    return (data['like_count'] as num).toInt();
  }

  @override
  Future<int> unlikePoem(String token, String poemId) async {
    final data = await request('POST', '/poems/$poemId/unlike', token: token);
    return (data['like_count'] as num).toInt();
  }

  @override
  Future<Map<String, dynamic>> fetchLikeStatus(String token, String poemId) async {
    return await request('GET', '/poems/$poemId/likes', token: token);
  }

  @override
  Future<Comment> addComment(
    String token,
    String poemId,
    String content,
    {String? parentId}
  ) async {
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parentId'] = parentId;
    final data = await request(
      'POST',
      '/poems/$poemId/comments',
      token: token,
      body: body,
    );
    return Comment.fromJson(data['comment'] as Map<String, dynamic>);
  }

  @override
  Future<List<Comment>> fetchComments(String token, String poemId) async {
    final data = await request('GET', '/poems/$poemId/comments', token: token);
    return (data['comments'] as List)
        .map((item) => Comment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteComment(String token, String commentId) async {
    await request('DELETE', '/comments/$commentId', token: token);
  }

  @override
  Future<Archive> archivePoem(
    String token,
    String poemId, {
    String title = '',
    String category = '',
    String notes = '',
    String tags = '',
    String source = 'saved',
  }) async {
    final data = await request(
      'POST',
      '/poems/$poemId/archive',
      token: token,
      body: {
        'title': title,
        'category': category,
        'notes': notes,
        'tags': tags,
        'source': source,
      },
    );
    return Archive.fromJson(data['archive'] as Map<String, dynamic>);
  }

  @override
  Future<List<Archive>> fetchArchives(String token) async {
    final data = await request('GET', '/me/archives', token: token);
    return (data['archives'] as List)
        .map((item) => Archive.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Archive> updateArchive(
    String token,
    String archiveId, {
    required String title,
    required String category,
    required String notes,
    required String tags,
  }) async {
    final data = await request(
      'PUT',
      '/archives/$archiveId',
      token: token,
      body: {
        'title': title,
        'category': category,
        'notes': notes,
        'tags': tags,
      },
    );
    return Archive.fromJson(data['archive'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteArchive(String token, String archiveId) async {
    await request('DELETE', '/archives/$archiveId', token: token);
  }
}
