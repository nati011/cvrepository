import { NextResponse } from "next/server";
import { backendBase } from "@/lib/backend";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(_: Request, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    const res = await fetch(`${backendBase()}/v1/jobs/${encodeURIComponent(id)}/rank`, {
      method: "POST",
    });
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

export async function GET(_: Request, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    const res = await fetch(`${backendBase()}/v1/jobs/${encodeURIComponent(id)}/rank`, {
      cache: "no-store",
    });
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
