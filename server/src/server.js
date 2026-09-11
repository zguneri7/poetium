import 'dotenv/config';
import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import cors from 'cors';
import express from 'express';
import jwt from 'jsonwebtoken';
import { pool, query } from './db.js';
import { migrate } from './migrate.js';

if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET is required.');

const app = express();
app.use(cors());
app.use(express.json({ limit: '64kb' }));

function publicUser(row) {
  return { id: String(row.id), name: row.name, username: row.username, email: row.email };
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

app.post('/auth/register', async (req, res, next) => {
  try {
    const { name, username, email, password } = req.body;
    if (![name, username, email, password].every((value) => typeof value === 'string' && value.trim())) {
      return res.status(400).json({ message: 'Tüm alanları doldurun.' });
    }
    if (password.length < 6) return res.status(400).json({ message: 'Şifre en az 6 karakter olmalı.' });
    const passwordHash = await bcrypt.hash(password, 12);
    const result = await query(
      `INSERT INTO users(name, username, email, password_hash)
       VALUES ($1, LOWER($2), LOWER($3), $4) RETURNING *`,
      [name.trim(), username.trim(), email.trim(), passwordHash],
    );
    res.status(201).json({ token: issueToken(result.rows[0]), user: publicUser(result.rows[0]) });
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
    res.json({ token: issueToken(user), user: publicUser(user) });
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

  app.get('/users', authenticate, async (req, res, next) => {
    try {
      const result = await query(
        'SELECT id, name, username FROM users WHERE id <> $1 ORDER BY name LIMIT 100',
        [req.userId],
      );
      res.json({ users: result.rows.map((user) => ({ ...user, id: String(user.id) })) });
    } catch (error) { next(error); }
  });

app.get('/poems', authenticate, async (req, res, next) => {
  try {
    const result = await query(poemSelect(`WHERE p.visibility = 'public' OR p.author_id = $1 OR EXISTS (
      SELECT 1 FROM poem_recipients pr WHERE pr.poem_id = p.id AND pr.user_id = $1
    )`), [req.userId]);
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
    if (!title?.trim() || !body?.trim() || !['public', 'selected'].includes(visibility)) {
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

app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ message: 'Sunucu hatası.' });
});

const port = Number(process.env.PORT ?? 3000);
migrate()
  .then(() => app.listen(port, '0.0.0.0', () => console.log(`Poetium API listening on ${port}`)))
  .catch((error) => { console.error(error); process.exit(1); });