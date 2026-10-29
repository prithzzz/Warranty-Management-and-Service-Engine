import { NextResponse } from 'next/server';
import { callProcedure, dbErrorMessage } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';
import { loadRequestForUser } from '@/lib/access';

const TYPES = ['REPAIR', 'REPLACEMENT', 'REFUND'];

// POST /api/service-requests/:id/claim { claim_type } : file a warranty claim (sp_file_warranty_claim)
export async function POST(request, { params }) {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF']);
  if (auth.error) return auth.error;
  const id = Number(params.id);
  if (!(await loadRequestForUser(id, auth.user))) {
    return NextResponse.json({ error: 'Request not found' }, { status: 404 });
  }
  const { claim_type } = await request.json().catch(() => ({}));
  if (!TYPES.includes(claim_type)) {
    return NextResponse.json({ error: 'Claim type must be REPAIR, REPLACEMENT or REFUND' }, { status: 400 });
  }
  try {
    const out = await callProcedure('sp_file_warranty_claim', [id, claim_type], ['claim_id']);
    return NextResponse.json({ claim_id: out.claim_id }, { status: 201 });
  } catch (err) {
    return NextResponse.json({ error: dbErrorMessage(err) }, { status: 400 });
  }
}
