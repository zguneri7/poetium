import 'package:flutter/material.dart';

import 'api.dart';

void main() => runApp(const PoetiumApp());

const ink = Color(0xFF1F3935);
const paper = Color(0xFFF8F4EB);
const coral = Color(0xFFB58A2A);

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

enum AuthMode { login, register, forgotPassword }

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
      final session = mode == AuthMode.register
          ? await widget.repository.register(
              name: name.text.trim(),
              username: username.text.trim(),
              email: email.text.trim(),
              password: password.text,
            )
          : await widget.repository.login(
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
                      isRegister
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
                      isRegister
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
                    if (isRegister) ...[
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
                    if (!isForgot) ...[
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
                    if (!isForgot) ...[
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
                                  : isForgot
                                  ? 'Bağlantı gönder'
                                  : 'Giriş yap',
                            ),
                    ),
                    const SizedBox(height: 14),
                    if (isForgot)
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
      final result = await widget.repository.fetchPoems(widget.token);
      final userResult = await widget.repository.fetchUsers(widget.token);
      if (mounted) {
        setState(() {
          poems = result;
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
              onRate: rate,
              onShowRatingDetails: showRatingDetails,
            ),
      Compose(
        users: users,
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
              if (!mounted) return;
              setState(() {
                poems.insert(0, poem);
                tab = 2;
              });
            },
      ),
      ProfileScreen(
        account: widget.account,
        poems: poems
            .where((poem) => poem.authorId == widget.account.id)
            .toList(),
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

class Discover extends StatelessWidget {
  const Discover({
    super.key,
    required this.poems,
    required this.onRate,
    required this.onShowRatingDetails,
  });
  final List<Poem> poems;
  final ValueChanged<Poem> onRate;
  final ValueChanged<Poem> onShowRatingDetails;
  @override
  Widget build(BuildContext context) => Padding(
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
            itemCount: poems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => PoemCard(
              poem: poems[index],
              onRate: () => onRate(poems[index]),
              onShowRatingDetails: () => onShowRatingDetails(poems[index]),
            ),
          ),
        ),
      ],
    ),
  );
}

class PoemCard extends StatelessWidget {
  const PoemCard({
    super.key,
    required this.poem,
    required this.onRate,
    required this.onShowRatingDetails,
  });
  final Poem poem;
  final VoidCallback onRate;
  final VoidCallback onShowRatingDetails;
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
                      poem.author,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      poem.visibility,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                poem.ratings == 0 ? '-' : poem.average.toStringAsFixed(1),
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
            poem.title,
            style: const TextStyle(
              fontSize: 24,
              color: ink,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            poem.body,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF505952),
            ),
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: poem.ratings == 0 ? null : onShowRatingDetails,
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: Text('${poem.ratings} değerlendirme'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black54,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: onRate,
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Puanla'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.account,
    required this.poems,
    required this.onLogout,
  });

  final UserAccount account;
  final List<Poem> poems;
  final VoidCallback onLogout;

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
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, color: ink),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Row(
                children: [
                  CircleAvatar(
                    radius: 39,
                    backgroundColor: const Color(0xFF171717),
                    child: Text(
                      account.username.isEmpty
                          ? '?'
                          : account.username[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFD9B75D),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${account.username}',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          account.name,
                          style: const TextStyle(
                            color: coral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          account.email,
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
                  _ProfileStat(value: '${poems.length}', label: 'Yayın'),
                  const _ProfileStat(value: '0', label: 'Takipçi'),
                  const _ProfileStat(value: '0', label: 'Takip'),
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
      if (poems.isEmpty)
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
            itemCount: poems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => PoemCard(
              poem: poems[index],
              onRate: () {},
              onShowRatingDetails: () {},
            ),
          ),
        ),
    ],
  );
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

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
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
  );
}

typedef PublishPoem =
    Future<void> Function({
      required String title,
      required String body,
      required String visibility,
      required List<String> recipientIds,
    });

class Compose extends StatefulWidget {
  const Compose({super.key, required this.users, required this.onPublish});
  final List<UserProfile> users;
  final PublishPoem onPublish;
  @override
  State<Compose> createState() => _ComposeState();
}

class _ComposeState extends State<Compose> {
  final title = TextEditingController(), body = TextEditingController();
  String visibility = 'Herkese açık';
  bool publishing = false;
  final recipients = <String>{};
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve şiir metni gerekli.')),
      );
      return;
    }
    setState(() => publishing = true);
    try {
      await widget.onPublish(
        title: title.text.trim(),
        body: body.text.trim(),
        visibility: visibility == 'Seçtiklerim' ? 'selected' : 'public',
        recipientIds: recipients.toList(),
      );
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
            (person) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('@${person.username}'),
              subtitle: Text(person.name),
              value: recipients.contains(person.id),
              activeColor: ink,
              onChanged: (selected) => setState(
                () => selected!
                    ? recipients.add(person.id)
                    : recipients.remove(person.id),
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
