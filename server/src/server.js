import 'dotenv/config';
import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import cors from 'cors';
import express from 'express';
import jwt from 'jsonwebtoken';
import nodemailer from 'nodemailer';
import { pool, query } from './db.js';
import { migrate } from './migrate.js';

if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET is required.');

const emailVerificationRequired = process.env.EMAIL_VERIFICATION_REQUIRED === 'true';
const geminiApiKey = process.env.GEMINI_API_KEY;
const geminiRpmLimit = Number(process.env.GEMINI_RPM_LIMIT ?? 5);
const geminiRpdLimit = Number(process.env.GEMINI_RPD_LIMIT ?? 20);
const geminiRequests = [];
let geminiDay = new Date().toISOString().slice(0, 10);
let geminiDayCount = 0;

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

const mailer = process.env.SMTP_HOST
  ? nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT ?? 587),
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER
        ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
        : undefined,
    })
  : null;

async function sendVerificationEmail(email, token) {
  if (!mailer) throw new Error('SMTP_HOST, SMTP_USER ve SMTP_PASS yapılandırılmalı.');
  const verifyUrl = `${process.env.APP_URL ?? 'http://localhost:3000'}/auth/verify-email?token=${token}`;
  await mailer.sendMail({
    from: process.env.SMTP_FROM ?? process.env.SMTP_USER,
    to: email,
    subject: 'Poetium e-posta doğrulaması',
    text: `Poetium hesabını doğrulamak için bu kodu uygulamaya gir:\n\n${token}\n\nBağlantı: ${verifyUrl}\n\nBu kod 30 dakika geçerlidir.`,
  });
}

function reserveGeminiRequest() {
  const now = Date.now();
  const today = new Date(now).toISOString().slice(0, 10);
  if (today !== geminiDay) {
    geminiDay = today;
    geminiDayCount = 0;
  }
  while (geminiRequests[0] <= now - 60_000) geminiRequests.shift();
  if (geminiDayCount >= geminiRpdLimit) {
    return 'Günlük Gemini OCR kotası doldu. Yarın tekrar deneyin.';
  }
  if (geminiRequests.length >= geminiRpmLimit) {
    return 'Gemini OCR dakikalık kotası doldu. Bir dakika sonra tekrar deneyin.';
  }
  geminiRequests.push(now);
  geminiDayCount += 1;
  return null;
}

function publicUser(row) {
  return {
    id: String(row.id),
    name: row.name,
    username: row.username,
    email: row.email,
    avatar_url: row.avatar_url ?? null,
  };
}

function issueToken(user) {
  return jwt.sign({ sub: String(user.id) }, process.env.JWT_SECRET, { expiresIn: '30d' });
}

function authenticate(req, res, next) {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ message: 'Oturum gerekli.' });
  try {
    req.userId = jwt.verify(token, process.env.JWT_SECRET).sub;
    next();
  } catch {
      res.status(401).json({ message: 'Oturum geçersiz veya süresi dolmuş.' });
  }
}

function poemSelect(where = '') {
  return `SELECT p.id, p.title, p.body, p.visibility, p.created_at,
    u.id AS author_id, u.name AS author_name, u.username AS author_username,
    COUNT(r.user_id)::int AS ratings,
    COALESCE((
      AVG(r.duygusal_etki) * 20 +
      AVG(r.ozgunluk) * 20 +
      AVG(r.imge_mecaz) * 15 +
      AVG(r.dil_sozcuk_secimi) * 15 +
      AVG(r.ahenk_akis) * 10 +
      AVG(r.butunluk_yapi) * 10 +
      AVG(r.siir_teknigi) * 5 +
      AVG(r.derinlik) * 5
    ) / 100.0, 0)::float AS average,
    COALESCE((
      AVG(r.duygusal_etki) * 20 +
      AVG(r.ozgunluk) * 20 +
      AVG(r.imge_mecaz) * 15 +
      AVG(r.dil_sozcuk_secimi) * 15 +
      AVG(r.ahenk_akis) * 10 +
      AVG(r.butunluk_yapi) * 10 +
      AVG(r.siir_teknigi) * 5 +
      AVG(r.derinlik) * 5
    ) / 100.0, 0)::float AS total_score,
    COALESCE(AVG(r.imge_mecaz), 0)::float AS image,
    COALESCE(AVG(r.ahenk_akis), 0)::float AS rhythm,
    COALESCE(AVG(r.duygusal_etki), 0)::float AS emotion,
    COALESCE(AVG(r.ozgunluk), 0)::float AS originality
    FROM poems p JOIN users u ON u.id = p.author_id
    LEFT JOIN ratings r ON r.poem_id = p.id ${where}
    GROUP BY p.id, u.id ORDER BY p.created_at DESC`;
}

app.get('/health', async (_req, res, next) => {
  try {
    const result = await query('SELECT current_database() AS database, NOW() AS time');
    res.json({ status: 'ok', ...result.rows[0] });
  } catch (error) { next(error); }
});

app.post('/ocr/gemini', authenticate, async (req, res, next) => {
  try {
    if (!geminiApiKey) {
      return res.status(503).json({ message: 'Gemini OCR yapılandırılmamış.' });
    }
    const { mimeType, imageBase64 } = req.body;
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(mimeType) || typeof imageBase64 !== 'string') {
      return res.status(400).json({ message: 'Geçerli bir görsel gerekli.' });
    }
    const quotaMessage = reserveGeminiRequest();
    if (quotaMessage) return res.status(429).json({ message: quotaMessage });

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${encodeURIComponent(geminiApiKey)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: 'Bu görseldeki şiir metnini aynen yazıya aktar. Yorum yapma, metni açıklama, sadece satır sonlarını koruyarak OCR sonucunu döndür. Okuyamadığın kelimeleri tahmin etme.' },
              { inline_data: { mime_type: mimeType, data: imageBase64 } },
            ],
          }],
          generationConfig: { temperature: 0 },
        }),
      },
    );
    const data = await response.json();
    if (!response.ok) {
      if (response.status === 429) {
        return res.status(429).json({ message: 'Gemini OCR kotası doldu. Daha sonra tekrar deneyin.' });
      }
      return res.status(502).json({ message: 'Gemini OCR isteği başarısız oldu.' });
    }
    const text = data.candidates?.[0]?.content?.parts
      ?.map((part) => part.text ?? '')
      .join('')
      .trim();
    if (!text) return res.status(422).json({ message: 'Görselden metin okunamadı.' });
    res.json({ text });
  } catch (error) { next(error); }
});

app.post('/auth/register', async (req, res, next) => {
  try {
    const { name, username, email, password } = req.body;
    if (![name, username, email, password].every((value) => typeof value === 'string' && value.trim())) {
      return res.status(400).json({ message: 'Tüm alanları doldurun.' });
    }
    if (password.length < 6) return res.status(400).json({ message: 'Şifre en az 6 karakter olmalı.' });
    const passwordHash = await bcrypt.hash(password, 12);
    const result = await query(
      `INSERT INTO users(name, username, email, password_hash, email_verified_at)
       VALUES ($1, LOWER($2), LOWER($3), $4, ${emailVerificationRequired ? 'NULL' : 'NOW()'}) RETURNING *`,
      [name.trim(), username.trim(), email.trim(), passwordHash],
    );
    if (emailVerificationRequired) {
      const rawToken = crypto.randomBytes(32).toString('hex');
      const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
      await query(
        `INSERT INTO email_verification_tokens(user_id, token_hash, expires_at)
         VALUES ($1, $2, NOW() + INTERVAL '30 minutes')`,
        [result.rows[0].id, tokenHash],
      );
      await sendVerificationEmail(result.rows[0].email, rawToken);
      return res.status(202).json({ message: 'Doğrulama e-postası gönderildi.' });
    }
    res.status(201).json({ message: 'Kayıt başarılı.' });
  } catch (error) {
    if (error.code === '23505') return res.status(409).json({ message: 'E-posta veya kullanıcı adı zaten kayıtlı.' });
    next(error);
  }
});

app.post('/auth/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const result = await query('SELECT * FROM users WHERE email = LOWER($1)', [email ?? '']);
    const user = result.rows[0];
    if (!user) {
      return res.status(404).json({ message: 'Bu e-posta kayıtlı değil. Kayıt ol veya e-posta adresini kontrol et.' });
    }
    if (!(await bcrypt.compare(password ?? '', user.password_hash))) {
      return res.status(401).json({ message: 'E-posta veya şifre hatalı.' });
    }
    if (emailVerificationRequired && !user.email_verified_at) {
      return res.status(403).json({ message: 'Önce e-posta adresini doğrula.' });
    }
    res.json({ token: issueToken(user), user: publicUser(user) });
  } catch (error) { next(error); }
});

app.get('/auth/verify-email', async (req, res, next) => {
  try {
    const token = String(req.query.token ?? '');
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    const result = await query(
      `SELECT id, user_id FROM email_verification_tokens
       WHERE token_hash = $1 AND used_at IS NULL AND expires_at > NOW()`,
      [tokenHash],
    );
    if (!result.rows[0]) return res.status(400).send('Doğrulama bağlantısı geçersiz veya süresi dolmuş.');
    await query('UPDATE users SET email_verified_at = NOW() WHERE id = $1', [result.rows[0].user_id]);
    await query('UPDATE email_verification_tokens SET used_at = NOW() WHERE id = $1', [result.rows[0].id]);
    res.send('E-posta doğrulandı. Poetium uygulamasına dönüp giriş yapabilirsin.');
  } catch (error) { next(error); }
});

app.post('/auth/verify-email', async (req, res, next) => {
  try {
    const token = String(req.body.token ?? '');
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    const result = await query(
      `SELECT id, user_id FROM email_verification_tokens
       WHERE token_hash = $1 AND used_at IS NULL AND expires_at > NOW()`,
      [tokenHash],
    );
    if (!result.rows[0]) return res.status(400).json({ message: 'Doğrulama kodu geçersiz veya süresi dolmuş.' });
    await query('UPDATE users SET email_verified_at = NOW() WHERE id = $1', [result.rows[0].user_id]);
    await query('UPDATE email_verification_tokens SET used_at = NOW() WHERE id = $1', [result.rows[0].id]);
    res.json({ message: 'E-posta doğrulandı.' });
  } catch (error) { next(error); }
});

app.post('/auth/forgot-password', async (req, res, next) => {
  try {
    const email = String(req.body.email ?? '').trim();
    if (!email) {
      return res.status(400).json({ message: 'E-posta adresi gerekli.' });
    }
    const result = await query('SELECT id FROM users WHERE email = LOWER($1)', [email]);
    if (result.rows[0]) {
      const token = crypto.randomBytes(32).toString('hex');
      const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
      await query(
        `INSERT INTO password_reset_tokens(user_id, token_hash, expires_at)
         VALUES ($1, $2, NOW() + INTERVAL '30 minutes')`,
        [result.rows[0].id, tokenHash],
      );
    }
    res.json({ message: 'Şifre yenileme talebi alındı. E-posta kutunu kontrol et.' });
  } catch (error) { next(error); }
});

app.get('/me', authenticate, async (req, res, next) => {
  try {
    const result = await query('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (!result.rows[0]) return res.status(404).json({ message: 'Kullanıcı bulunamadı.' });
    res.json({ user: publicUser(result.rows[0]) });
  } catch (error) { next(error); }
});

app.put('/me/profile-image', authenticate, async (req, res, next) => {
  try {
    const avatarUrl = req.body.avatarUrl;
    if (avatarUrl !== null &&
        (typeof avatarUrl !== 'string' || !avatarUrl.startsWith('data:image/'))) {
      return res.status(400).json({ message: 'Profil resmi geçersiz.' });
    }
    if (typeof avatarUrl === 'string' && avatarUrl.length > 1500000) {
      return res.status(413).json({ message: 'Profil resmi çok büyük.' });
    }
    const result = await query(
      'UPDATE users SET avatar_url = $1 WHERE id = $2 RETURNING *',
      [avatarUrl, req.userId],
    );
    if (!result.rows[0]) return res.status(404).json({ message: 'Kullanıcı bulunamadı.' });
    res.json({ user: publicUser(result.rows[0]) });
  } catch (error) { next(error); }
});

  app.get('/users', authenticate, async (req, res, next) => {
    try {
      const result = await query(
        'SELECT id, name, username, avatar_url FROM users WHERE id <> $1 ORDER BY name LIMIT 100',
        [req.userId],
      );
      res.json({ users: result.rows.map((user) => ({ ...user, id: String(user.id) })) });
    } catch (error) { next(error); }
  });

app.get('/users/:id', authenticate, async (req, res, next) => {
  try {
    const result = await query(
      'SELECT id, name, username, avatar_url FROM users WHERE id = $1',
      [req.params.id],
    );
    if (!result.rows[0]) return res.status(404).json({ message: 'Kullanıcı bulunamadı.' });
    res.json({ user: { ...result.rows[0], id: String(result.rows[0].id) } });
  } catch (error) { next(error); }
});

app.get('/users/:id/poems', authenticate, async (req, res, next) => {
  try {
    const result = await query(
      poemSelect(`WHERE p.author_id = $1 AND (
        p.visibility = 'public' OR p.author_id = $2 OR EXISTS (
          SELECT 1 FROM poem_recipients pr WHERE pr.poem_id = p.id AND pr.user_id = $2
        )
      )`),
      [req.params.id, req.userId],
    );
    res.json({ poems: result.rows });
  } catch (error) { next(error); }
});

function poemAccessClause(currentUserId) {
  return `WHERE p.visibility = 'public'
    OR p.author_id = ${currentUserId}
    OR (p.visibility != 'private' AND EXISTS (
      SELECT 1 FROM poem_recipients pr WHERE pr.poem_id = p.id AND pr.user_id = ${currentUserId}
    ))
    OR (p.visibility != 'private' AND EXISTS (
      SELECT 1 FROM follows f WHERE f.follower_id = ${currentUserId} AND f.following_id = p.author_id
    ))`;
}

app.get('/poems', authenticate, async (req, res, next) => {
  try {
    const result = await query(poemSelect(poemAccessClause(req.userId)), [req.userId]);
    res.json({ poems: result.rows });
  } catch (error) { next(error); }
});

app.get('/feed', authenticate, async (req, res, next) => {
  try {
    const result = await query(
      poemSelect(`WHERE p.visibility != 'private' AND EXISTS (
        SELECT 1 FROM follows f WHERE f.follower_id = $1 AND f.following_id = p.author_id
      )`),
      [req.userId],
    );
    res.json({ poems: result.rows });
  } catch (error) { next(error); }
});

app.get('/me/poems', authenticate, async (req, res, next) => {
  try {
    const result = await query(poemSelect('WHERE p.author_id = $1'), [req.userId]);
    res.json({ poems: result.rows });
  } catch (error) { next(error); }
});

app.post('/poems', authenticate, async (req, res, next) => {
  const client = await pool.connect();
  try {
    const { title, body, visibility = 'public', recipientIds = [] } = req.body;
    if (!title?.trim() || !body?.trim() || !['public', 'selected', 'private'].includes(visibility)) {
      return res.status(400).json({ message: 'Şiir bilgileri geçersiz.' });
    }
    await client.query('BEGIN');
    const inserted = await client.query(
      `INSERT INTO poems(author_id, title, body, visibility) VALUES ($1, $2, $3, $4) RETURNING id`,
      [req.userId, title.trim(), body.trim(), visibility],
    );
    for (const recipientId of recipientIds) {
      await client.query('INSERT INTO poem_recipients(poem_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [inserted.rows[0].id, recipientId]);
    }
    await client.query('COMMIT');
    const result = await query(poemSelect('WHERE p.id = $1'), [inserted.rows[0].id]);
    res.status(201).json({ poem: result.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally { client.release(); }
});

app.get('/poems/:id/ratings', authenticate, async (req, res, next) => {
  try {
    const access = await query(
      `SELECT 1 FROM poems p
       WHERE p.id = $1 AND (
         p.visibility = 'public' OR p.author_id = $2 OR EXISTS (
           SELECT 1 FROM poem_recipients pr WHERE pr.poem_id = p.id AND pr.user_id = $2
         )
       )`,
      [req.params.id, req.userId],
    );
    if (!access.rows[0]) return res.status(404).json({ message: 'Şiir bulunamadı.' });

    const result = await query(
      `SELECT r.user_id, u.name, u.username,
        r.duygusal_etki, r.ozgunluk, r.imge_mecaz, r.dil_sozcuk_secimi,
        r.ahenk_akis, r.butunluk_yapi, r.siir_teknigi, r.derinlik,
        (
          r.duygusal_etki * 20 + r.ozgunluk * 20 + r.imge_mecaz * 15 +
          r.dil_sozcuk_secimi * 15 + r.ahenk_akis * 10 + r.butunluk_yapi * 10 +
          r.siir_teknigi * 5 + r.derinlik * 5
        ) / 100.0 AS total_score
       FROM ratings r
       JOIN users u ON u.id = r.user_id
       WHERE r.poem_id = $1
       ORDER BY r.updated_at DESC`,
      [req.params.id],
    );
    res.json({
      ratings: result.rows.map((rating) => ({
        user_id: String(rating.user_id),
        name: rating.name,
        username: rating.username,
        total_score: Number(rating.total_score),
        scores: {
          'Duygusal Etki': rating.duygusal_etki,
          'Özgünlük': rating.ozgunluk,
          'İmge & Mecaz': rating.imge_mecaz,
          'Dil & Sözcük Seçimi': rating.dil_sozcuk_secimi,
          'Ahenk & Akış': rating.ahenk_akis,
          'Bütünlük & Yapı': rating.butunluk_yapi,
          'Şiir Tekniği': rating.siir_teknigi,
          'Derinlik': rating.derinlik,
        },
      })),
    });
  } catch (error) { next(error); }
});

app.put('/poems/:id/rating', authenticate, async (req, res, next) => {
  try {
    const rawScores = req.body.scores ?? req.body;
    const normalized = {
      duygusalEtki: Number(rawScores.duygusalEtki ?? rawScores.duygusal_etki ?? rawScores['Duygusal Etki'] ?? rawScores.emotion ?? rawScores.Duygu ?? 0),
      ozgunluk: Number(rawScores.ozgunluk ?? rawScores.originality ?? rawScores['Özgünlük'] ?? rawScores.Ozgunluk ?? 0),
      imgeMecaz: Number(rawScores.imgeMecaz ?? rawScores.imge_mecaz ?? rawScores.image ?? rawScores['İmge & Mecaz'] ?? rawScores['İmge'] ?? rawScores.Imge ?? 0),
      dilSozcukSecimi: Number(rawScores.dilSozcukSecimi ?? rawScores.dil_sozcuk_secimi ?? rawScores['Dil & Sözcük Seçimi'] ?? 0),
      ahenkAkis: Number(rawScores.ahenkAkis ?? rawScores.ahenk_akis ?? rawScores.rhythm ?? rawScores['Ahenk & Akış'] ?? rawScores.Ritim ?? 0),
      butunlukYapi: Number(rawScores.butunlukYapi ?? rawScores.butunluk_yapi ?? rawScores['Bütünlük & Yapı'] ?? 0),
      siirTeknigi: Number(rawScores.siirTeknigi ?? rawScores.siir_teknigi ?? rawScores['Şiir Tekniği'] ?? 0),
      derinlik: Number(rawScores.derinlik ?? rawScores['Derinlik'] ?? 0),
    };
    const values = Object.values(normalized);
    if (values.length !== 8 || values.some((score) => !Number.isInteger(score) || score < 1 || score > 5)) {
      return res.status(400).json({ message: 'Tüm puanlar 1 ile 5 arasında olmalı.' });
    }
    await query(
      `INSERT INTO ratings(
        poem_id, user_id, duygusal_etki, ozgunluk, imge_mecaz, dil_sozcuk_secimi,
        ahenk_akis, butunluk_yapi, siir_teknigi, derinlik
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       ON CONFLICT (poem_id, user_id) DO UPDATE SET
         duygusal_etki = EXCLUDED.duygusal_etki,
         ozgunluk = EXCLUDED.ozgunluk,
         imge_mecaz = EXCLUDED.imge_mecaz,
         dil_sozcuk_secimi = EXCLUDED.dil_sozcuk_secimi,
         ahenk_akis = EXCLUDED.ahenk_akis,
         butunluk_yapi = EXCLUDED.butunluk_yapi,
         siir_teknigi = EXCLUDED.siir_teknigi,
         derinlik = EXCLUDED.derinlik,
         updated_at = NOW()`,
      [
        req.params.id,
        req.userId,
        normalized.duygusalEtki,
        normalized.ozgunluk,
        normalized.imgeMecaz,
        normalized.dilSozcukSecimi,
        normalized.ahenkAkis,
        normalized.butunlukYapi,
        normalized.siirTeknigi,
        normalized.derinlik,
      ],
    );
    const result = await query(poemSelect('WHERE p.id = $1'), [req.params.id]);
    res.json({ poem: result.rows[0] });
  } catch (error) { next(error); }
});

// TAKIP ENDPOINTS
app.post('/users/:id/follow', authenticate, async (req, res, next) => {
  try {
    if (String(req.userId) === req.params.id) return res.status(400).json({ message: 'Kendinizi takip edemezsiniz.' });
    const checkUser = await query('SELECT id FROM users WHERE id = $1', [req.params.id]);
    if (!checkUser.rows[0]) return res.status(404).json({ message: 'Kullanıcı bulunamadı.' });
    await query('INSERT INTO follows(follower_id, following_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [req.userId, req.params.id]);
    res.json({ message: 'Takip başarılı.' });
  } catch (error) { next(error); }
});

app.post('/users/:id/unfollow', authenticate, async (req, res, next) => {
  try {
    await query('DELETE FROM follows WHERE follower_id = $1 AND following_id = $2', [req.userId, req.params.id]);
    res.json({ message: 'Takip kaldırıldı.' });
  } catch (error) { next(error); }
});

app.get('/users/:id/followers', authenticate, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT u.id, u.name, u.username, u.avatar_url FROM users u
       JOIN follows f ON u.id = f.follower_id
       WHERE f.following_id = $1
       ORDER BY f.created_at DESC`,
      [req.params.id],
    );
    res.json({ followers: result.rows.map((u) => ({ ...u, id: String(u.id) })) });
  } catch (error) { next(error); }
});

app.get('/users/:id/following', authenticate, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT u.id, u.name, u.username, u.avatar_url FROM users u
       JOIN follows f ON u.id = f.following_id
       WHERE f.follower_id = $1
       ORDER BY f.created_at DESC`,
      [req.params.id],
    );
    res.json({ following: result.rows.map((u) => ({ ...u, id: String(u.id) })) });
  } catch (error) { next(error); }
});

// BEĞENI ENDPOINTS
app.post('/poems/:id/like', authenticate, async (req, res, next) => {
  try {
    await query('INSERT INTO likes(user_id, poem_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [req.userId, req.params.id]);
    const result = await query('SELECT COUNT(*)::int as like_count FROM likes WHERE poem_id = $1', [req.params.id]);
    res.json({ like_count: result.rows[0].like_count });
  } catch (error) { next(error); }
});

app.post('/poems/:id/unlike', authenticate, async (req, res, next) => {
  try {
    await query('DELETE FROM likes WHERE user_id = $1 AND poem_id = $2', [req.userId, req.params.id]);
    const result = await query('SELECT COUNT(*)::int as like_count FROM likes WHERE poem_id = $1', [req.params.id]);
    res.json({ like_count: result.rows[0].like_count });
  } catch (error) { next(error); }
});

app.get('/poems/:id/likes', authenticate, async (req, res, next) => {
  try {
    const result = await query(
      'SELECT COUNT(*)::int as like_count FROM likes WHERE poem_id = $1',
      [req.params.id],
    );
    const liked = await query(
      'SELECT 1 FROM likes WHERE user_id = $1 AND poem_id = $2',
      [req.userId, req.params.id],
    );
    res.json({ like_count: result.rows[0].like_count, is_liked: !!liked.rows[0] });
  } catch (error) { next(error); }
});

app.get('/me/liked-poems', authenticate, async (req, res, next) => {
  try {
    const result = await query(
      poemSelect(`WHERE EXISTS (
        SELECT 1 FROM likes l WHERE l.poem_id = p.id AND l.user_id = $1
      )`),
      [req.userId],
    );
    res.json({ poems: result.rows });
  } catch (error) { next(error); }
});

// YORUM ENDPOINTS
app.post('/poems/:id/comments', authenticate, async (req, res, next) => {
  try {
    const { content, parentId } = req.body;
    if (!content?.trim() || content.length > 500) return res.status(400).json({ message: 'Yorum 1-500 karakter olmalı.' });
    if (parentId) {
      const parent = await query(
        'SELECT id FROM comments WHERE id = $1 AND poem_id = $2',
        [parentId, req.params.id],
      );
      if (!parent.rows[0]) return res.status(400).json({ message: 'Yanıtlanacak yorum bulunamadı.' });
    }
    const result = await query(
      `INSERT INTO comments(poem_id, user_id, parent_id, content) VALUES ($1, $2, $3, $4)
       RETURNING id, poem_id, user_id, parent_id, content, created_at`,
      [req.params.id, req.userId, parentId || null, content.trim()],
    );
    const user = await query('SELECT name, username FROM users WHERE id = $1', [req.userId]);
    res.status(201).json({
      comment: {
        id: String(result.rows[0].id),
        poem_id: String(result.rows[0].poem_id),
        user_id: String(result.rows[0].user_id),
        parent_id: result.rows[0].parent_id ? String(result.rows[0].parent_id) : null,
        name: user.rows[0].name,
        username: user.rows[0].username,
        content: result.rows[0].content,
        created_at: result.rows[0].created_at,
      },
    });
  } catch (error) { next(error); }
});

app.get('/poems/:id/comments', authenticate, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT c.id, c.user_id, c.parent_id, c.content, c.created_at, u.name, u.username
       FROM comments c
       JOIN users u ON u.id = c.user_id
       WHERE c.poem_id = $1
       ORDER BY c.created_at DESC`,
      [req.params.id],
    );
    res.json({
      comments: result.rows.map((c) => ({
        id: String(c.id),
        user_id: String(c.user_id),
        parent_id: c.parent_id ? String(c.parent_id) : null,
        name: c.name,
        username: c.username,
        content: c.content,
        created_at: c.created_at,
      })),
    });
  } catch (error) { next(error); }
});

app.delete('/comments/:id', authenticate, async (req, res, next) => {
  try {
    const result = await query('SELECT user_id FROM comments WHERE id = $1', [req.params.id]);
    if (!result.rows[0]) return res.status(404).json({ message: 'Yorum bulunamadı.' });
    if (String(result.rows[0].user_id) !== String(req.userId)) {
      return res.status(403).json({ message: 'Bu yorum sizin değil.' });
    }
    await query('DELETE FROM comments WHERE id = $1', [req.params.id]);
    res.json({ message: 'Yorum silindi.' });
  } catch (error) { next(error); }
});

// ARŞİV ENDPOINTS
app.post('/poems/:id/archive', authenticate, async (req, res, next) => {
  try {
    const { title, category = '', notes = '', tags = '', source = 'saved' } = req.body;
    if (!['saved', 'ocr'].includes(source)) return res.status(400).json({ message: 'Kaynak geçersiz.' });
    const poem = await query('SELECT id FROM poems WHERE id = $1', [req.params.id]);
    if (!poem.rows[0]) return res.status(404).json({ message: 'Şiir bulunamadı.' });
    const result = await query(
      `INSERT INTO archives(user_id, poem_id, title, category, notes, tags, source)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (user_id, poem_id) DO UPDATE SET
         title = EXCLUDED.title, category = EXCLUDED.category,
         notes = EXCLUDED.notes, tags = EXCLUDED.tags,
         source = EXCLUDED.source, updated_at = NOW()
       RETURNING *`,
      [req.userId, req.params.id, title || '', category.substring(0, 80), notes.substring(0, 5000), tags.substring(0, 200), source],
    );
    const archive = await query(
      `SELECT a.id, a.poem_id, a.title, a.category, a.notes, a.tags, a.source,
        a.created_at, a.updated_at, p.title AS poem_title, p.body AS poem_body,
        u.name AS author_name, u.username AS author_username
       FROM archives a
       JOIN poems p ON p.id = a.poem_id
       JOIN users u ON u.id = p.author_id
       WHERE a.id = $1`,
      [result.rows[0].id],
    );
    const a = archive.rows[0];
    res.status(201).json({ archive: {
      id: String(a.id), poem_id: String(a.poem_id), poem_title: a.poem_title,
      poem_body: a.poem_body, author_name: a.author_name,
      author_username: a.author_username, archive_title: a.title,
      category: a.category ?? '', notes: a.notes, tags: a.tags,
      source: a.source, created_at: a.created_at, updated_at: a.updated_at,
    } });
  } catch (error) { next(error); }
});

app.get('/me/archives', authenticate, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT a.id, a.poem_id, a.title, a.category, a.notes, a.tags, a.source, a.created_at, a.updated_at,
        p.title AS poem_title, p.body, u.name AS author_name, u.username AS author_username
       FROM archives a
       JOIN poems p ON p.id = a.poem_id
       JOIN users u ON u.id = p.author_id
       WHERE a.user_id = $1
       ORDER BY a.updated_at DESC`,
      [req.userId],
    );
    res.json({
      archives: result.rows.map((a) => ({
        id: String(a.id),
        poem_id: String(a.poem_id),
        poem_title: a.poem_title,
        poem_body: a.body,
        author_name: a.author_name,
        author_username: a.author_username,
        archive_title: a.title,
        category: a.category ?? '',
        notes: a.notes,
        tags: a.tags,
        source: a.source,
        created_at: a.created_at,
        updated_at: a.updated_at,
      })),
    });
  } catch (error) { next(error); }
});

app.put('/archives/:id', authenticate, async (req, res, next) => {
  try {
    const { title, category = '', notes = '', tags = '' } = req.body;
    const archive = await query('SELECT user_id FROM archives WHERE id = $1', [req.params.id]);
    if (!archive.rows[0]) return res.status(404).json({ message: 'Arşiv bulunamadı.' });
    if (String(archive.rows[0].user_id) !== String(req.userId)) {
      return res.status(403).json({ message: 'Bu arşiv sizin değil.' });
    }
    const result = await query(
      `UPDATE archives SET title = $2, category = $3, notes = $4, tags = $5, updated_at = NOW()
       WHERE id = $1 RETURNING id`,
      [req.params.id, title || '', category.substring(0, 80), notes.substring(0, 5000), tags.substring(0, 200)],
    );
    const updated = await query(
      `SELECT a.id, a.poem_id, a.title, a.category, a.notes, a.tags, a.source, a.created_at, a.updated_at,
        p.title AS poem_title, p.body AS poem_body, u.name AS author_name, u.username AS author_username
       FROM archives a JOIN poems p ON p.id = a.poem_id JOIN users u ON u.id = p.author_id
       WHERE a.id = $1`,
      [result.rows[0].id],
    );
    const a = updated.rows[0];
    res.json({ archive: {
      id: String(a.id), poem_id: String(a.poem_id), poem_title: a.poem_title,
      poem_body: a.poem_body, author_name: a.author_name,
      author_username: a.author_username, archive_title: a.title,
      category: a.category ?? '',
      notes: a.notes, tags: a.tags, source: a.source,
      created_at: a.created_at, updated_at: a.updated_at,
    } });
  } catch (error) { next(error); }
});

app.delete('/archives/:id', authenticate, async (req, res, next) => {
  try {
    const archive = await query('SELECT user_id FROM archives WHERE id = $1', [req.params.id]);
    if (!archive.rows[0]) return res.status(404).json({ message: 'Arşiv bulunamadı.' });
    if (String(archive.rows[0].user_id) !== String(req.userId)) {
      return res.status(403).json({ message: 'Bu arşiv sizin değil.' });
    }
    await query('DELETE FROM archives WHERE id = $1', [req.params.id]);
    res.json({ message: 'Arşiv silindi.' });
  } catch (error) { next(error); }
});

app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ message: 'Sunucu hatası.' });
});

const port = Number(process.env.PORT ?? 3000);
migrate()
  .then(() => app.listen(port, '0.0.0.0', () => console.log(`Poetium API listening on ${port}`)))
  .catch((error) => { console.error(error); process.exit(1); });