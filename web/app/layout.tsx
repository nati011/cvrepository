import type { Metadata } from "next";
import { GeistMono } from "geist/font/mono";
import { AppShell } from "@/components/AppShell";
import { BRAND_URL } from "@/lib/brand";
import { Providers } from "./providers";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "CV repository", template: "%s | CV repository" },
  description: "Upload, index, and search CV PDFs",
  authors: [{ name: "Kifiya", url: BRAND_URL }],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${GeistMono.variable} font-sans antialiased bg-brand-light text-brand-dark dark:bg-brand-dark dark:text-brand-light`}
      >
        <Providers>
          <AppShell>{children}</AppShell>
        </Providers>
      </body>
    </html>
  );
}
