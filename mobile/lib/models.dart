class Job {
  final String id;
  final String title;
  final String jdText;
  final String status;
  final String client;
  final String hiringManager;
  final String location;
  final int? headcount;
  final String? startDate;
  final String? endDate;
  final List<String> tags;
  final String? ownerId;
  final String createdAt;
  final String updatedAt;

  Job({
    required this.id,
    required this.title,
    required this.jdText,
    this.status = 'active',
    this.client = '',
    this.hiringManager = '',
    this.location = '',
    this.headcount,
    this.startDate,
    this.endDate,
    this.tags = const [],
    this.ownerId,
    required this.createdAt,
    this.updatedAt = '',
  });

  bool get allowsManualRank =>
      status == 'draft' || status == 'active' || status == 'paused';

  bool get canDeactivate =>
      status == 'draft' || status == 'active' || status == 'paused';

  bool get isDeactivated => status == 'closed' || status == 'archived';

  String get metadataSubtitle {
    final parts = <String>[];
    if (client.isNotEmpty) parts.add(client);
    if (location.isNotEmpty) parts.add(location);
    return parts.join(' · ');
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return Job(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      jdText: (json['jd_text'] ?? '') as String,
      status: (json['status'] ?? 'active') as String,
      client: (json['client'] ?? '') as String,
      hiringManager: (json['hiring_manager'] ?? '') as String,
      location: (json['location'] ?? '') as String,
      headcount: json['headcount'] == null ? null : (json['headcount'] as num).toInt(),
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      tags: rawTags is List
          ? rawTags.map((e) => e.toString()).toList()
          : const [],
      ownerId: json['owner_id'] as String?,
      createdAt: (json['created_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'jd_text': jdText,
        'status': status,
        'client': client,
        'hiring_manager': hiringManager,
        'location': location,
        if (headcount != null) 'headcount': headcount,
        if (startDate != null && startDate!.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate!.isNotEmpty) 'end_date': endDate,
        'tags': tags,
        if (ownerId != null && ownerId!.isNotEmpty) 'owner_id': ownerId,
      };

  Map<String, dynamic> toDefinitionJson() => {
        'title': title,
        'jd_text': jdText,
      };
}

class CampaignStats {
  final int rankedCount;
  final RankStatus rankStatus;
  final int shortlist;
  final int star;
  final int pass;
  final double? avgScore;
  final int? topScore;
  final int reviewedCount;

  const CampaignStats({
    required this.rankedCount,
    required this.rankStatus,
    required this.shortlist,
    required this.star,
    required this.pass,
    this.avgScore,
    this.topScore,
    required this.reviewedCount,
  });

  factory CampaignStats.fromJson(Map<String, dynamic> json, String campaignId) {
    final reactions = json['reactions'] as Map? ?? {};
    final rankRaw = json['rank_status'] as Map? ?? {};
    return CampaignStats(
      rankedCount: ((json['ranked_count'] ?? 0) as num).toInt(),
      rankStatus: RankStatus.fromJson({
        'job_id': campaignId,
        'campaign_id': campaignId,
        ...Map<String, dynamic>.from(rankRaw),
      }),
      shortlist: ((reactions['shortlist'] ?? 0) as num).toInt(),
      star: ((reactions['star'] ?? 0) as num).toInt(),
      pass: ((reactions['pass'] ?? 0) as num).toInt(),
      avgScore: json['avg_score'] == null ? null : (json['avg_score'] as num).toDouble(),
      topScore: json['top_score'] == null ? null : (json['top_score'] as num).toInt(),
      reviewedCount: ((json['reviewed_count'] ?? 0) as num).toInt(),
    );
  }
}

class Experience {
  final String title;
  final String company;
  final String start;
  final String end;

  Experience({
    required this.title,
    required this.company,
    required this.start,
    required this.end,
  });

  factory Experience.fromJson(Map<String, dynamic> json) {
    return Experience(
      title: (json['title'] ?? '') as String,
      company: (json['company'] ?? '') as String,
      start: (json['start'] ?? '') as String,
      end: (json['end'] ?? '') as String,
    );
  }

  String get range {
    final parts = [start, end].where((p) => p.isNotEmpty).toList();
    return parts.join(' – ');
  }
}

class Evidence {
  final String claim;
  final String quote;

  Evidence({required this.claim, required this.quote});

  factory Evidence.fromJson(Map<String, dynamic> json) {
    return Evidence(
      claim: (json['claim'] ?? '') as String,
      quote: (json['quote'] ?? '') as String,
    );
  }

  bool get isStated =>
      quote.trim().isNotEmpty && quote.trim().toLowerCase() != 'not stated';
}

class RoleMatch {
  final String jobId;
  final String jobTitle;
  final int score;
  final RoleKind kind;

  const RoleMatch({
    required this.jobId,
    required this.jobTitle,
    required this.score,
    this.kind = RoleKind.job,
  });
}

enum RoleKind { job, campaign }

class FeedItem {
  final String cvId;
  final String name;
  final String fileName;
  final String location;
  final String contact;
  final int totalYears;
  final int score;
  final Map<String, int> subscores;
  final String tldr;
  final List<String> skills;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> redFlags;
  final List<String> suggestedQuestions;
  final List<Experience> experience;
  final List<Evidence> evidence;

  /// The job this candidate was scored against (populated client-side so the
  /// global feed can show which role each match belongs to).
  final String jobId;
  final String jobTitle;
  final String scoredAt;
  final List<RoleMatch> roleMatches;

  FeedItem({
    required this.cvId,
    required this.name,
    required this.fileName,
    required this.location,
    required this.contact,
    required this.totalYears,
    required this.score,
    required this.subscores,
    required this.tldr,
    required this.skills,
    required this.strengths,
    required this.gaps,
    required this.redFlags,
    required this.suggestedQuestions,
    required this.experience,
    required this.evidence,
    this.jobId = '',
    this.jobTitle = '',
    this.scoredAt = '',
    this.roleMatches = const [],
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final cv = _asMap(json['cv']);
    final profile = _asMap(json['profile']);
    final onePager = _asMap(json['one_pager']);
    final subs = _asMap(json['subscores']);

    return FeedItem(
      cvId: (cv['id'] ?? '') as String,
      name: (profile['name'] ?? cv['title'] ?? cv['original_filename'] ?? 'Unknown candidate') as String,
      fileName: (cv['original_filename'] ?? '') as String,
      location: (profile['location'] ?? '') as String,
      contact: (profile['contact'] ?? '') as String,
      totalYears: ((profile['total_years'] ?? 0) as num).toInt(),
      score: ((json['score'] ?? 0) as num).toInt(),
      subscores: subs.map((k, v) => MapEntry(k, ((v ?? 0) as num).toInt())),
      tldr: (onePager['tldr'] ?? '') as String,
      skills: _asStringList(profile['skills']),
      strengths: _asStringList(onePager['strengths']),
      gaps: _asStringList(onePager['gaps']),
      redFlags: _asStringList(onePager['red_flags']),
      suggestedQuestions: _asStringList(onePager['suggested_questions']),
      experience: _asList(profile['experience'])
          .map((e) => Experience.fromJson(_asMap(e)))
          .toList(),
      evidence: _asList(json['evidence'])
          .map((e) => Evidence.fromJson(_asMap(e)))
          .where((e) => e.isStated)
          .toList(),
      scoredAt: (json['scored_at'] ?? cv['created_at'] ?? '') as String,
    );
  }

  /// Builds a profile-only view from GET /v1/cvs/{id} (no ranking data yet).
  factory FeedItem.fromCvJson(Map<String, dynamic> cv) {
    final profile = _asMap(cv['profile']);
    return FeedItem(
      cvId: (cv['id'] ?? '') as String,
      name: (profile['name'] ?? cv['title'] ?? cv['original_filename'] ?? 'Unknown candidate') as String,
      fileName: (cv['original_filename'] ?? '') as String,
      location: (profile['location'] ?? '') as String,
      contact: (profile['contact'] ?? '') as String,
      totalYears: ((profile['total_years'] ?? 0) as num).toInt(),
      score: 0,
      subscores: const {},
      tldr: '',
      skills: _asStringList(profile['skills']),
      strengths: const [],
      gaps: const [],
      redFlags: const [],
      suggestedQuestions: const [],
      experience: _asList(profile['experience'])
          .map((e) => Experience.fromJson(_asMap(e)))
          .toList(),
      evidence: const [],
      scoredAt: (cv['updated_at'] ?? cv['created_at'] ?? '') as String,
    );
  }

  FeedItem withJob({required String jobId, required String jobTitle}) => FeedItem(
        cvId: cvId,
        name: name,
        fileName: fileName,
        location: location,
        contact: contact,
        totalYears: totalYears,
        score: score,
        subscores: subscores,
        tldr: tldr,
        skills: skills,
        strengths: strengths,
        gaps: gaps,
        redFlags: redFlags,
        suggestedQuestions: suggestedQuestions,
        experience: experience,
        evidence: evidence,
        jobId: jobId,
        jobTitle: jobTitle,
        scoredAt: scoredAt,
        roleMatches: [
          RoleMatch(jobId: jobId, jobTitle: jobTitle, score: score),
        ],
      );

  FeedItem withRoleMatches(List<RoleMatch> roles) {
    final sorted = [...roles]..sort((a, b) => b.score.compareTo(a.score));
    final top = sorted.isNotEmpty ? sorted.first : null;
    return FeedItem(
      cvId: cvId,
      name: name,
      fileName: fileName,
      location: location,
      contact: contact,
      totalYears: totalYears,
      score: top?.score ?? score,
      subscores: subscores,
      tldr: tldr,
      skills: skills,
      strengths: strengths,
      gaps: gaps,
      redFlags: redFlags,
      suggestedQuestions: suggestedQuestions,
      experience: experience,
      evidence: evidence,
      jobId: top?.jobId ?? jobId,
      jobTitle: top?.jobTitle ?? jobTitle,
      scoredAt: scoredAt,
      roleMatches: sorted,
    );
  }

  List<RoleMatch> get displayRoles {
    if (roleMatches.isNotEmpty) return roleMatches;
    if (jobTitle.isNotEmpty) {
      return [
        RoleMatch(jobId: jobId, jobTitle: jobTitle, score: score),
      ];
    }
    return const [];
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// A global-search hit (CV document), mirroring the web `/v1/search` response.
class SearchHit {
  final String id;
  final String title;
  final String originalFilename;

  SearchHit({
    required this.id,
    required this.title,
    required this.originalFilename,
  });

  factory SearchHit.fromJson(Map<String, dynamic> json) {
    return SearchHit(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      originalFilename: (json['original_filename'] ?? '') as String,
    );
  }

  String get label => title.isNotEmpty ? title : originalFilename;

  String get initials {
    final src = label.trim();
    if (src.isEmpty) return '?';
    final parts = src.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class Citation {
  final String cvId;
  final String claim;
  final String quote;

  Citation({required this.cvId, required this.claim, required this.quote});

  factory Citation.fromJson(Map<String, dynamic> json) {
    return Citation(
      cvId: (json['cv_id'] ?? '') as String,
      claim: (json['claim'] ?? '') as String,
      quote: (json['quote'] ?? '') as String,
    );
  }
}

class ChatResponse {
  final String answer;
  final List<Citation> cites;

  ChatResponse({required this.answer, required this.cites});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      answer: (json['answer'] ?? '') as String,
      cites: _asList(json['cites'])
          .map((c) => Citation.fromJson(_asMap(c)))
          .toList(),
    );
  }
}

class ExecStat {
  final String execId;
  final int totalReviews;
  final int likes;
  final int shortlists;
  final int stars;
  final int passes;
  final int streakDays;

  ExecStat({
    required this.execId,
    required this.totalReviews,
    required this.likes,
    required this.shortlists,
    required this.stars,
    required this.passes,
    required this.streakDays,
  });

  factory ExecStat.fromJson(Map<String, dynamic> json) {
    return ExecStat(
      execId: (json['exec_id'] ?? '') as String,
      totalReviews: ((json['total_reviews'] ?? 0) as num).toInt(),
      likes: ((json['likes'] ?? 0) as num).toInt(),
      shortlists: ((json['shortlists'] ?? 0) as num).toInt(),
      stars: ((json['stars'] ?? 0) as num).toInt(),
      passes: ((json['passes'] ?? 0) as num).toInt(),
      streakDays: ((json['streak_days'] ?? 0) as num).toInt(),
    );
  }
}

/// A candidate in the Liked or Starred lists, with reaction metadata.
class ListEntry {
  final FeedItem item;
  final Reaction reaction;

  const ListEntry({required this.item, required this.reaction});
}

/// A ranked candidate within a specific campaign.
class CampaignCandidate {
  final FeedItem item;
  final int rank;
  final String? reactionAction;

  const CampaignCandidate({
    required this.item,
    required this.rank,
    this.reactionAction,
  });

  bool get isReviewed => reactionAction != null;
  bool get isShortlisted => reactionAction == 'shortlist';
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic v) => v is List ? v : const [];

List<String> _asStringList(dynamic v) =>
    _asList(v).map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();

class Reaction {
  final String id;
  final String cvId;
  final String? jobId;
  final String execId;
  final String action;
  final String createdAt;

  const Reaction({
    required this.id,
    required this.cvId,
    this.jobId,
    required this.execId,
    required this.action,
    required this.createdAt,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) {
    final jobId = json['job_id'];
    return Reaction(
      id: (json['id'] ?? '') as String,
      cvId: (json['cv_id'] ?? '') as String,
      jobId: jobId == null ? null : jobId as String,
      execId: (json['exec_id'] ?? 'anonymous') as String,
      action: (json['action'] ?? '') as String,
      createdAt: (json['created_at'] ?? '') as String,
    );
  }

  ReactionKey get key => ReactionKey(cvId: cvId, jobId: jobId ?? '');
}

class ReactionKey {
  final String cvId;
  final String jobId;

  const ReactionKey({required this.cvId, this.jobId = ''});

  factory ReactionKey.of(String cvId, String? jobId) =>
      ReactionKey(cvId: cvId, jobId: jobId ?? '');

  @override
  bool operator ==(Object other) =>
      other is ReactionKey && other.cvId == cvId && other.jobId == jobId;

  @override
  int get hashCode => Object.hash(cvId, jobId);
}

class RankStatus {
  final String jobId;
  final int pending;
  final int processing;
  final int done;
  final int failed;

  const RankStatus({
    required this.jobId,
    required this.pending,
    required this.processing,
    required this.done,
    required this.failed,
  });

  factory RankStatus.fromJson(Map<String, dynamic> json) {
    return RankStatus(
      jobId: (json['job_id'] ?? json['campaign_id'] ?? '') as String,
      pending: ((json['pending'] ?? 0) as num).toInt(),
      processing: ((json['processing'] ?? 0) as num).toInt(),
      done: ((json['done'] ?? 0) as num).toInt(),
      failed: ((json['failed'] ?? 0) as num).toInt(),
    );
  }

  bool get isActive => pending > 0 || processing > 0;
  int get total => pending + processing + done + failed;
}

class JobProgress {
  final String jobId;
  final String execId;
  final int reviewed;

  const JobProgress({
    required this.jobId,
    required this.execId,
    required this.reviewed,
  });

  factory JobProgress.fromJson(Map<String, dynamic> json) {
    return JobProgress(
      jobId: (json['job_id'] ?? '') as String,
      execId: (json['exec_id'] ?? '') as String,
      reviewed: ((json['reviewed'] ?? 0) as num).toInt(),
    );
  }
}

class ImprovedJD {
  final String title;
  final String jdText;
  final String summary;
  final List<String> highlights;
  final List<String> suggestedSkills;

  const ImprovedJD({
    required this.title,
    required this.jdText,
    required this.summary,
    required this.highlights,
    required this.suggestedSkills,
  });

  factory ImprovedJD.fromJson(Map<String, dynamic> json) {
    return ImprovedJD(
      title: (json['title'] ?? '') as String,
      jdText: (json['jd_text'] ?? '') as String,
      summary: (json['summary'] ?? '') as String,
      highlights: _asStringList(json['highlights']),
      suggestedSkills: _asStringList(json['suggested_skills']),
    );
  }
}

class ChatMessage {
  final String text;
  final bool fromUser;
  final List<Citation> cites;
  final bool error;

  const ChatMessage({
    required this.text,
    required this.fromUser,
    this.cites = const [],
    this.error = false,
  });
}

class StageCounts {
  final int pending;
  final int processing;
  final int ready;
  final int failed;

  const StageCounts({
    this.pending = 0,
    this.processing = 0,
    this.ready = 0,
    this.failed = 0,
  });

  factory StageCounts.fromJson(Map<String, dynamic> json) {
    return StageCounts(
      pending: ((json['pending'] ?? 0) as num).toInt(),
      processing: ((json['processing'] ?? 0) as num).toInt(),
      ready: ((json['ready'] ?? 0) as num).toInt(),
      failed: ((json['failed'] ?? 0) as num).toInt(),
    );
  }
}

class RankCounts {
  final int pending;
  final int processing;
  final int done;
  final int failed;

  const RankCounts({
    this.pending = 0,
    this.processing = 0,
    this.done = 0,
    this.failed = 0,
  });

  factory RankCounts.fromJson(Map<String, dynamic> json) {
    return RankCounts(
      pending: ((json['pending'] ?? 0) as num).toInt(),
      processing: ((json['processing'] ?? 0) as num).toInt(),
      done: ((json['done'] ?? 0) as num).toInt(),
      failed: ((json['failed'] ?? 0) as num).toInt(),
    );
  }
}

class PipelineStats {
  final int totalCvs;
  final StageCounts extraction;
  final StageCounts profile;
  final RankCounts ranking;
  final int jobs;
  final int campaigns;

  const PipelineStats({
    this.totalCvs = 0,
    this.extraction = const StageCounts(),
    this.profile = const StageCounts(),
    this.ranking = const RankCounts(),
    this.jobs = 0,
    this.campaigns = 0,
  });

  factory PipelineStats.fromJson(Map<String, dynamic> json) {
    return PipelineStats(
      totalCvs: ((json['total_cvs'] ?? 0) as num).toInt(),
      extraction: StageCounts.fromJson(_asMap(json['extraction'])),
      profile: StageCounts.fromJson(_asMap(json['profile'])),
      ranking: RankCounts.fromJson(_asMap(json['ranking'])),
      jobs: ((json['jobs'] ?? 0) as num).toInt(),
      campaigns: ((json['campaigns'] ?? 0) as num).toInt(),
    );
  }
}

enum NoticeTone { info, success, progress, warning }

class AppNotice {
  final String id;
  final NoticeTone tone;
  final String title;
  final String detail;
  final int? tabIndex;

  const AppNotice({
    required this.id,
    required this.tone,
    required this.title,
    required this.detail,
    this.tabIndex,
  });
}

List<AppNotice> buildNotices(PipelineStats stats) {
  final out = <AppNotice>[];
  final inFlight = stats.extraction.pending +
      stats.extraction.processing +
      stats.profile.pending +
      stats.profile.processing +
      stats.ranking.pending +
      stats.ranking.processing;

  if (inFlight > 0) {
    out.add(AppNotice(
      id: 'in-flight',
      tone: NoticeTone.progress,
      title: '$inFlight item${inFlight == 1 ? '' : 's'} processing',
      detail: 'Extraction, profiling, and ranking are running in the background.',
      tabIndex: 2,
    ));
  }
  if (stats.ranking.done > 0) {
    out.add(AppNotice(
      id: 'ranked',
      tone: NoticeTone.success,
      title: '${stats.ranking.done} candidate${stats.ranking.done == 1 ? '' : 's'} ranked',
      detail: 'Scored across ${stats.jobs} job${stats.jobs == 1 ? '' : 's'}. Review in the feed.',
      tabIndex: 0,
    ));
  }
  if (stats.extraction.ready > 0) {
    out.add(AppNotice(
      id: 'search-ready',
      tone: NoticeTone.info,
      title: '${stats.extraction.ready} CV${stats.extraction.ready == 1 ? '' : 's'} search-ready',
      detail: 'Extracted résumé text is indexed and searchable.',
    ));
  }
  final failed = stats.extraction.failed + stats.profile.failed;
  if (failed > 0) {
    out.add(AppNotice(
      id: 'failed',
      tone: NoticeTone.warning,
      title: '$failed document${failed == 1 ? '' : 's'} need attention',
      detail: 'Some files failed to parse or profile.',
      tabIndex: 2,
    ));
  }
  return out;
}
