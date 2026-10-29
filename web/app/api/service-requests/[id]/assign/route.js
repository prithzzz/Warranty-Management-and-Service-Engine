import { NextResponse } from 'next/server';
import { callProcedure, query, dbErrorMessage } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';
import { loadRequestForUser } from '@/lib/access';

// POST /api/service-requests/:id/assign : auto-pick the best technician (sp_assign_technician)
export async function POST(request, { params }) {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF']);
  if (auth.error) return auth.error;
  const id = Number(params.id);
  if (!(await loadRequestForUser(id, auth.user))) {
    return NextResponse.json({ error: 'Request not found' }, { status: 404 });
  }
  try {
    const out = await callProcedure('sp_assign_technician', [id], ['technician_id']);
    const [tech] = await query('SELECT full_name FROM technician WHERE technician_id = ?', [out.technician_id]);
    return NextResponse.json({ technician_id: out.technician_id, technician: tech?.full_name });
  } catch (err) {
    return NextResponse.json({ error: dbErrorMessage(err) }, { status: 400 });
  }
}
