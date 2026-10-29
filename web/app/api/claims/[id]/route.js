import { NextResponse } from 'next/server';
import { query, callProcedure, dbErrorMessage } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

// POST /api/claims/:id
//   { action: 'approve' }
//   { action: 'reject', remarks }
//   { action: 'replace', new_serial_no }   sp_process_replacement (multi-table transaction)
// Allowed status changes are enforced by trigger trg_claim_bu.
export async function POST(request, { params }) {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF']);
  if (auth.error) return auth.error;
  const user = auth.user;
  const id = Number(params.id);

  const [claim] = await query(
    `SELECT wc.claim_id, sr.center_id FROM warranty_claim wc
     JOIN service_request sr ON sr.request_id = wc.request_id WHERE wc.claim_id = ?`,
    [id]
  );
  if (!claim || (user.role === 'SERVICE_STAFF' && claim.center_id !== user.centerId)) {
    return NextResponse.json({ error: 'Claim not found' }, { status: 404 });
  }

  const b = await request.json().catch(() => ({}));
  try {
    if (b.action === 'approve') {
      await query("UPDATE warranty_claim SET status = 'APPROVED' WHERE claim_id = ?", [id]);
    } else if (b.action === 'reject') {
      if (!b.remarks) return NextResponse.json({ error: 'Give a reason for rejecting' }, { status: 400 });
      await query("UPDATE warranty_claim SET status = 'REJECTED', remarks = ? WHERE claim_id = ?", [b.remarks, id]);
    } else if (b.action === 'replace') {
      if (!b.new_serial_no) return NextResponse.json({ error: 'Enter the replacement serial number' }, { status: 400 });
      await callProcedure('sp_process_replacement', [id, b.new_serial_no.trim()]);
    } else {
      return NextResponse.json({ error: 'Unknown action' }, { status: 400 });
    }
    return NextResponse.json({ ok: true });
  } catch (err) {
    return NextResponse.json({ error: dbErrorMessage(err) }, { status: 400 });
  }
}
