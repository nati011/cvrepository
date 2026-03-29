export type CVStatus = "pending" | "processing" | "ready" | "failed";

export type CV = {
  id: string;
  title: string;
  original_filename: string;
  content_type: string;
  size_bytes: number;
  sha256: string;
  status: CVStatus;
  parse_error?: string | null;
  text_snippet?: string | null;
  created_at: string;
  updated_at: string;
};

export type CVListResponse = {
  items: CV[];
  total: number;
};

export type SearchHit = {
  id: string;
  title: string;
  original_filename: string;
};

export type SearchResponse = {
  query: string;
  hits: SearchHit[];
};
