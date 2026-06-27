package pipeline

import (
	"context"
	"encoding/json"
	"fmt"

	"cvrepo/internal/groq"
)

type Profile struct {
	Name       string       `json:"name"`
	Contact    string       `json:"contact"`
	Location   string       `json:"location"`
	Skills     []string     `json:"skills"`
	Experience []Experience `json:"experience"`
	Education  []string     `json:"education"`
	TotalYears float64      `json:"total_years"`
}

type Experience struct {
	Title   string `json:"title"`
	Company string `json:"company"`
	Start   string `json:"start"`
	End     string `json:"end"`
}

type Subscores struct {
	Skills    int `json:"skills"`
	Seniority int `json:"seniority"`
	Domain    int `json:"domain"`
}

type EvidenceItem struct {
	Claim string `json:"claim"`
	Quote string `json:"quote"`
}

type ScoreResult struct {
	Score     int            `json:"score"`
	Subscores Subscores      `json:"subscores"`
	Evidence  []EvidenceItem `json:"evidence"`
}

type OnePager struct {
	TLDR               string   `json:"tldr"`
	Strengths          []string `json:"strengths"`
	Gaps               []string `json:"gaps"`
	RedFlags           []string `json:"red_flags"`
	SuggestedQuestions []string `json:"suggested_questions"`
}

type ChatAnswer struct {
	Answer string `json:"answer"`
	Cites  []struct {
		CVID  string `json:"cv_id"`
		Claim string `json:"claim"`
		Quote string `json:"quote"`
	} `json:"cites"`
}

type Service struct {
	groq *groq.Client
}

func New(g *groq.Client) *Service {
	return &Service{groq: g}
}

func (s *Service) ExtractProfile(ctx context.Context, cvText string) (*Profile, error) {
	system := `You extract structured candidate profiles from CV text. Return valid JSON only with keys:
name, contact, location, skills (array of strings), experience (array of {title, company, start, end}),
education (array of strings), total_years (number).
Use empty strings or empty arrays when unknown. Do not invent facts not present in the CV.`
	user := fmt.Sprintf("Extract a profile from this CV text:\n\n%s", cvText)
	raw, err := s.groq.Complete(ctx, system, user, true)
	if err != nil {
		return nil, err
	}
	var p Profile
	if err := json.Unmarshal([]byte(raw), &p); err != nil {
		return nil, fmt.Errorf("parse profile json: %w", err)
	}
	return &p, nil
}

func (s *Service) ScoreAgainstJob(ctx context.Context, jd string, profile *Profile, cvText string) (*ScoreResult, error) {
	profileJSON, _ := json.Marshal(profileForAnalysis(profile))
	system := `You score candidate fit against a job description. Return valid JSON only with keys:
score (0-100 integer), subscores ({skills, seniority, domain} each 0-100),
evidence (array of {claim, quote} where quote is an exact excerpt from the CV text).
Do not factor candidate location, geography, or relocation into the score or subscores.
Ground every claim in the CV. If not stated, say "not stated" in the quote.`
	user := fmt.Sprintf("Job description:\n%s\n\nCandidate profile JSON:\n%s\n\nCV text:\n%s", jd, string(profileJSON), cvText)
	raw, err := s.groq.Complete(ctx, system, user, true)
	if err != nil {
		return nil, err
	}
	var res ScoreResult
	if err := json.Unmarshal([]byte(raw), &res); err != nil {
		return nil, fmt.Errorf("parse score json: %w", err)
	}
	return &res, nil
}

func (s *Service) GenerateOnePager(ctx context.Context, jd string, profile *Profile, cvText string) (*OnePager, error) {
	profileJSON, _ := json.Marshal(profileForAnalysis(profile))
	system := `You write a concise hiring one-pager. Return valid JSON only with keys:
tldr (2 sentences max), strengths (array), gaps (array), red_flags (array), suggested_questions (array).
Do not mention location, geography, or relocation in the assessment.
Ground claims in the CV text only. If unknown, say "not stated".`
	user := fmt.Sprintf("Job description:\n%s\n\nCandidate profile JSON:\n%s\n\nCV text:\n%s", jd, string(profileJSON), cvText)
	raw, err := s.groq.Complete(ctx, system, user, true)
	if err != nil {
		return nil, err
	}
	var op OnePager
	if err := json.Unmarshal([]byte(raw), &op); err != nil {
		return nil, fmt.Errorf("parse one-pager json: %w", err)
	}
	return &op, nil
}

// RankedResult bundles a score and one-pager as marshaled JSON, ready for persistence.
type RankedResult struct {
	Score     int
	Subscores []byte
	Evidence  []byte
	OnePager  []byte
}

// RankCV scores a candidate against a job and generates a one-pager, returning
// marshaled JSON fields so callers (worker or handler) can persist without
// re-implementing the prompt orchestration.
func (s *Service) RankCV(ctx context.Context, jd string, profileJSON []byte, cvText string) (*RankedResult, error) {
	var profile Profile
	if len(profileJSON) > 0 {
		_ = json.Unmarshal(profileJSON, &profile)
	}
	scoreRes, err := s.ScoreAgainstJob(ctx, jd, &profile, cvText)
	if err != nil {
		return nil, err
	}
	onePager, err := s.GenerateOnePager(ctx, jd, &profile, cvText)
	if err != nil {
		return nil, err
	}
	subJSON, _ := json.Marshal(scoreRes.Subscores)
	evJSON, _ := json.Marshal(scoreRes.Evidence)
	opJSON, _ := json.Marshal(onePager)
	return &RankedResult{
		Score:     scoreRes.Score,
		Subscores: subJSON,
		Evidence:  evJSON,
		OnePager:  opJSON,
	}, nil
}

// JDImprovement is the AI-enhanced job description plus editorial metadata.
type JDImprovement struct {
	Title           string   `json:"title"`
	JDText          string   `json:"jd_text"`
	Summary         string   `json:"summary"`
	Highlights      []string `json:"highlights"`
	SuggestedSkills []string `json:"suggested_skills"`
}

// ImproveJD rewrites/structures a job description (or drafts one from a title
// when jdText is empty). An optional instruction lets the caller steer tone or
// focus (e.g. "make it more concise", "emphasize remote-friendliness").
func (s *Service) ImproveJD(ctx context.Context, title, jdText, instruction string) (*JDImprovement, error) {
	system := `You are an expert technical recruiter and copywriter who improves job descriptions.
Return valid JSON only with keys:
title (string, a crisp role title),
jd_text (string, the improved job description in clean Markdown with clear sections such as
"## About the role", "## Responsibilities", "## Requirements", "## Nice to have" using bullet points),
summary (string, one or two sentences describing what you changed/added),
highlights (array of short strings, the key improvements you made),
suggested_skills (array of strings, concrete skills/keywords worth including).
Keep it factual and grounded in the provided input. Do not invent a company name, salary, or benefits
that were not provided. Be inclusive and concise. If the input is sparse, produce a strong, generic draft
based on the title.`
	user := fmt.Sprintf("Role title: %s\n\nCurrent job description (may be empty):\n%s", title, jdText)
	if instruction = trimSpace(instruction); instruction != "" {
		user += fmt.Sprintf("\n\nExtra instruction from the hiring manager: %s", instruction)
	}
	raw, err := s.groq.Complete(ctx, system, user, true)
	if err != nil {
		return nil, err
	}
	var out JDImprovement
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return nil, fmt.Errorf("parse jd improvement json: %w", err)
	}
	return &out, nil
}

// profileForAnalysis strips fields that must not influence fit scoring or summaries.
func profileForAnalysis(p *Profile) *Profile {
	if p == nil {
		return nil
	}
	copy := *p
	copy.Location = ""
	return &copy
}

func trimSpace(s string) string {
	start := 0
	for start < len(s) && (s[start] == ' ' || s[start] == '\t' || s[start] == '\n' || s[start] == '\r') {
		start++
	}
	end := len(s)
	for end > start && (s[end-1] == ' ' || s[end-1] == '\t' || s[end-1] == '\n' || s[end-1] == '\r') {
		end--
	}
	return s[start:end]
}

func (s *Service) Chat(ctx context.Context, query string, contexts []string) (*ChatAnswer, error) {
	system := `You answer questions about a pile of CVs. Return valid JSON only with keys:
answer (string), cites (array of {cv_id, claim, quote}).
Only use information from the provided contexts. If insufficient data, say so.`
	user := fmt.Sprintf("Question: %s\n\nContexts:\n%s", query, stringsJoin(contexts, "\n---\n"))
	raw, err := s.groq.Complete(ctx, system, user, true)
	if err != nil {
		return nil, err
	}
	var ans ChatAnswer
	if err := json.Unmarshal([]byte(raw), &ans); err != nil {
		return nil, fmt.Errorf("parse chat json: %w", err)
	}
	return &ans, nil
}

func stringsJoin(parts []string, sep string) string {
	if len(parts) == 0 {
		return ""
	}
	out := parts[0]
	for i := 1; i < len(parts); i++ {
		out += sep + parts[i]
	}
	return out
}
