'use client';
import { useEffect, useState } from 'react';
import DataTable from '@/components/DataTable';
import { api, formatMoney } from '@/lib/apiClient';

export default function PartsPage() {
  const [parts, setParts] = useState([]);
  const [role, setRole] = useState(null);
  const [form, setForm] = useState({ part_code: '', quantity: 5 });
  const [msg, setMsg] = useState(null);

  async function load() { setParts((await api('/api/parts')).parts); }
  useEffect(() => {
    load();
    api('/api/auth/me').then((d) => setRole(d.user.role));
  }, []);

  async function restock(e) {
    e.preventDefault();
    setMsg(null);
    try {
      await api('/api/parts', { method: 'POST', body: { part_code: form.part_code, quantity: Number(form.quantity) } });
      setMsg({ ok: true, text: 'Stock updated' });
      load();
    } catch (err) {
      setMsg({ ok: false, text: err.message });
    }
  }

  const low = parts.filter((p) => p.needs_reorder);

  return (
    <>
      <h1>Spare parts</h1>
      {low.length > 0 && <p className="error">{low.length} part(s) at or below reorder level: {low.map((p) => p.part_name).join(', ')}</p>}
      <DataTable
        rows={parts}
        columns={[
          { key: 'part_code', label: 'Code' },
          { key: 'part_name', label: 'Part' },
          { key: 'part_category', label: 'Category' },
          { key: 'unit_price', label: 'Price', render: (p) => formatMoney(p.unit_price) },
          { key: 'stock_qty', label: 'In stock' },
          { key: 'reorder_level', label: 'Reorder at' },
          { key: 'units_used', label: 'Used so far' },
          { key: 'needs_reorder', label: '', render: (p) => (p.needs_reorder ? <span className="badge badge-bad">REORDER</span> : '') }
        ]}
      />
      {role === 'ADMIN' && (
        <>
          <h2>Record a delivery</h2>
          <form className="row" onSubmit={restock}>
            <label>Part
              <select value={form.part_code} onChange={(e) => setForm({ ...form, part_code: e.target.value })} required>
                <option value="">Choose part</option>
                {parts.map((p) => <option key={p.part_code} value={p.part_code}>{p.part_name}</option>)}
              </select>
            </label>
            <label>Quantity received<input type="number" min="1" value={form.quantity} onChange={(e) => setForm({ ...form, quantity: e.target.value })} /></label>
            <button>Add stock</button>
          </form>
          {msg && <p className={msg.ok ? 'success' : 'error'} style={{ marginTop: 10 }}>{msg.text}</p>}
        </>
      )}
    </>
  );
}
