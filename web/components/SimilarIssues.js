'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { api, formatMoney } from '@/lib/apiClient';

// Shows the past requests most similar to a request (pgvector cosine search)
export default function SimilarIssues({ requestId }) {
  const [matches, setMatches] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    api('/api/similar?request_id=' + requestId)
      .then((d) => setMatches(d.matches))
      .catch((e) => setError(e.message));
  }, [requestId]);

  if (error) return <p className="error">{error}</p>;
  if (!matches) return <p className="muted">Searching past repairs...</p>;
  if (matches.length === 0) return <p className="muted">No similar past requests yet.</p>;

  return (
    <div className="grid">
      {matches.map((m) => (
        <div className="card" key={m.request_id}>
          <div className="spread">
            <strong><Link href={`/service/${m.request_id}`}>Request #{m.request_id}</Link></strong>
            <span className="badge badge-neutral">{Math.round(m.similarity * 100)}% match</span>
          </div>
          <p className="small muted">{m.model_name} · {m.issue_type.replace(/_/g, ' ').toLowerCase()} · {m.request_date}</p>
          <p className="small">{m.issue_text}</p>
          {m.resolution_text
            ? <p className="small"><strong>Fix:</strong> {m.resolution_text}</p>
            : <p className="small muted">Not repaired yet</p>}
          {m.parts_used && <p className="small muted">Parts: {m.parts_used}</p>}
          {m.repair_cost != null && <p className="small muted">Cost: {formatMoney(m.repair_cost)} by {m.technician}</p>}
        </div>
      ))}
    </div>
  );
}
