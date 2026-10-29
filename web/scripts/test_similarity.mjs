// Vector search test cases: each complaint is worded differently from the
// stored request it should match. PASS if the expected request is in the top 3.
// Run from the web folder after "npm run embed":  npm run test:vector
import './loadEnv.mjs';
import pg from 'pg';
import { embed, toPgVector } from '../lib/embeddings.mjs';

const CASES = [
  { text: 'phone switches itself off when battery shows 20 percent', expect: [14, 17, 5] },
  { text: 'fridge is warm inside and the motor is loud',              expect: [12] },
  { text: 'coloured stripes running down the television screen',      expect: [6] },
  { text: 'laptop lid is wobbly because the hinge is broken',         expect: [13] },
  { text: 'television has picture but the speakers are silent',       expect: [8] },
  { text: 'dropped my phone and the glass on the back shattered',     expect: [4] },
  { text: 'telly will not switch on, red light flashing',             expect: [10] },
  { text: 'photos come out blurry, camera cannot focus',              expect: [15] }
];

const client = new pg.Client({
  host: process.env.PG_HOST, port: Number(process.env.PG_PORT || 5432),
  user: process.env.PG_USER, password: process.env.PG_PASSWORD, database: process.env.PG_DATABASE
});
await client.connect();

let passed = 0;
for (const [i, c] of CASES.entries()) {
  const vector = toPgVector(await embed(c.text));
  const { rows } = await client.query(
    `SELECT request_id, ROUND((1 - (embedding <=> $1::vector))::numeric, 3) AS similarity
     FROM issue_embedding ORDER BY embedding <=> $1::vector LIMIT 3`,
    [vector]
  );
  const top = rows.map((r) => r.request_id);
  const ok = c.expect.some((id) => top.includes(id));
  if (ok) passed += 1;
  console.log(`V${String(i + 1).padStart(2, '0')} ${ok ? 'PASS' : 'FAIL'}  "${c.text}"`);
  console.log(`     top 3: ${rows.map((r) => `#${r.request_id} (${r.similarity})`).join(', ')}  expected one of ${c.expect.join(', ')}`);
}
console.log(`\n${passed} of ${CASES.length} vector search tests passed`);
await client.end();
process.exit(passed === CASES.length ? 0 : 1);
