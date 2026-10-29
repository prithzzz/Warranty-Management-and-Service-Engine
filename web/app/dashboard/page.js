'use client';
import { useEffect, useState } from 'react';
import DataTable from '@/components/DataTable';
import { api, formatMoney } from '@/lib/apiClient';

function Bars({ rows, labelKey, valueKey }) {
  const max = Math.max(...rows.map((r) => Number(r[valueKey])), 1);
  return (
    <div className="card">
      {rows.map((r) => (
        <div className="bar-row" key={r[labelKey]}>
          <span>{r[labelKey]}</span>
          <div className="bar" style={{ width: `${(Number(r[valueKey]) / max) * 100}%` }} />
          <span className="small">{formatMoney(r[valueKey])}</span>
        </div>
      ))}
    </div>
  );
}

export default function DashboardPage() {
  const [d, setD] = useState(null);
  useEffect(() => { api('/api/dashboard').then(setD); }, []);
  if (!d) return <p className="muted">Loading...</p>;

  const t = d.totals;
  const stats = [
    ['Customers', t.customers], ['Units sold', t.units_sold], ['Revenue', formatMoney(t.revenue)],
    ['Active warranties', t.active_warranties], ['Expiring in 30 days', t.expiring_soon], ['Open recalls', t.open_recalls]
  ];

  return (
    <>
      <h1>Sales and warranty dashboard</h1>
      <div className="stats">
        {stats.map(([label, value]) => (
          <div className="card stat" key={label}><div className="muted small">{label}</div><div className="value">{value}</div></div>
        ))}
      </div>

      <h2>Revenue by brand</h2>
      <Bars rows={d.byBrand} labelKey="brand" valueKey="revenue" />

      <h2>Monthly revenue (last 12 months with sales)</h2>
      <Bars rows={d.monthly} labelKey="month" valueKey="revenue" />

      <h2>Warranties ending in the next 120 days</h2>
      <DataTable
        rows={d.expiring}
        columns={[
          { key: 'customer_name', label: 'Customer' },
          { key: 'serial_no', label: 'Serial number' },
          { key: 'model_name', label: 'Model' },
          { key: 'plan_code', label: 'Plan' },
          { key: 'end_date', label: 'Ends on' },
          { key: 'days_left', label: 'Days left' }
        ]}
      />
    </>
  );
}
