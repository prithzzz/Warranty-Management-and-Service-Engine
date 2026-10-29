'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import StatusBadge from '@/components/StatusBadge';
import { api, formatMoney } from '@/lib/apiClient';

function JobCard({ job, parts, onDone }) {
  const [partCode, setPartCode] = useState('');
  const [qty, setQty] = useState(1);
  const [labour, setLabour] = useState('');
  const [notes, setNotes] = useState('');
  const [msg, setMsg] = useState(null);
  const open = job.status === 'ASSIGNED' || job.status === 'IN_PROGRESS';

  async function act(body, success) {
    setMsg(null);
    try {
      await api(`/api/repairs/${job.repair_id}`, { method: 'POST', body });
      setMsg({ ok: true, text: success });
      onDone();
    } catch (err) {
      setMsg({ ok: false, text: err.message });
    }
  }

  return (
    <div className="card">
      <div className="spread">
        <strong><Link href={`/service/${job.request_id}`}>Request #{job.request_id}</Link> · {job.model_name}</strong>
        <span className="row"><StatusBadge value={job.priority} /><StatusBadge value={job.status} /></span>
      </div>
      <p className="small">{job.issue_description}</p>
      <p className="small muted">Parts: {job.parts_used || 'none'} · Cost so far: {formatMoney(job.total_cost)}</p>
      {msg && <p className={msg.ok ? 'success small' : 'error small'}>{msg.text}</p>}

      {job.status === 'ASSIGNED' && <button onClick={() => act({ action: 'start' }, 'Repair started')}>Start repair</button>}

      {open && (
        <>
          <div className="row" style={{ marginTop: 10 }}>
            <label>Part
              <select value={partCode} onChange={(e) => setPartCode(e.target.value)}>
                <option value="">Choose part</option>
                {parts.map((p) => <option key={p.part_code} value={p.part_code}>{p.part_name} ({p.stock_qty} left)</option>)}
              </select>
            </label>
            <label>Qty<input type="number" min="1" value={qty} onChange={(e) => setQty(e.target.value)} style={{ minWidth: 70, width: 70 }} /></label>
            <button className="secondary" onClick={() => act({ action: 'add_part', part_code: partCode, quantity: qty }, 'Part added')}>Add part</button>
          </div>
          <div className="row" style={{ marginTop: 10 }}>
            <label>Labour (Rs)<input type="number" min="0" value={labour} onChange={(e) => setLabour(e.target.value)} /></label>
            <label style={{ flex: 1 }}>Resolution notes<input value={notes} onChange={(e) => setNotes(e.target.value)} /></label>
            <button onClick={() => act({ action: 'complete', labour_charge: labour || 0, notes }, 'Repair completed')}>Complete</button>
          </div>
        </>
      )}
    </div>
  );
}

export default function TechnicianPage() {
  const [jobs, setJobs] = useState(null);
  const [parts, setParts] = useState([]);

  async function load() {
    const [j, p] = await Promise.all([api('/api/repairs'), api('/api/parts')]);
    setJobs(j.repairs);
    setParts(p.parts.filter((x) => x.stock_qty > 0));
  }
  useEffect(() => { load(); }, []);

  if (!jobs) return <p className="muted">Loading...</p>;
  const open = jobs.filter((j) => j.status === 'ASSIGNED' || j.status === 'IN_PROGRESS');
  const done = jobs.filter((j) => !(j.status === 'ASSIGNED' || j.status === 'IN_PROGRESS'));

  return (
    <>
      <h1>Technician jobs</h1>
      <h2>Open ({open.length})</h2>
      {open.length === 0 ? <p className="muted">No open jobs</p> : (
        <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(420px, 1fr))' }}>
          {open.map((j) => <JobCard key={j.repair_id} job={j} parts={parts} onDone={load} />)}
        </div>
      )}
      <h2>Finished ({done.length})</h2>
      <div className="grid">
        {done.map((j) => <JobCard key={j.repair_id} job={j} parts={parts} onDone={load} />)}
      </div>
    </>
  );
}
