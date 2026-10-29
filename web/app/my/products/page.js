'use client';
import { useEffect, useState } from 'react';
import DataTable from '@/components/DataTable';
import StatusBadge from '@/components/StatusBadge';
import { api } from '@/lib/apiClient';

export default function MyProductsPage() {
  const [data, setData] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    api('/api/my/products').then(setData).catch((e) => setError(e.message));
  }, []);

  if (error) return <p className="error">{error}</p>;
  if (!data) return <p className="muted">Loading...</p>;

  return (
    <>
      <h1>My products</h1>
      {data.units.filter((u) => u.recall_code).map((u) => (
        <p key={u.serial_no} className="error">
          Your {u.model_name} ({u.serial_no}) is under recall {u.recall_code}: {u.recall_title}. Please raise a service request.
        </p>
      ))}
      <DataTable
        rows={data.units}
        columns={[
          { key: 'serial_no', label: 'Serial number' },
          { key: 'model', label: 'Product', render: (r) => `${r.brand} ${r.model_name}` },
          { key: 'status', label: 'Status', render: (r) => <StatusBadge value={r.status} /> },
          { key: 'covered_today', label: 'Covered today', render: (r) => (r.covered_today ? 'Yes' : 'No') }
        ]}
      />

      <h2>My warranties</h2>
      <DataTable
        rows={data.warranties}
        columns={[
          { key: 'serial_no', label: 'Serial number' },
          { key: 'model_name', label: 'Model' },
          { key: 'plan_code', label: 'Plan' },
          { key: 'end_date', label: 'Ends on' },
          { key: 'live_status', label: 'Status', render: (r) => <StatusBadge value={r.live_status} /> },
          { key: 'days_left', label: 'Days left' }
        ]}
      />

      <h2>Recall notices</h2>
      <DataTable
        rows={data.notices}
        empty="No recall notices"
        columns={[
          { key: 'recall_code', label: 'Recall' },
          { key: 'title', label: 'Title' },
          { key: 'serial_no', label: 'Unit' },
          { key: 'remedy', label: 'Remedy' },
          { key: 'status', label: 'Status', render: (r) => <StatusBadge value={r.status} /> }
        ]}
      />
    </>
  );
}
