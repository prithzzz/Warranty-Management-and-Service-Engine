// Coloured label for status values (ACTIVE, EXPIRED, OPEN, SETTLED, ...)
const TONES = {
  good: ['ACTIVE', 'COMPLETED', 'CLOSED', 'SETTLED', 'RESOLVED', 'APPROVED', 'SOLD', 'PASS'],
  warn: ['EXPIRING_SOON', 'ASSIGNED', 'IN_PROGRESS', 'SUBMITTED', 'PENDING', 'SENT', 'ACKNOWLEDGED', 'ANNOUNCED', 'MEDIUM', 'HIGH'],
  bad:  ['EXPIRED', 'VOID', 'REJECTED', 'CANCELLED', 'URGENT', 'CRITICAL', 'REPLACED', 'OPEN']
};

export default function StatusBadge({ value }) {
  if (!value) return null;
  const tone = Object.keys(TONES).find((t) => TONES[t].includes(value)) || 'neutral';
  return <span className={`badge badge-${tone}`}>{String(value).replace(/_/g, ' ')}</span>;
}
