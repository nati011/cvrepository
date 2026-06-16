import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/chat_provider.dart';
import 'package:cv_exec_feed/providers/feed_provider.dart';
import 'package:cv_exec_feed/screens/feed_screen.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/utils/citation_utils.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(candidateLookupProvider);
    final chat = ref.watch(chatProvider);

    ref.listen(chatProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToEnd();
      }
    });

    return Column(
      children: [
        Expanded(
          child: chat.messages.isEmpty
              ? const _EmptyChat()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: chat.messages.length + (chat.loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= chat.messages.length) {
                      return const _TypingBubble();
                    }
                    return _MessageBubble(message: chat.messages[index]);
                  },
                ),
        ),
        _Composer(
          controller: _ctrl,
          enabled: !chat.loading,
          onSend: _ask,
        ),
      ],
    );
  }

  Future<void> _ask() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty || ref.read(chatProvider).loading) return;
    _ctrl.clear();
    await ref.read(chatProvider.notifier).ask(query);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.auto_awesome, size: 48, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          'Ask the CV pile',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Get evidence-backed answers with citations across all candidate CVs.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.fromUser;
    final bg = isUser
        ? scheme.primary
        : message.error
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final fg = isUser
        ? scheme.onPrimary
        : message.error
            ? scheme.onErrorContainer
            : scheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(message.text, style: TextStyle(color: fg, height: 1.35)),
            ),
            if (message.cites.isNotEmpty) ...[
              const SizedBox(height: 6),
              const SectionLabel(icon: Icons.format_quote, label: 'Citations'),
              const SizedBox(height: 4),
              ...groupCitationsByCandidate(message.cites)
                  .map((group) => _CitationGroup(cites: group)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CitationGroup extends ConsumerWidget {
  final List<Citation> cites;
  const _CitationGroup({required this.cites});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cites.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final cvId = cites.first.cvId;
    final candidate = ref.watch(candidateLookupProvider)[cvId];
    final canOpen = candidate != null;

    Future<void> openProfile() async {
      var resolved = candidate;
      resolved ??= await resolveCandidate(ref, cvId);
      if (!context.mounted) return;
      if (resolved != null) {
        showCandidateDetails(context, resolved);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile is still processing. Try again in a few seconds.',
          ),
        ),
      );
    }

    return LiQuoteCard(
      margin: const EdgeInsets.only(bottom: 6),
      background: scheme.surface,
      padding: const EdgeInsets.all(10),
      onTap: openProfile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (candidate != null) ...[
                LiAvatar(initials: candidate.initials, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    candidate.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ] else
                Expanded(
                  child: Text(
                    cites.first.claim.isNotEmpty
                        ? cites.first.claim
                        : 'Candidate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
              if (canOpen || cvId.isNotEmpty) ...[
                Text(
                  'View profile',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: canOpen
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: canOpen ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
          ...cites.asMap().entries.map((entry) {
            final cite = entry.value;
            final isFirst = entry.key == 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isFirst) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                ],
                if (candidate != null && cite.claim.isNotEmpty) ...[
                  SizedBox(height: isFirst ? 4 : 0),
                  Text(
                    cite.claim,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
                if (cite.quote.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '“${cite.quote}”',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Dot(), _Dot(delay: 150), _Dot(delay: 300),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = ((_c.value * 1000) - widget.delay) % 900 / 900;
        final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2)).clamp(0.3, 1.0);
        return Opacity(
          opacity: opacity,
          child: CircleAvatar(
            radius: 4,
            backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => enabled ? onSend() : null,
              decoration: InputDecoration(
                hintText: 'Ask about the candidates…',
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(enabled: enabled, onSend: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onSend;
  const _SendButton({required this.enabled, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.5,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.brandGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.seed.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: enabled ? onSend : null,
            child: const Icon(Icons.arrow_upward_rounded,
                size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
