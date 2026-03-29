import { NextRequest, NextResponse } from "next/server";
import { backendBase } from "@/lib/backend";

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();
    const res = await fetch(`${backendBase()}/v1/cvs/batch`, {
      method: "POST",
      body: formData,
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
