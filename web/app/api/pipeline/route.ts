import { NextResponse } from "next/server";
import { backendBase } from "@/lib/backend";

export async function GET() {
  try {
    const res = await fetch(`${backendBase()}/v1/pipeline`, { cache: "no-store" });
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
