import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';

// GET /api/recalls/:id : every unit in the recall scope with its owner and notice status
export async function GET(request, { params }) {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF']);
  if (auth.error) return auth.error;

  const recall = await query('SELECT * FROM recall_campaign WHERE recall_id = ?', [Number(params.id)]);
  if (!recall[0]) return NextResponse.json({ error: 'Recall not found' }, { status: 404 });

  const units = await query(
    `SELECT serial_no, model_name, manufacture_date, unit_status, owner_name, owner_email, notification_status
     FROM v_recall_affected_units WHERE recall_code = ? ORDER BY serial_no`,
    [recall[0].recall_code]
  );
  return NextResponse.json({ recall: recall[0], units });
}
