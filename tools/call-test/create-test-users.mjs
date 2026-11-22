import pg from "pg";
import bcrypt from "bcryptjs";

const passwordHash = bcrypt.hashSync("CallTest#2026", 10);

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

async function upsert(email, fullName, username) {
  const existing = await pool.query(
    "SELECT id FROM users WHERE lower(email) = lower($1)",
    [email],
  );
  if (existing.rows.length > 0) return existing.rows[0].id;
  const inserted = await pool.query(
    `INSERT INTO users (full_name, email, username, password_hash, auth_provider, birth_date, interest)
     VALUES ($1, $2, $3, $4, 'local', '2000-01-01', 'Music')
     RETURNING id`,
    [fullName, email, username, passwordHash],
  );
  return inserted.rows[0].id;
}

const a = await upsert("calltest.a@test.local", "Call Tester A", "calltest_a");
const b = await upsert("calltest.b@test.local", "Call Tester B", "calltest_b");
const c = await upsert("calltest.c@test.local", "Call Tester C", "calltest_c");
const d = await upsert("calltest.d@test.local", "Call Tester D", "calltest_d");

console.log(JSON.stringify({ a, b, c, d }));
await pool.end();
