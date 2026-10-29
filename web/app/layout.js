import './globals.css';
import Nav from '@/components/Nav';

export const metadata = {
  title: 'Warranty Management and Service Engine',
  description: 'Warranty, recall and service tracking for serial-numbered products'
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <Nav />
        <main className="container">{children}</main>
      </body>
    </html>
  );
}
