'use client';
import { useEffect, useState } from 'react';
import DataTable from '@/components/DataTable';
import { api, formatMoney } from '@/lib/apiClient';

export default function NewSalePage() {
  const [customers, setCustomers] = useState([]);
  const [catalog, setCatalog] = useState({ units: [], plans: [] });
  const [sales, setSales] = useState([]);
  const [form, setForm] = useState({ customer_id: '', invoice_no: '', serial_no: '', plan_code: 'STD12', channel: 'RETAIL_STORE', price: '' });
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(false);

  async function load() {
    const [c, cat, s] = await Promise.all([api('/api/customers?q='), api('/api/catalog'), api('/api/sales')]);
    setCustomers(c.customers);
    setCatalog(cat);
    setSales(s.sales);
  }
  useEffect(() => { load(); }, []);

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  function pickUnit(e) {
    const unit = catalog.units.find((u) => u.serial_no === e.target.value);
    setForm({ ...form, serial_no: e.target.value, price: unit ? unit.mrp : '' });
  }

  async function submit(e) {
    e.preventDefault();
    setMsg(null);
    setBusy(true);
    try {
      const res = await api('/api/sales', { method: 'POST', body: form });
      setMsg({ ok: true, text: `Sale saved as purchase #${res.purchase_id}. The unit is now sold and its warranty is active.` });
      setForm({ ...form, invoice_no: '', serial_no: '', price: '' });
      load();
    } catch (err) {
      // trigger messages such as "Unit is under an active recall" arrive here
      setMsg({ ok: false, text: err.message });
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <h1>Register a sale</h1>
      <p className="muted">Creates the invoice, sells the unit and starts its warranty in one database transaction.</p>

      <form className="card stack" onSubmit={submit} style={{ marginTop: 16 }}>
        <label>Customer
          <select value={form.customer_id} onChange={set('customer_id')} required>
            <option value="">Choose a customer</option>
            {customers.map((c) => <option key={c.customer_id} value={c.customer_id}>{c.full_name} ({c.email})</option>)}
          </select>
        </label>
        <label>Invoice number<input value={form.invoice_no} onChange={set('invoice_no')} placeholder="INV-2026-0100" required /></label>
        <label>Unit in stock
          <select value={form.serial_no} onChange={pickUnit} required>
            <option value="">Choose a unit</option>
            {catalog.units.map((u) => (
              <option key={u.serial_no} value={u.serial_no}>
                {u.serial_no}: {u.brand} {u.model_name}{u.active_recall ? ` (under recall ${u.active_recall})` : ''}
              </option>
            ))}
          </select>
        </label>
        <label>Warranty plan
          <select value={form.plan_code} onChange={set('plan_code')}>
            {catalog.plans.map((p) => (
              <option key={p.plan_code} value={p.plan_code}>
                {p.plan_name} ({p.duration_months} months, {formatMoney(p.price)})
              </option>
            ))}
          </select>
        </label>
        <label>Channel
          <select value={form.channel} onChange={set('channel')}>
            <option value="RETAIL_STORE">Retail store</option>
            <option value="ONLINE">Online</option>
            <option value="DEALER">Dealer</option>
          </select>
        </label>
        <label>Selling price (Rs)<input type="number" min="1" step="0.01" value={form.price} onChange={set('price')} required /></label>
        {msg && <p className={msg.ok ? 'success' : 'error'}>{msg.text}</p>}
        <button disabled={busy}>{busy ? 'Saving...' : 'Register sale'}</button>
      </form>

      <h2>Recent sales</h2>
      <DataTable
        rows={sales}
        columns={[
          { key: 'invoice_no', label: 'Invoice' },
          { key: 'purchase_date', label: 'Date' },
          { key: 'customer_name', label: 'Customer' },
          { key: 'units', label: 'Units' },
          { key: 'channel', label: 'Channel' },
          { key: 'total_amount', label: 'Total', render: (r) => formatMoney(r.total_amount) }
        ]}
      />
    </>
  );
}
