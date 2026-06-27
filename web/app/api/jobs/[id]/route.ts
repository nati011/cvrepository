import { NextRequest, NextResponse } from "next/server";
import { backendBase } from "@/lib/backend";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(req: NextRequest, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    const qs = new URL(req.url).searchParams.toString();
    const url = `${backendBase()}/v1/jobs/${encodeURIComponent(id)}${qs ? `?${qs}` : ""}`;
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

export async function PUT(req: NextRequest, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    const body = await req.text();
    const res = await fetch(`${backendBase()}/v1/jobs/${encodeURIComponent(id)}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body,
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

export async function DELETE(req: NextRequest, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    const res = await fetch(`${backendBase()}/v1/jobs/${encodeURIComponent(id)}`, {
      method: "DELETE",
    });
    if (res.status === 204) {
      return new NextResponse(null, { status: 204 });
    }
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
