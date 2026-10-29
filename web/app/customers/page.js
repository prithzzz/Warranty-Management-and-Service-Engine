'use client';
import { useEffect, useState } from 'react';
import DataTable from '@/components/DataTable';
import { api, formatMoney } from '@/lib/apiClient';

const EMPTY = { full_name: '', email: '', phone: '', address: '', city: '', preferred_channel: 'EMAIL' };

export default function CustomersPage() {
  const [q, setQ] = useState('');
  const [rows, setRows] = useState([]);
  const [form, setForm] = useState(EMPTY);
  const [msg, setMsg] = useState(null);

  async function load(search = q) {
    const data = await api('/api/customers?q=' + encodeURIComponent(search));
    setRows(data.customers);
  }
  useEffect(() => { load(''); }, []);

  async function addCustomer(e) {
    e.preventDefault();
    setMsg(null);
    try {
      await api('/api/customers', { method: 'POST', body: form });
      setMsg({ ok: true, text: `Customer ${form.full_name} added` });
      setForm(EMPTY);
      load();
    } catch (err) {
      setMsg({ ok: false, text: err.message });
    }
  }

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  return (
    <>
      <h1>Customers</h1>
      <form className="row" onSubmit={(e) => { e.preventDefault(); load(); }} style={{ margin: '16px 0' }}>
        <label>Search name, email or phone<input value={q} onChange={(e) => setQ(e.target.value)} /></label>
        <button>Search</button>
      </form>
      <DataTable
        rows={rows}
        columns={[
          { key: 'full_name', label: 'Name' },
          { key: 'email', label: 'Email' },
          { key: 'phone', label: 'Phone' },
          { key: 'city', label: 'City' },
          { key: 'purchases', label: 'Invoices' },
          { key: 'lifetime_spend', label: 'Lifetime spend', render: (r) => formatMoney(r.lifetime_spend) },
          { key: 'registered_on', label: 'Registered' }
        ]}
      />

      <h2>Add a customer</h2>
      <form className="card stack" onSubmit={addCustomer}>
        <label>Full name<input value={form.full_name} onChange={set('full_name')} required /></label>
        <label>Email<input type="email" value={form.email} onChange={set('email')} required /></label>
        <label>Phone (10 digits, starts with 6-9)<input value={form.phone} onChange={set('phone')} required /></label>
        <label>Address<input value={form.address} onChange={set('address')} /></label>
        <label>City<input value={form.city} onChange={set('city')} required /></label>
        <label>Preferred alert channel
          <select value={form.preferred_channel} onChange={set('preferred_channel')}>
            <option>EMAIL</option><option>SMS</option><option>APP</option>
          </select>
        </label>
        {msg && <p className={msg.ok ? 'success' : 'error'}>{msg.text}</p>}
        <button>Add customer</button>
      </form>
    </>
  );
}
