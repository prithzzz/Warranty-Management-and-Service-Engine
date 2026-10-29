// Signed session tokens (JWT, HS256). Edge-safe: used by middleware and API routes.
import { SignJWT, jwtVerify } from 'jose';

export const SESSION_COOKIE = 'wme_session';
const SESSION_HOURS = 8;

function secretKey() {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 16) throw new Error('JWT_SECRET must be set in .env.local (16+ characters)');
  return new TextEncoder().encode(secret);
}

export async function createSessionToken(user) {
  return new SignJWT({
    uid: user.user_id,
    username: user.username,
    role: user.role,
    customerId: user.customer_id,
    technicianId: user.technician_id,
    centerId: user.center_id
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(`${SESSION_HOURS}h`)
    .sign(secretKey());
}

export async function readSessionToken(token) {
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, secretKey());
    return payload;
  } catch {
    return null;   // expired or tampered
  }
}

export const sessionCookieOptions = {
  httpOnly: true,
  sameSite: 'lax',
  secure: process.env.NODE_ENV === 'production',
  path: '/',
  maxAge: SESSION_HOURS * 60 * 60
};

// Which roles may open which pages (checked in middleware.js)
export const PAGE_ROLES = [
  { prefix: '/customers',  roles: ['ADMIN', 'SERVICE_STAFF'] },
  { prefix: '/sales',      roles: ['ADMIN', 'SERVICE_STAFF'] },
  { prefix: '/recalls',    roles: ['ADMIN', 'SERVICE_STAFF'] },
  { prefix: '/dashboard',  roles: ['ADMIN', 'SERVICE_STAFF'] },
  { prefix: '/claims',     roles: ['ADMIN', 'SERVICE_STAFF'] },
  { prefix: '/service',    roles: ['ADMIN', 'SERVICE_STAFF', 'TECHNICIAN'] },
  { prefix: '/parts',      roles: ['ADMIN', 'SERVICE_STAFF', 'TECHNICIAN'] },
  { prefix: '/technician', roles: ['ADMIN', 'TECHNICIAN'] },
  { prefix: '/my',         roles: ['CUSTOMER'] },
  { prefix: '/warranty',   roles: ['ADMIN', 'SERVICE_STAFF', 'TECHNICIAN', 'CUSTOMER'] }
];
