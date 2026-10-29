// Loads web/.env.local into process.env for the Node scripts (Next.js does this itself).
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const envPath = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '.env.local');

if (!existsSync(envPath)) {
  console.error('Missing web/.env.local. Copy .env.example to .env.local and fill it in.');
  process.exit(1);
}

for (const line of readFileSync(envPath, 'utf8').split('\n')) {
  const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
  if (match && process.env[match[1]] === undefined) process.env[match[1]] = match[2];
}
