// Runs before every page and API request: no valid session means no access.
import { NextResponse } from 'next/server';
import { SESSION_COOKIE, PAGE_ROLES, readSessionToken } from './lib/session';

const PUBLIC_PATHS = ['/login', '/api/auth/login'];

export async function middleware(request) {
  const { pathname } = request.nextUrl;
  if (PUBLIC_PATHS.includes(pathname)) return NextResponse.next();

  const user = await readSessionToken(request.cookies.get(SESSION_COOKIE)?.value);

  if (!user) {
    if (pathname.startsWith('/api/')) {
      return NextResponse.json({ error: 'Please log in' }, { status: 401 });
    }
    const url = new URL('/login', request.url);
    url.searchParams.set('next', pathname);
    return NextResponse.redirect(url);
  }

  // page-level role check (API routes check roles themselves)
  if (!pathname.startsWith('/api/')) {
    const rule = PAGE_ROLES.find((r) => pathname === r.prefix || pathname.startsWith(r.prefix + '/'));
    if (rule && !rule.roles.includes(user.role)) {
      return NextResponse.redirect(new URL('/', request.url));
    }
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)']
};
