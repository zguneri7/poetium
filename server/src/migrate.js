import { pool } from './db.js';

const statements = [
  `CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    username VARCHAR(40) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    avatar_url TEXT,
    email_verified_at TIMESTAMPTZ,
    password_hash TEXT,
    google_subject VARCHAR(255) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT users_auth_method CHECK (password_hash IS NOT NULL OR google_subject IS NOT NULL)
  )`,
  'ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT',
  'ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ',
  `CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `CREATE TABLE IF NOT EXISTS poems (
    id BIGSERIAL PRIMARY KEY,
    author_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(160) NOT NULL,
    body TEXT NOT NULL,
    visibility VARCHAR(24) NOT NULL DEFAULT 'public',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT poems_visibility CHECK (visibility IN ('public', 'selected'))
  )`,
  `CREATE TABLE IF NOT EXISTS poem_recipients (
    poem_id BIGINT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (poem_id, user_id)
  )`,
  `CREATE TABLE IF NOT EXISTS ratings (
    poem_id BIGINT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    duygusal_etki SMALLINT CHECK (duygusal_etki BETWEEN 1 AND 5),
    ozgunluk SMALLINT CHECK (ozgunluk BETWEEN 1 AND 5),
    imge_mecaz SMALLINT CHECK (imge_mecaz BETWEEN 1 AND 5),
    dil_sozcuk_secimi SMALLINT CHECK (dil_sozcuk_secimi BETWEEN 1 AND 5),
    ahenk_akis SMALLINT CHECK (ahenk_akis BETWEEN 1 AND 5),
    butunluk_yapi SMALLINT CHECK (butunluk_yapi BETWEEN 1 AND 5),
    siir_teknigi SMALLINT CHECK (siir_teknigi BETWEEN 1 AND 5),
    derinlik SMALLINT CHECK (derinlik BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (poem_id, user_id)
  )`,
  `ALTER TABLE ratings ADD COLUMN IF NOT EXISTS duygusal_etki SMALLINT CHECK (duygusal_etki BETWEEN 1 AND 5)`,
  `ALTER TABLE ratings ADD COLUMN IF NOT EXISTS ozgunluk SMALLINT CHECK (ozgunluk BETWEEN 1 AND 5)`,
  `ALTER TABLE ratings ADD COLUMN IF NOT EXISTS imge_mecaz SMALLINT CHECK (imge_mecaz BETWEEN 1 AND 5)`,
  `ALTER TABLE ratings ADD COLUMN IF NOT EXISTS dil_sozcuk_secimi SMALLINT CHECK (dil_sozcuk_secimi BETWEEN 1 AND 5)`,
  `ALTER TABLE ratings ADD COLUMN IF NOT EXISTS ahenk_akis SMALLINT CHECK (ahenk_akis BETWEEN 1 AND 5)`,
  `ALTER TABLE ratings ADD COLUMN IF NOT EXISTS butunluk_yapi SMALLINT CHECK (butunluk_yapi BETWEEN 1 AND 5)`,
  `ALTER TABLE ratings ADD COLUMN IF NOT EXISTS siir_teknigi SMALLINT CHECK (siir_teknigi BETWEEN 1 AND 5)`,
  `ALTER TABLE ratings ADD COLUMN IF NOT EXISTS derinlik SMALLINT CHECK (derinlik BETWEEN 1 AND 5)`,
  `DO $$
   BEGIN
     IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ratings' AND column_name = 'image') THEN
       ALTER TABLE ratings ALTER COLUMN image DROP NOT NULL;
     END IF;
     IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ratings' AND column_name = 'rhythm') THEN
       ALTER TABLE ratings ALTER COLUMN rhythm DROP NOT NULL;
     END IF;
     IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ratings' AND column_name = 'emotion') THEN
       ALTER TABLE ratings ALTER COLUMN emotion DROP NOT NULL;
     END IF;
     IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ratings' AND column_name = 'originality') THEN
       ALTER TABLE ratings ALTER COLUMN originality DROP NOT NULL;
     END IF;
   END $$`,
  `CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `CREATE TABLE IF NOT EXISTS follows (
    follower_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (follower_id, following_id),
    CONSTRAINT no_self_follow CHECK (follower_id != following_id)
  )`,
  `CREATE TABLE IF NOT EXISTS likes (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    poem_id BIGINT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, poem_id)
  )`,
  `CREATE TABLE IF NOT EXISTS comments (
    id BIGSERIAL PRIMARY KEY,
    poem_id BIGINT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_id BIGINT REFERENCES comments(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  'ALTER TABLE comments ADD COLUMN IF NOT EXISTS parent_id BIGINT REFERENCES comments(id) ON DELETE CASCADE',
  `CREATE TABLE IF NOT EXISTS archives (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    poem_id BIGINT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
    title VARCHAR(160),
    category VARCHAR(80),
    notes TEXT,
    tags VARCHAR(200),
    source VARCHAR(20) DEFAULT 'saved',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT archives_source CHECK (source IN ('saved', 'ocr'))
  )`,
  'ALTER TABLE archives ADD COLUMN IF NOT EXISTS category VARCHAR(80)',
  'CREATE UNIQUE INDEX IF NOT EXISTS archives_user_poem_unique_idx ON archives(user_id, poem_id)',
  'CREATE INDEX IF NOT EXISTS poems_created_at_idx ON poems(created_at DESC)',
  'CREATE INDEX IF NOT EXISTS poems_author_id_idx ON poems(author_id)',
  'CREATE INDEX IF NOT EXISTS comments_poem_id_idx ON comments(poem_id)',
  'CREATE INDEX IF NOT EXISTS archives_user_id_idx ON archives(user_id)',
  'CREATE INDEX IF NOT EXISTS likes_user_id_idx ON likes(user_id)',
  'CREATE INDEX IF NOT EXISTS follows_follower_id_idx ON follows(follower_id)',
];

export async function migrate() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const statement of statements) await client.query(statement);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

if (process.argv[1] === new URL(import.meta.url).pathname.replace(/^\/(.:)/, '$1')) {
  migrate()
    .then(() => console.log('Database migration completed.'))
    .finally(() => pool.end());
}