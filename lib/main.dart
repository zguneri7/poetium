import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'api.dart';

void main() => runApp(const PoetiumApp());

const ink = Color(0xFF1F3935);
const paper = Color(0xFFF8F4EB);
const coral = Color(0xFFB58A2A);

class PoetiumAvatar extends StatelessWidget {
  const PoetiumAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    this.radius = 20,
  });

  final String username;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE8D3B7),
      backgroundImage: image == null
          ? null
          : MemoryImage(base64Decode(image.split(',').last)),
      child: image == null
          ? Text(
              username.isEmpty ? '?' : username[0].toUpperCase(),
              style: const TextStyle(color: ink, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }
}

enum AvatarAction { gallery, camera, remove }

class PoetiumBrand extends StatelessWidget {
  const PoetiumBrand({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/branding/poetium_icon.png',
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(width: 12),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POETIUM',
            style: TextStyle(
              color: Color(0xFF171717),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.2,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'ŞİİR BURADA YAŞAR',
            style: TextStyle(
              color: Color(0xFF8A7966),
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    ],
  );
}

enum AuthMode { login, register, verifyEmail, forgotPassword }

const bool emailVerificationRequired = bool.fromEnvironment(
  'EMAIL_VERIFICATION_REQUIRED',
  defaultValue: false,
);

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.repository,
    required this.onAuthenticated,
  });

  final PoetiumRepository repository;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final verificationToken = TextEditingController();
  AuthMode mode = AuthMode.login;
  bool obscurePassword = true;
  bool googleLoading = false;
  bool submitting = false;

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    email.dispose();
    password.dispose();
    verificationToken.dispose();
    super.dispose();
  }

  void switchMode(AuthMode value) {
    formKey.currentState?.reset();
    setState(() => mode = value);
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => submitting = true);
    try {
      if (mode == AuthMode.forgotPassword) {
        await widget.repository.forgotPassword(email.text.trim());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Şifre yenileme talebi alındı. E-posta kutunu kontrol et.',
            ),
          ),
        );
        switchMode(AuthMode.login);
        return;
      }
      if (mode == AuthMode.register) {
        await widget.repository.register(
          name: name.text.trim(),
          username: username.text.trim(),
          email: email.text.trim(),
          password: password.text,
        );
        if (!mounted) return;
        if (emailVerificationRequired) {
          setState(() => mode = AuthMode.verifyEmail);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doğrulama kodunu e-posta kutundan al.')),
          );
          return;
        }
        final session = await widget.repository.login(
          email: email.text.trim(),
          password: password.text,
        );
        if (mounted) widget.onAuthenticated(session);
        return;
      }
      if (mode == AuthMode.verifyEmail) {
        await widget.repository.verifyEmail(verificationToken.text.trim());
        if (!mounted) return;
        setState(() => mode = AuthMode.login);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-posta doğrulandı. Şimdi giriş yapabilirsin.')),
        );
        return;
      }
      final session = await widget.repository.login(
        email: email.text.trim(),
        password: password.text,
      );
      if (mounted) {
        widget.onAuthenticated(session);
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  Future<void> continueWithGoogle() async {
    setState(() => googleLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => googleLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google OAuth istemci kimliği yapılandırılmalı.'),
      ),
    );
  }

  String? requiredField(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    final isRegister = mode == AuthMode.register;
    final isVerifyEmail = mode == AuthMode.verifyEmail;
    final isForgot = mode == AuthMode.forgotPassword;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/branding/poetium_icon.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                        isVerifyEmail
                          ? 'E-postanı doğrula'
                          : isRegister
                          ? 'Hesabını oluştur'
                          : isForgot
                          ? 'Şifreni yenile'
                          : 'Tekrar hoş geldin',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        isVerifyEmail
                          ? 'E-postana gönderilen doğrulama kodunu gir.'
                          : isRegister
                          ? 'Şiirlerini kendi adınla yayınlamaya başla.'
                          : isForgot
                          ? 'E-posta adresine yenileme bağlantısı göndereceğiz.'
                          : 'Şiirlerine ve topluluğuna devam et.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (isVerifyEmail) ...[
                      TextFormField(
                        key: const Key('verification-token'),
                        controller: verificationToken,
                        decoration: const InputDecoration(
                          labelText: 'Doğrulama kodu',
                          prefixIcon: Icon(Icons.verified_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => requiredField(
                          value,
                          'E-posta doğrulama kodunu gir.',
                        ),
                      ),
                    ] else if (isRegister) ...[
                      TextFormField(
                        key: const Key('register-name'),
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Ad soyad',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            requiredField(value, 'Ad soyadını yaz.'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('register-username'),
                        controller: username,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı adı',
                          prefixText: '@',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            requiredField(value, 'Kullanıcı adı belirle.'),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      key: const Key('auth-email'),
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Geçerli bir e-posta yaz.';
                        }
                        return null;
                      },
                    ),
                    if (!isForgot && !isVerifyEmail) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('auth-password'),
                        controller: password,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: obscurePassword
                                ? 'Şifreyi göster'
                                : 'Şifreyi gizle',
                            onPressed: () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 6
                            ? 'Şifre en az 6 karakter olmalı.'
                            : null,
                      ),
                    ],
                    if (mode == AuthMode.login)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => switchMode(AuthMode.forgotPassword),
                          child: const Text('Şifremi unuttum'),
                        ),
                      ),
                    if (!isForgot && !isVerifyEmail) ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        key: const Key('google-auth'),
                        onPressed: googleLoading ? null : continueWithGoogle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF252525),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: const BorderSide(color: Color(0xFFD8D3CB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: googleLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'G',
                                    style: TextStyle(
                                      color: Color(0xFF4285F4),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'sans-serif',
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Google ile devam et'),
                                ],
                              ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'veya e-posta ile',
                                style: TextStyle(
                                  color: Colors.black45,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                      ),
                    ] else
                      const SizedBox(height: 10),
                    FilledButton(
                      key: const Key('auth-submit'),
                      onPressed: submitting ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      child: submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isRegister
                                  ? 'Kayıt ol'
                                  : isVerifyEmail
                                  ? 'E-postayı doğrula'
                                  : isForgot
                                  ? 'Bağlantı gönder'
                                  : 'Giriş yap',
                            ),
                    ),
                    const SizedBox(height: 14),
                    if (isVerifyEmail)
                      TextButton(
                        onPressed: () => switchMode(AuthMode.login),
                        child: const Text('Giriş ekranına dön'),
                      )
                    else if (isForgot)
                      TextButton(
                        onPressed: () => switchMode(AuthMode.login),
                        child: const Text('Giriş ekranına dön'),
                      )
                    else
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            isRegister
                                ? 'Zaten hesabın var mı?'
                                : 'Hesabın yok mu?',
                          ),
                          TextButton(
                            key: Key(
                              isRegister
                                  ? 'switch-to-login'
                                  : 'switch-to-register',
                            ),
                            onPressed: () => switchMode(
                              isRegister ? AuthMode.login : AuthMode.register,
                            ),
                            child: Text(isRegister ? 'Giriş yap' : 'Kayıt ol'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PoetiumApp extends StatefulWidget {
  const PoetiumApp({super.key, this.repository});
  final PoetiumRepository? repository;

  @override
  State<PoetiumApp> createState() => _PoetiumAppState();
}

class _PoetiumAppState extends State<PoetiumApp> {
  AuthSession? session;
  late final PoetiumRepository repository =
      widget.repository ?? HttpPoetiumRepository();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Poetium',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: paper),
      scaffoldBackgroundColor: paper,
      fontFamily: 'serif',
      useMaterial3: true,
    ),
    home: session == null
        ? AuthScreen(
            repository: repository,
            onAuthenticated: (value) => setState(() => session = value),
          )
        : HomeScreen(
            account: session!.user,
            token: session!.token,
            repository: repository,
            onLogout: () => setState(() => session = null),
          ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.account,
    required this.token,
    required this.repository,
    required this.onLogout,
  });

  final UserAccount account;
  final String token;
  final PoetiumRepository repository;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  List<Poem> poems = [];
  List<UserProfile> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadPoems();
  }

  Future<void> loadPoems() async {
    try {
      final generalFeed = await widget.repository.fetchPoems(widget.token);
      final followFeed = await widget.repository.fetchFollowingFeed(widget.token);
      final userResult = await widget.repository.fetchUsers(widget.token);
      final combined = <String, Poem>{};
      for (final poem in [...generalFeed, ...followFeed]) {
        combined[poem.id] = poem;
      }
      if (mounted) {
        setState(() {
          poems = combined.values.toList();
          users = userResult;
          loading = false;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> rate(Poem poem) async {
    final scores = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      builder: (_) => RatingSheet(poem: poem),
    );
    if (scores == null) return;
    try {
      final updated = await widget.repository.ratePoem(
        token: widget.token,
        poemId: poem.id,
        scores: scores,
      );
      if (mounted) {
        setState(
          () => poems[poems.indexWhere((item) => item.id == poem.id)] = updated,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> showRatingDetails(Poem poem) async {
    try {
      final ratings = await widget.repository.fetchRatingDetails(
        token: widget.token,
        poemId: poem.id,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: paper,
        builder: (_) => RatingDetailsSheet(poem: poem, ratings: ratings),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      loading
          ? const Center(child: CircularProgressIndicator())
          : Discover(
              poems: poems,
              users: users,
              currentUserId: widget.account.id,
              token: widget.token,
              repository: widget.repository,
              onRate: rate,
              onShowRatingDetails: showRatingDetails,
            ),
      Compose(
        users: users,
        currentUserId: widget.account.id,
        token: widget.token,
        repository: widget.repository,
        onPoemCreated: (poem) => setState(() => poems.insert(0, poem)),
        onPublish:
            ({
              required title,
              required body,
              required visibility,
              required recipientIds,
            }) async {
              final poem = await widget.repository.createPoem(
                token: widget.token,
                title: title,
                body: body,
                visibility: visibility,
                recipientIds: recipientIds,
              );
              if (!mounted) return poem;
              setState(() {
                poems.insert(0, poem);
                tab = 2;
              });
              return poem;
            },
      ),
      ProfileScreen(
        account: widget.account,
        poems: poems
            .where((poem) => poem.authorId == widget.account.id)
            .toList(),
        token: widget.token,
        repository: widget.repository,
        onLogout: widget.onLogout,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8D3B7),
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit),
            label: 'Yaz',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Ben',
          ),
        ],
      ),
    );
  }
}

class Discover extends StatefulWidget {
  const Discover({
    super.key,
    required this.poems,
    required this.users,
    required this.currentUserId,
    required this.token,
    required this.repository,
    required this.onRate,
    required this.onShowRatingDetails,
  });
  final List<Poem> poems;
  final List<UserProfile> users;
  final String currentUserId;
  final String token;
  final PoetiumRepository repository;
  final ValueChanged<Poem> onRate;
  final ValueChanged<Poem> onShowRatingDetails;

  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final filteredPoems = query.isEmpty
        ? widget.poems
        : widget.poems.where((poem) {
            return poem.title.toLowerCase().contains(query) ||
                poem.body.toLowerCase().contains(query) ||
                poem.author.toLowerCase().contains(query);
          }).toList();
    final filteredUsers = query.isEmpty
        ? const <UserProfile>[]
        : widget.users.where((user) {
            return user.name.toLowerCase().contains(query) ||
                user.username.toLowerCase().contains(query);
          }).toList();

    return Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PoetiumBrand(),
        const SizedBox(height: 32),
        const Text(
          'BUGÜNÜN DİZELERİ',
          style: TextStyle(
            color: coral,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.3,
          ),
        ),
        const Text(
          'Keşfet',
          style: TextStyle(
            color: ink,
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Şiir veya kullanıcı ara...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Aramayı temizle',
                    onPressed: () {
                      search.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        if (query.isNotEmpty && filteredUsers.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'KULLANICILAR',
            style: TextStyle(
              color: coral,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filteredUsers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final user = filteredUsers[index];
                return ActionChip(
                  avatar: PoetiumAvatar(
                    username: user.username,
                    avatarUrl: user.avatarUrl,
                    radius: 15,
                  ),
                  label: Text('@${user.username}'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => UserProfileDetailScreen(
                        user: user,
                        token: widget.token,
                        repository: widget.repository,
                        currentUserId: widget.currentUserId,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Wrap(
          spacing: 8,
          children: [
            Chip(
              label: Text('Senin için'),
              backgroundColor: ink,
              labelStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Chip(label: Text('Yeni'), backgroundColor: Colors.white),
            Chip(label: Text('Takipte'), backgroundColor: Colors.white),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: filteredPoems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => PoemCard(
              poem: filteredPoems[index],
              token: widget.token,
              repository: widget.repository,
              onRate: () => widget.onRate(filteredPoems[index]),
              onShowRatingDetails: () =>
                  widget.onShowRatingDetails(filteredPoems[index]),
            ),
          ),
        ),
      ],
    ),
  );
  }
}

class PoemCard extends StatefulWidget {
  const PoemCard({
    super.key,
    required this.poem,
    required this.token,
    required this.repository,
    required this.onRate,
    required this.onShowRatingDetails,
  });
  final Poem poem;
  final String token;
  final PoetiumRepository repository;
  final VoidCallback onRate;
  final VoidCallback onShowRatingDetails;

  @override
  State<PoemCard> createState() => _PoemCardState();
}

class _PoemCardState extends State<PoemCard> {
  int? likeCount;
  bool isLiked = false;
  int? commentCount;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final likeStatus =
          await widget.repository.fetchLikeStatus(widget.token, widget.poem.id);
      final comments =
          await widget.repository.fetchComments(widget.token, widget.poem.id);
      setState(() {
        likeCount = likeStatus['like_count'] as int;
        isLiked = likeStatus['is_liked'] as bool;
        commentCount = comments.length;
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    try {
      final newCount = isLiked
          ? await widget.repository.unlikePoem(widget.token, widget.poem.id)
          : await widget.repository.likePoem(widget.token, widget.poem.id);
      setState(() {
        likeCount = newCount;
        isLiked = !isLiked;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE8E0D3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFE8D3B7),
                    child: Icon(Icons.person, color: ink, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.poem.author,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.poem.visibility,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    widget.poem.ratings == 0
                        ? '-'
                        : widget.poem.average.toStringAsFixed(1),
                    style: const TextStyle(
                      color: coral,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                widget.poem.title,
                style: const TextStyle(
                  fontSize: 24,
                  color: ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.poem.body,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF505952),
                ),
              ),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: widget.poem.ratings == 0
                        ? null
                        : widget.onShowRatingDetails,
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: Text('${widget.poem.ratings} değerlendirme'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black54,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _toggleLike,
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_outline,
                      size: 18,
                      color: isLiked ? Colors.red : null,
                    ),
                    label: Text('${likeCount ?? 0}'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isLiked ? Colors.red : Colors.black54,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _showCommentSheet(context);
                    },
                    icon: const Icon(Icons.comment_outlined, size: 18),
                    label: Text('${commentCount ?? 0}'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black54,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onRate,
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: const Text('Puanla'),
                  ),
                  IconButton(
                    tooltip: 'Arşive kaydet',
                    onPressed: () => _showArchiveSheet(context),
                    icon: const Icon(Icons.bookmark_border),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Future<void> _showCommentSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CommentSheet(
        token: widget.token,
        poemId: widget.poem.id,
        repository: widget.repository,
        onCommentAdded: () {
          _loadStats();
        },
      ),
    );
  }

  Future<void> _showArchiveSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      builder: (_) => ArchiveEditorSheet(
        token: widget.token,
        repository: widget.repository,
        poem: widget.poem,
      ),
    );
  }
}

class CommentSheet extends StatefulWidget {
  const CommentSheet({
    super.key,
    required this.token,
    required this.poemId,
    required this.repository,
    required this.onCommentAdded,
  });

  final String token;
  final String poemId;
  final PoetiumRepository repository;
  final VoidCallback onCommentAdded;

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final controller = TextEditingController();
  bool sending = false;
  Comment? replyingTo;
  List<Comment> comments = const [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final result = await widget.repository.fetchComments(
        widget.token,
        widget.poemId,
      );
      if (mounted) {
        setState(() => comments = result);
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await widget.repository.addComment(
        widget.token,
        widget.poemId,
        text,
        parentId: replyingTo?.id,
      );
      controller.clear();
      setState(() => replyingTo = null);
      await _loadComments();
      widget.onCommentAdded();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yorum eklenemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Yorumlar',
            style: TextStyle(
              color: ink,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (comments.isEmpty)
            const Text('Henüz yorum yok.', style: TextStyle(color: Colors.black54))
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: comments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) => Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${comments[index].username}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(comments[index].content),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => replyingTo = comments[index],
                            ),
                            icon: const Icon(Icons.reply, size: 16),
                            label: const Text('Yanıtla'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (replyingTo != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '@${replyingTo!.username} kullanıcısına yanıt veriyorsun',
                    style: const TextStyle(color: ink, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Yanıtı iptal et',
                  onPressed: () => setState(() => replyingTo = null),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Yorum yaz...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: sending ? null : _submit,
                child: sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Gönder'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.account,
    required this.poems,
    required this.token,
    required this.repository,
    required this.onLogout,
  });

  final UserAccount account;
  final List<Poem> poems;
  final String token;
  final PoetiumRepository repository;
  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<UserProfile> followers = const [];
  List<UserProfile> following = const [];
  String? avatarUrl;
  bool avatarSaving = false;

  @override
  void initState() {
    super.initState();
    avatarUrl = widget.account.avatarUrl;
    _loadFollowStats();
  }

  Future<void> _changeAvatar() async {
    final action = await showModalBottomSheet<AvatarAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, AvatarAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Fotoğraf çek'),
              onTap: () => Navigator.pop(context, AvatarAction.camera),
            ),
            if (avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Profil resmini kaldır'),
                onTap: () => Navigator.pop(context, AvatarAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == AvatarAction.remove) {
      if (avatarUrl == null) return;
      await _saveAvatar(null);
      return;
    }
    final source = action == AvatarAction.gallery
        ? ImageSource.gallery
        : ImageSource.camera;
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _saveAvatar('data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Future<void> _saveAvatar(String? dataUrl) async {
    setState(() => avatarSaving = true);
    try {
      final updated = await widget.repository.updateProfileImage(
        widget.token,
        dataUrl,
      );
      if (mounted) setState(() => avatarUrl = updated.avatarUrl);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => avatarSaving = false);
    }
  }

  Future<void> _loadFollowStats() async {
    try {
      final followerResult = await widget.repository.fetchFollowers(
        widget.token,
        widget.account.id,
      );
      final followingResult = await widget.repository.fetchFollowing(
        widget.token,
        widget.account.id,
      );
      if (!mounted) return;
      setState(() {
        followers = followerResult;
        following = followingResult;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        followers = const [];
        following = const [];
      });
    }
  }

  Future<void> _toggleProfileFollow(String userId) async {
    final isFollowing = following.any((user) => user.id == userId);
    try {
      if (isFollowing) {
        await widget.repository.unfollowUser(widget.token, userId);
      } else {
        await widget.repository.followUser(widget.token, userId);
      }
      await _loadFollowStats();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takip işlemi başarısız oldu.')),
      );
    }
  }

  void _showFollowList(BuildContext context, List<UserProfile> users, String title) {
    final query = TextEditingController();
    var expanded = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (bottomContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final text = query.text.trim().toLowerCase();
            final filteredUsers = users.where((user) {
              if (text.isEmpty) return true;
              return user.name.toLowerCase().contains(text) ||
                  user.username.toLowerCase().contains(text);
            }).toList();
            final visibleUsers = expanded
                ? filteredUsers
                : filteredUsers.take(5).toList();
            return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: query,
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Takip edilenlerde ara...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filteredUsers.isEmpty)
                    const Text(
                      'Hiçbir sonuç bulunamadı.',
                      style: TextStyle(color: Colors.black54),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: visibleUsers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final user = visibleUsers[index];
                          final isFollowing = following.any((item) => item.id == user.id);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: PoetiumAvatar(
                              username: user.username,
                              avatarUrl: user.avatarUrl,
                            ),
                            title: Text('@${user.username}'),
                            subtitle: Text(user.name),
                            onTap: () {
                              Navigator.of(modalContext).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => UserProfileDetailScreen(
                                    user: user,
                                    token: widget.token,
                                    repository: widget.repository,
                                    currentUserId: widget.account.id,
                                  ),
                                ),
                              );
                            },
                            trailing: user.id == widget.account.id
                                ? null
                                : TextButton(
                                    onPressed: () => _toggleProfileFollow(user.id),
                                    child: Text(
                                      isFollowing ? 'Takipten çık' : 'Takip et',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                  if (filteredUsers.length > 5)
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: () => setModalState(() => expanded = !expanded),
                        icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                        label: Text(expanded ? 'Daha az göster' : 'Tümünü göster (${filteredUsers.length})'),
                      ),
                    ),
                ],
              ),
            ),
          );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const PoetiumBrand(),
                  IconButton(
                    tooltip: 'Çıkış yap',
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout, color: ink),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Row(
                children: [
                  GestureDetector(
                    onTap: avatarSaving ? null : _changeAvatar,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        PoetiumAvatar(
                          username: widget.account.username,
                          avatarUrl: avatarUrl,
                          radius: 39,
                        ),
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: ink,
                          child: avatarSaving
                              ? const SizedBox.square(
                                  dimension: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${widget.account.username}',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.account.name,
                          style: const TextStyle(
                            color: coral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.account.email,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _ProfileStat(
                    value: '${widget.poems.length}',
                    label: 'Yayın',
                    onTap: () {},
                  ),
                  _ProfileStat(
                    value: '${followers.length}',
                    label: 'Takipçi',
                    onTap: () => _showFollowList(context, followers, 'Takipçiler'),
                  ),
                  _ProfileStat(
                    value: '${following.length}',
                    label: 'Takip',
                    onTap: () => _showFollowList(context, following, 'Takip edilenler'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ArchiveScreen(
                          token: widget.token,
                          repository: widget.repository,
                          currentUserId: widget.account.id,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    label: const Text('Arşivim'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FavoritesScreen(
                          token: widget.token,
                          repository: widget.repository,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.favorite_outline),
                    label: const Text('Favorilerim'),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                'YAYINLARIM',
                style: TextStyle(
                  color: coral,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Dizelerin',
                style: TextStyle(
                  color: ink,
                  fontSize: 31,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      if (widget.poems.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                'Henüz bir şiir yayınlamadın.\nİlk dizeni Yaz sekmesinden paylaş.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.5),
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          sliver: SliverList.separated(
            itemCount: widget.poems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => PoemCard(
              poem: widget.poems[index],
              token: widget.token,
              repository: widget.repository,
              onRate: () {},
              onShowRatingDetails: () {},
            ),
          ),
        ),
    ],
  );
}

class ArchiveEditorSheet extends StatefulWidget {
  const ArchiveEditorSheet({
    super.key,
    required this.token,
    required this.repository,
    required this.poem,
    this.archive,
  });

  final String token;
  final PoetiumRepository repository;
  final Poem poem;
  final Archive? archive;

  @override
  State<ArchiveEditorSheet> createState() => _ArchiveEditorSheetState();
}

class _ArchiveEditorSheetState extends State<ArchiveEditorSheet> {
  late final title = TextEditingController(
    text: widget.archive?.archiveTitle ?? widget.poem.title,
  );
  late final category = TextEditingController(
    text: widget.archive?.category ?? '',
  );
  late final notes = TextEditingController(text: widget.archive?.notes ?? '');
  late final tags = TextEditingController(text: widget.archive?.tags ?? '');
  bool saving = false;

  @override
  void dispose() {
    title.dispose();
    category.dispose();
    notes.dispose();
    tags.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      if (widget.archive == null) {
        await widget.repository.archivePoem(
          widget.token,
          widget.poem.id,
          title: title.text.trim(),
          category: category.text.trim(),
          notes: notes.text.trim(),
          tags: tags.text.trim(),
        );
      } else {
        await widget.repository.updateArchive(
          widget.token,
          widget.archive!.id,
          title: title.text.trim(),
          category: category.text.trim(),
          notes: notes.text.trim(),
          tags: tags.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.archive == null ? 'Arşive kaydet' : 'Arşivi düzenle',
            style: const TextStyle(color: ink, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Arşiv başlığı', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'Kategori', hintText: 'Örneğin: Aşk, Doğa, Günlük', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: notes, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Notlar', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: tags, decoration: const InputDecoration(labelText: 'Etiketler', hintText: 'duygu, gece, şehir', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : save,
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
            ),
          ),
        ],
      ),
    ),
  );
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    required this.token,
    required this.repository,
  });

  final String token;
  final PoetiumRepository repository;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Poem> poems = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.repository.fetchLikedPoems(widget.token);
      if (mounted) setState(() { poems = result; loading = false; });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      title: const Text('Favorilerim'),
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : poems.isEmpty
        ? const Center(
            child: Text(
              'Henüz favori şiirin yok.',
              style: TextStyle(color: Colors.black54),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            itemCount: poems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => PoemCard(
              poem: poems[index],
              token: widget.token,
              repository: widget.repository,
              onRate: () {},
              onShowRatingDetails: () {},
            ),
          ),
  );
}

class _ArchiveLibraryItem {
  const _ArchiveLibraryItem({required this.poem, this.archive});

  final Poem poem;
  final Archive? archive;
}

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({
    super.key,
    required this.token,
    required this.repository,
    required this.currentUserId,
  });
  final String token;
  final PoetiumRepository repository;
  final String currentUserId;

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Archive> archives = const [];
  List<Poem> ownPoems = const [];
  String selectedCategory = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.repository.fetchArchives(widget.token),
        widget.repository.fetchUserPoems(widget.token, widget.currentUserId),
      ]);
      if (mounted) {
        setState(() {
          archives = results[0] as List<Archive>;
          ownPoems = results[1] as List<Poem>;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _edit(Archive archive) async {
    final poem = Poem(
      id: archive.poemId,
      authorId: '',
      title: archive.poemTitle,
      body: archive.poemBody,
      author: '@${archive.authorUsername}',
      visibility: 'Herkese açık',
      scores: const {},
      ratings: 0,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      builder: (_) => ArchiveEditorSheet(
        token: widget.token,
        repository: widget.repository,
        poem: poem,
        archive: archive,
      ),
    );
    _load();
  }

  Future<void> _delete(Archive archive) async {
    await widget.repository.deleteArchive(widget.token, archive.id);
    _load();
  }

  Future<void> _archiveOwnPoem(Poem poem) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      builder: (_) => ArchiveEditorSheet(
        token: widget.token,
        repository: widget.repository,
        poem: poem,
      ),
    );
    _load();
  }

  String _exportText(Poem poem, {Archive? archive}) => [
        archive?.archiveTitle.isNotEmpty == true ? archive!.archiveTitle : poem.title,
        '',
        'Şair: ${poem.author}',
        if (archive != null) 'Kaynak: ${archive.source == 'ocr' ? 'OCR' : 'Kaydedilen şiir'}',
        if (archive?.category.isNotEmpty == true) 'Kategori: ${archive!.category}',
        '',
        poem.body,
        if (archive?.tags.isNotEmpty == true) ...['', 'Etiketler: ${archive!.tags}'],
        if (archive?.notes.isNotEmpty == true) ...['', 'Notlar:', archive!.notes],
      ].join('\n');

  Future<void> _exportTextFile(Poem poem, {Archive? archive}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: _exportText(poem, archive: archive),
        subject: archive?.archiveTitle.isNotEmpty == true ? archive!.archiveTitle : poem.title,
      ),
    );
  }

  Future<void> _exportPdf(Poem poem, {Archive? archive}) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              archive?.archiveTitle.isNotEmpty == true ? archive!.archiveTitle : poem.title,
            ),
          ),
          pw.Text(poem.author),
          if (archive?.category.isNotEmpty == true) pw.Text('Kategori: ${archive!.category}'),
          pw.SizedBox(height: 20),
          pw.Text(poem.body),
          if (archive?.tags.isNotEmpty == true) ...[
            pw.SizedBox(height: 20),
            pw.Text('Etiketler: ${archive!.tags}'),
          ],
          if (archive?.notes.isNotEmpty == true) ...[
            pw.SizedBox(height: 12),
            pw.Text('Notlar:'),
            pw.Text(archive!.notes),
          ],
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: '${poem.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf',
    );
  }

  Future<void> _showExportMenu(Poem poem, {Archive? archive}) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF olarak paylaş'),
              onTap: () {
                Navigator.pop(context);
                _exportPdf(poem, archive: archive);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Metin olarak paylaş'),
              onTap: () {
                Navigator.pop(context);
                _exportTextFile(poem, archive: archive);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedPoemIds = archives.map((archive) => archive.poemId).toSet();
    final categories = archives
        .map((archive) => archive.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final items = <_ArchiveLibraryItem>[
      ...archives.map(
        (archive) => _ArchiveLibraryItem(
          archive: archive,
          poem: Poem(
            id: archive.poemId,
            authorId: widget.currentUserId,
            title: archive.poemTitle,
            body: archive.poemBody,
            author: '@${archive.authorUsername}',
            visibility: 'Herkese açık',
            scores: const {},
            ratings: 0,
          ),
        ),
      ),
      ...ownPoems.where((poem) => !savedPoemIds.contains(poem.id)).map(
        (poem) => _ArchiveLibraryItem(poem: poem),
      ),
    ].where((item) => selectedCategory.isEmpty ||
        item.archive?.category == selectedCategory).toList();

    return Scaffold(
    backgroundColor: paper,
    appBar: AppBar(title: const Text('Arşivim'), backgroundColor: paper, foregroundColor: ink, elevation: 0),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (categories.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Tümü'),
                        selected: selectedCategory.isEmpty,
                        onSelected: (_) => setState(() => selectedCategory = ''),
                      ),
                      ...categories.map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: selectedCategory == category,
                            onSelected: (_) => setState(() => selectedCategory = category),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Arşivinde bu kategoride şiir yok.', style: TextStyle(color: Colors.black54)))
                    : ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final item = items[index];
              final archive = item.archive;
              final poem = item.poem;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  title: Text(
                    archive?.archiveTitle.isNotEmpty == true
                        ? archive!.archiveTitle
                        : poem.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    archive == null
                        ? 'Kendi şiirin\nArşive eklemek için menüyü aç'
                        : '@${archive.authorUsername}\n${archive.category.isEmpty ? 'Kategori belirtilmemiş' : archive.category}',
                    maxLines: 2,
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'archive') {
                        _archiveOwnPoem(poem);
                      } else if (value == 'edit') {
                        _edit(archive!);
                      } else if (value == 'delete') {
                        _delete(archive!);
                      } else {
                        _showExportMenu(poem, archive: archive);
                      }
                    },
                    itemBuilder: (_) => archive == null
                        ? const [
                            PopupMenuItem(value: 'archive', child: Text('Arşive ekle')),
                            PopupMenuItem(value: 'export', child: Text('Çıktı al')),
                          ]
                        : const [
                            PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                            PopupMenuItem(value: 'delete', child: Text('Sil')),
                            PopupMenuItem(value: 'export', child: Text('Çıktı al')),
                          ],
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(title: Text(poem.title), content: Text(poem.body)),
                  ),
                ),
              );
            },
          ),
              ),
            ],
          ),
  );
  }
}

class RatingDetailsSheet extends StatelessWidget {
  const RatingDetailsSheet({
    super.key,
    required this.poem,
    required this.ratings,
  });

  final Poem poem;
  final List<RatingDetail> ratings;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Değerlendirmeler',
            style: TextStyle(
              color: ink,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(poem.title, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          if (ratings.isEmpty)
            const Text(
              'Henüz değerlendirme yok.',
              style: TextStyle(color: Colors.black54),
            )
          else
            ...ratings.map(
              (rating) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE8E0D3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${rating.username}',
                                    style: const TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    rating.name,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              rating.totalScore.toStringAsFixed(1),
                              style: const TextStyle(
                                color: coral,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...rating.scores.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  '${entry.value}/5',
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class UserProfileDetailScreen extends StatefulWidget {
  const UserProfileDetailScreen({
    super.key,
    required this.user,
    required this.token,
    required this.repository,
    required this.currentUserId,
  });

  final UserProfile user;
  final String token;
  final PoetiumRepository repository;
  final String currentUserId;

  @override
  State<UserProfileDetailScreen> createState() => _UserProfileDetailScreenState();
}

class _UserProfileDetailScreenState extends State<UserProfileDetailScreen> {
  bool loading = true;
  bool isFollowing = false;
  List<Poem> poems = const [];
  List<UserProfile> followers = const [];
  List<UserProfile> following = const [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final poemResult = await widget.repository.fetchUserPoems(
        widget.token,
        widget.user.id,
      );
      final followersResult = await widget.repository.fetchFollowers(
        widget.token,
        widget.user.id,
      );
      final followingResult = await widget.repository.fetchFollowing(
        widget.token,
        widget.user.id,
      );
      if (!mounted) return;
      setState(() {
        poems = poemResult;
        followers = followersResult;
        following = followingResult;
        isFollowing = followersResult.any((item) => item.id == widget.currentUserId);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        poems = const [];
        followers = const [];
        following = const [];
        loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.user.id == widget.currentUserId) return;
    try {
      if (isFollowing) {
        await widget.repository.unfollowUser(widget.token, widget.user.id);
      } else {
        await widget.repository.followUser(widget.token, widget.user.id);
      }
      await _loadProfile();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takip işlemi başarısız oldu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      title: Text('@${widget.user.username}'),
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PoetiumAvatar(
                      username: widget.user.username,
                      avatarUrl: widget.user.avatarUrl,
                      radius: 34,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${widget.user.username}',
                            style: const TextStyle(
                              color: ink,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.user.name,
                            style: const TextStyle(
                              color: coral,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (widget.user.id != widget.currentUserId)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _toggleFollow,
                      style: FilledButton.styleFrom(backgroundColor: ink),
                      child: Text(isFollowing ? 'Takipten çık' : 'Takip et'),
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _ProfileStat(value: '${poems.length}', label: 'Yayın'),
                    _ProfileStat(value: '${followers.length}', label: 'Takipçi'),
                    _ProfileStat(value: '${following.length}', label: 'Takip'),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  'ŞİİRLERİ',
                  style: TextStyle(
                    color: coral,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                if (poems.isEmpty)
                  const Text(
                    'Bu kullanıcının henüz yayımlanmış şiiri yok.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  ...poems.map(
                    (poem) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PoemCard(
                        poem: poem,
                        token: widget.token,
                        repository: widget.repository,
                        onRate: () {},
                        onShowRatingDetails: () {},
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: ink,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

typedef PublishPoem =
    Future<Poem> Function({
      required String title,
      required String body,
      required String visibility,
      required List<String> recipientIds,
    });

class OcrCaptureScreen extends StatefulWidget {
  const OcrCaptureScreen({
    super.key,
    required this.token,
    required this.repository,
    required this.onPoemCreated,
  });

  final String token;
  final PoetiumRepository repository;
  final ValueChanged<Poem> onPoemCreated;

  @override
  State<OcrCaptureScreen> createState() => _OcrCaptureScreenState();
}

class _OcrCaptureScreenState extends State<OcrCaptureScreen> {
  final picker = ImagePicker();
  final title = TextEditingController(text: 'Fotoğraftan şiir');
  final text = TextEditingController();
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  XFile? image;
  bool recognizing = false;
  bool saving = false;

  @override
  void dispose() {
    title.dispose();
    text.dispose();
    recognizer.close();
    super.dispose();
  }

  Future<void> choose(ImageSource source) async {
    try {
      final selected = await picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 2400,
      );
      if (selected == null) return;
      setState(() {
        image = selected;
        recognizing = true;
      });
      final result = await recognizer.processImage(
        InputImage.fromFilePath(selected.path),
      );
      if (mounted) {
        setState(() {
          text.text = result.text;
          recognizing = false;
        });
        if (result.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fotoğrafta okunabilir metin bulunamadı.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => recognizing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf işlenemedi.')),
        );
      }
    }
  }

  Future<void> save({required bool archive}) async {
    if (saving || text.text.trim().isEmpty || title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve tanınan metin gerekli.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final poem = await widget.repository.createPoem(
        token: widget.token,
        title: title.text.trim(),
        body: text.text.trim(),
        visibility: 'public',
      );
      if (archive) {
        await widget.repository.archivePoem(
          widget.token,
          poem.id,
          title: title.text.trim(),
          source: 'ocr',
        );
      }
      widget.onPoemCreated(poem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(archive ? 'Şiir yayınlandı ve arşive kaydedildi.' : 'Şiir yayınlandı.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      title: const Text('Fotoğraftan şiir'),
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: recognizing ? null : () => choose(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeriden seç'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: recognizing ? null : () => choose(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Fotoğraf çek'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(image!.path), height: 190, fit: BoxFit.cover),
            ),
          if (recognizing) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Türkçe metin okunuyor...', textAlign: TextAlign.center),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Şiir başlığı', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: text,
            minLines: 10,
            maxLines: 18,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(labelText: 'Tanınan metni düzenle', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving || recognizing ? null : () => save(archive: false),
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Şiir olarak yayınla'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving || recognizing ? null : () => save(archive: true),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Yayınla ve OCR arşivine kaydet'),
          ),
        ],
      ),
    ),
  );
}

class Compose extends StatefulWidget {
  const Compose({
    super.key,
    required this.users,
    required this.currentUserId,
    required this.token,
    required this.repository,
    required this.onPoemCreated,
    required this.onPublish,
  });
  final List<UserProfile> users;
  final String currentUserId;
  final String token;
  final PoetiumRepository repository;
  final ValueChanged<Poem> onPoemCreated;
  final PublishPoem onPublish;
  @override
  State<Compose> createState() => _ComposeState();
}

class _ComposeState extends State<Compose> {
  final title = TextEditingController(), body = TextEditingController();
  String visibility = 'Herkese açık';
  bool publishing = false;
  final recipients = <String>{};
  final followedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    try {
      final following = await widget.repository.fetchFollowing(
        widget.token,
        widget.currentUserId,
      );
      if (mounted) {
        setState(() {
          followedIds.clear();
          followedIds.addAll(following.map((user) => user.id));
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow(String userId) async {
    final isFollowing = followedIds.contains(userId);
    try {
      if (isFollowing) {
        await widget.repository.unfollowUser(widget.token, userId);
      } else {
        await widget.repository.followUser(widget.token, userId);
      }
      if (mounted) {
        setState(() {
          if (isFollowing) {
            followedIds.remove(userId);
          } else {
            followedIds.add(userId);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takip işlemi başarısız oldu.')),
        );
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> submit({bool archiveOnly = false}) async {
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve şiir metni gerekli.')),
      );
      return;
    }
    setState(() => publishing = true);
    try {
      final poem = await widget.onPublish(
        title: title.text.trim(),
        body: body.text.trim(),
        visibility: archiveOnly
            ? 'private'
            : (visibility == 'Seçtiklerim' ? 'selected' : 'public'),
        recipientIds: archiveOnly ? const [] : recipients.toList(),
      );
      await widget.repository.archivePoem(widget.token, poem.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              archiveOnly
                  ? 'Şiir sadece arşivine kaydedildi.'
                  : 'Şiir yayınlandı ve arşivine kaydedildi.',
            ),
          ),
        );
      }
      title.clear();
      body.clear();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => publishing = false);
      }
    }
  }

  Future<void> openOcr() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OcrCaptureScreen(
          token: widget.token,
          repository: widget.repository,
          onPoemCreated: widget.onPoemCreated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YENİ BİR METİN',
          style: TextStyle(
            color: coral,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.3,
          ),
        ),
        const Text(
          'Şiirini paylaş',
          style: TextStyle(
            color: ink,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: openOcr,
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Fotoğraftan şiir oluştur'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: title,
          style: const TextStyle(
            color: ink,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(hintText: 'Başlık'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: body,
          minLines: 7,
          maxLines: 10,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'Dizelerini buraya bırak...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'KİMLER GÖREBİLİR?',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF706C64),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Herkese açık', label: Text('Herkese açık')),
            ButtonSegment(value: 'Seçtiklerim', label: Text('Seçtiklerim')),
          ],
          selected: {visibility},
          onSelectionChanged: (value) =>
              setState(() => visibility = value.first),
        ),
        if (visibility == 'Seçtiklerim') ...[
          const SizedBox(height: 10),
          ...widget.users.map(
            (person) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('@${person.username}'),
              subtitle: Text(person.name),
              trailing: TextButton(
                onPressed: () => _toggleFollow(person.id),
                child: Text(
                  followedIds.contains(person.id) ? 'Takipten çık' : 'Takip et',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              leading: Checkbox(
                value: recipients.contains(person.id),
                activeColor: ink,
                onChanged: (selected) => setState(
                  () => selected!
                      ? recipients.add(person.id)
                      : recipients.remove(person.id),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: publishing ? null : submit,
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: publishing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Yayınla'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: publishing ? null : () => submit(archiveOnly: true),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Sadece arşive al'),
          ),
        ),
      ],
    ),
  );
}

class RatingSheet extends StatefulWidget {
  const RatingSheet({super.key, required this.poem});
  final Poem poem;
  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

const List<Map<String, dynamic>> poemEvaluationCriteria = [
  {
    'key': 'duygusalEtki',
    'label': 'Duygusal Etki',
    'weight': 20,
    'description': 'Okuyucuda duygu ve kalıcı etki yaratması',
  },
  {
    'key': 'ozgunluk',
    'label': 'Özgünlük',
    'weight': 20,
    'description': 'Klişelerden uzaklık, özgün yaklaşım ve ifade',
  },
  {
    'key': 'imgeMecaz',
    'label': 'İmge & Mecaz',
    'weight': 15,
    'description': 'Benzetme, metafor, sembol ve imgelerin gücü',
  },
  {
    'key': 'dilSozcukSecimi',
    'label': 'Dil & Sözcük Seçimi',
    'weight': 15,
    'description':
        'Kelime hassasiyeti, anlatım gücü ve gereksiz ifadelerden kaçınma',
  },
  {
    'key': 'ahenkAkis',
    'label': 'Ahenk & Akış',
    'weight': 10,
    'description': 'Ritmik akış, ses uyumu ve okunabilirlik',
  },
  {
    'key': 'butunlukYapi',
    'label': 'Bütünlük & Yapı',
    'weight': 10,
    'description': 'Dizelerin/kıtaların birbirini desteklemesi ve kompozisyon',
  },
  {
    'key': 'siirTeknigi',
    'label': 'Şiir Tekniği',
    'weight': 5,
    'description': 'Kafiye, redif, ölçü, vezin ve teknik unsurlar',
  },
  {
    'key': 'derinlik',
    'label': 'Derinlik',
    'weight': 5,
    'description': 'Alt anlamlar, çağrışım gücü ve yeniden okunabilirlik',
  },
];

class _RatingSheetState extends State<RatingSheet> {
  final scores = {
    for (final criterion in poemEvaluationCriteria)
      criterion['key'] as String: 0,
  };

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Değerlendir',
            style: TextStyle(
              color: ink,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${widget.poem.title} için düşünceni bırak.',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          ...poemEvaluationCriteria.map((criterion) {
            final key = criterion['key'] as String;
            final label = criterion['label'] as String;
            final weight = criterion['weight'] as int;
            final description = criterion['description'] as String;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: ink,
                                ),
                              ),
                            ),
                            Text(
                              '%$weight',
                              style: const TextStyle(
                                fontSize: 12,
                                color: coral,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(
                    5,
                    (index) => IconButton(
                      onPressed: () => setState(() => scores[key] = index + 1),
                      icon: Icon(
                        index < scores[key]! ? Icons.star : Icons.star_border,
                        color: coral,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: scores.values.any((score) => score == 0)
                  ? null
                  : () => Navigator.pop(context, scores),
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Puanlamayı gönder'),
            ),
          ),
        ],
      ),
    ),
  );
}
