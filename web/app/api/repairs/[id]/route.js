import { NextResponse } from 'next/server';
import { query, callProcedure, dbErrorMessage } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';
import { syncRequestEmbedding } from '@/lib/similarity';

// POST /api/repairs/:id
//   { action: 'start' }
//   { action: 'add_part', part_code, quantity }      stock is checked and reduced by triggers
//   { action: 'remove_part', part_code }             stock is restored by trigger
//   { action: 'complete', labour_charge, notes }     sp_complete_repair, then claim settles by trigger
export async function POST(request, { params }) {
  const auth = await requireRole(['TECHNICIAN', 'ADMIN']);
  if (auth.error) return auth.error;
  const user = auth.user;
  const id = Number(params.id);

  const [repair] = await query('SELECT repair_id, request_id, technician_id, status FROM repair WHERE repair_id = ?', [id]);
  if (!repair || (user.role === 'TECHNICIAN' && repair.technician_id !== user.technicianId)) {
    return NextResponse.json({ error: 'Repair not found' }, { status: 404 });
  }

  const b = await request.json().catch(() => ({}));
  try {
    if (b.action === 'start') {
      if (repair.status !== 'ASSIGNED') return NextResponse.json({ error: 'Only an assigned repair can be started' }, { status: 400 });
      await query("UPDATE repair SET status = 'IN_PROGRESS' WHERE repair_id = ?", [id]);
    } else if (b.action === 'add_part') {
      const qty = Number(b.quantity);
      if (!b.part_code || !(qty > 0)) return NextResponse.json({ error: 'Choose a part and a quantity above 0' }, { status: 400 });
      // look up the id first: the stock trigger updates spare_part, so the INSERT must not read it
      const [part] = await query('SELECT part_id FROM spare_part WHERE part_code = ?', [b.part_code]);
      if (!part) return NextResponse.json({ error: 'Unknown part' }, { status: 400 });
      await query('INSERT INTO repair_part (repair_id, part_id, quantity, unit_price) VALUES (?, ?, ?, NULL)', [id, part.part_id, qty]);
    } else if (b.action === 'remove_part') {
      if (repair.status === 'COMPLETED') return NextResponse.json({ error: 'Repair already completed' }, { status: 400 });
      const [part] = await query('SELECT part_id FROM spare_part WHERE part_code = ?', [b.part_code]);
      if (!part) return NextResponse.json({ error: 'Unknown part' }, { status: 400 });
      await query('DELETE FROM repair_part WHERE repair_id = ? AND part_id = ?', [id, part.part_id]);
    } else if (b.action === 'complete') {
      const labour = Number(b.labour_charge || 0);
      if (labour < 0) return NextResponse.json({ error: 'Labour charge cannot be negative' }, { status: 400 });
      await callProcedure('sp_complete_repair', [id, labour, b.notes || null]);
      // re-embed so future searches also see how this problem was fixed
      await syncRequestEmbedding(repair.request_id);
    } else {
      return NextResponse.json({ error: 'Unknown action' }, { status: 400 });
    }
    return NextResponse.json({ ok: true });
  } catch (err) {
    return NextResponse.json({ error: dbErrorMessage(err) }, { status: 400 });
  }
}
