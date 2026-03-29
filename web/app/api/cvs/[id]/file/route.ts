import { NextRequest, NextResponse } from "next/server";
import { backendBase } from "@/lib/backend";

type RouteContext = { params: Promise<{ id: string }> };

export async function GET(req: NextRequest, ctx: RouteContext) {
  try {
    const { id } = await ctx.params;
    const upstreamHeaders = new Headers();
    const range = req.headers.get("Range");
    if (range) upstreamHeaders.set("Range", range);

    const res = await fetch(`${backendBase()}/v1/cvs/${id}/file`, {
      cache: "no-store",
      headers: upstreamHeaders,
    });

    const headers = new Headers();
    const forward = [
      "Content-Type",
      "Content-Disposition",
      "Content-Length",
      "Content-Range",
      "Accept-Ranges",
      "Last-Modified",
    ] as const;
    for (const name of forward) {
      const v = res.headers.get(name);
      if (v) headers.set(name, v);
    }

    return new NextResponse(res.body, {
      status: res.status,
      headers,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "proxy error";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
