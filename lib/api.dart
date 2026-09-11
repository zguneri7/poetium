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
  });
  final String id;
  final String name;
  final String username;
  final String email;

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    id: json['id'].toString(),
    name: json['name'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
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
  });
  final String id;
  final String name;
  final String username;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'].toString(),
    name: json['name'] as String,
    username: json['username'] as String,
  );
}

abstract class PoetiumRepository {
  Future<AuthSession> register({
    required String name,
    required String username,
    required String email,
    required String password,
  });
  Future<AuthSession> login({required String email, required String password});
  Future<void> forgotPassword(String email);
  Future<List<Poem>> fetchPoems(String token);
  Future<List<UserProfile>> fetchUsers(String token);
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
  Future<AuthSession> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async => sessionFrom(
    await request(
      'POST',
      '/auth/register',
      body: {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      },
    ),
  );

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
  Future<List<Poem>> fetchPoems(String token) async {
    final data = await request('GET', '/poems', token: token);
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
}
