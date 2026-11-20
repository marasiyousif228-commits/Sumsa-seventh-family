import "./globals.css";
import type { Metadata } from "next";
export const metadata: Metadata = { title:"نظام إدارة أسرة الدفعة السابعة | SUMSA", description:"منصة إدارة ومتابعة أعمال أسرة الدفعة السابعة" };
export default function RootLayout({children}:{children:React.ReactNode}) {
  return <html lang="ar" dir="rtl"><body>{children}</body></html>;
}

