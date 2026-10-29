import { NextResponse } from 'next/server';
import { callProcedure, dbErrorMessage } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

// POST /api/recalls/:id/notify : queue notifications for every owner in scope (admin only)
export async function POST(request, { params }) {
  const auth = await requireRole(['ADMIN']);
  if (auth.error) return auth.error;
  try {
    const out = await callProcedure('sp_generate_recall_notifications', [Number(params.id)], ['created']);
    return NextResponse.json({ created: out.created });
  } catch (err) {
    return NextResponse.json({ error: dbErrorMessage(err) }, { status: 400 });
  }
}
