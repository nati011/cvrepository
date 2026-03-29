import { NextRequest, NextResponse } from "next/server";
import { backendBase } from "@/lib/backend";

export async function GET(req: NextRequest) {
  try {
    const qs = new URL(req.url).searchParams.toString();
    const url = `${backendBase()}/v1/search${qs ? `?${qs}` : ""}`;
    const res = await fetch(url, { cache: "no-store" });
    const text = await res.text();
    return new NextResponse(text, {
      status: res.status,
      headers: { "Content-Type": "application/json; charset=utf-8" },
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "proxy error";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
