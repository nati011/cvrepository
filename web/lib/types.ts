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

export type CampaignStatus = "draft" | "active" | "paused" | "closed" | "archived";

export type Job = {
  id: string;
  title: string;
  jd_text: string;
  created_at: string;
  updated_at: string;
};

export type JobsResponse = {
  items: Job[];
};

export type Campaign = {
  id: string;
  title: string;
  jd_text: string;
  status: CampaignStatus;
  client: string;
  hiring_manager: string;
  location: string;
  headcount?: number | null;
  start_date?: string | null;
  end_date?: string | null;
  tags: string[];
  owner_id?: string | null;
  created_at: string;
  updated_at: string;
};

export type CampaignsResponse = {
  items: Campaign[];
};

export type CampaignStats = {
  ranked_count: number;
  rank_status: {
    pending: number;
    processing: number;
    done: number;
    failed: number;
  };
  reactions: {
    shortlist: number;
    star: number;
    pass: number;
  };
  avg_score?: number | null;
  top_score?: number | null;
  reviewed_count: number;
};

export type JDImprovement = {
  title: string;
  jd_text: string;
  summary: string;
  highlights?: string[];
  suggested_skills?: string[];
};

export type FeedItem = {
  cv: CV;
  profile?: {
    name?: string;
    location?: string;
    skills?: string[];
  };
  score: number;
  subscores?: {
    skills?: number;
    seniority?: number;
    domain?: number;
    location?: number;
  };
  evidence?: Array<{ claim: string; quote: string }>;
  one_pager?: {
    tldr?: string;
    strengths?: string[];
    gaps?: string[];
    red_flags?: string[];
    suggested_questions?: string[];
  };
};

export type FeedResponse = {
  items: FeedItem[];
  total: number;
};

export type RankStatus = {
  job_id: string;
  pending: number;
  processing: number;
  done: number;
  failed: number;
};

export type StageCounts = {
  pending: number;
  processing: number;
  ready: number;
  failed: number;
};

export type RankCounts = {
  pending: number;
  processing: number;
  done: number;
  failed: number;
};

export type PipelineStats = {
  total_cvs: number;
  extraction: StageCounts;
  profile: StageCounts;
  ranking: RankCounts;
  jobs: number;
  campaigns: number;
};

const emptyStageCounts = (): StageCounts => ({
  pending: 0,
  processing: 0,
  ready: 0,
  failed: 0,
});

const emptyRankCounts = (): RankCounts => ({
  pending: 0,
  processing: 0,
  done: 0,
  failed: 0,
});

/** Coerce partial API payloads (e.g. older backends) into a safe PipelineStats. */
export function normalizePipelineStats(raw: Partial<PipelineStats> | null | undefined): PipelineStats {
  return {
    total_cvs: raw?.total_cvs ?? 0,
    extraction: raw?.extraction ?? emptyStageCounts(),
    profile: raw?.profile ?? emptyStageCounts(),
    ranking: raw?.ranking ?? emptyRankCounts(),
    jobs: raw?.jobs ?? 0,
    campaigns: raw?.campaigns ?? 0,
  };
}
