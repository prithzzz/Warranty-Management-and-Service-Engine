import { NextResponse } from 'next/server';
import { requireRole } from '@/lib/auth';
import { findSimilar } from '@/lib/similarity';

export const dynamic = 'force-dynamic';

// GET /api/similar?request_id=12
// GET /api/similar?text=phone+shuts+down&category=SMARTPHONE
export async function GET(request) {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF', 'TECHNICIAN']);
  if (auth.error) return auth.error;

  const p = new URL(request.url).searchParams;
  const requestId = p.get('request_id') ? Number(p.get('request_id')) : null;
  const text = (p.get('text') || '').trim();
  const category = p.get('category') || null;
  if (!requestId && text.length < 5) {
    return NextResponse.json({ error: 'Give a request_id or at least 5 characters of text' }, { status: 400 });
  }
  try {
    const matches = await findSimilar({ requestId, text, category, limit: 5 });
    return NextResponse.json({ matches });
  } catch (err) {
    return NextResponse.json({ error: 'Similarity search failed: ' + err.message }, { status: 500 });
  }
}
