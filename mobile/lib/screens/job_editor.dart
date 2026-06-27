import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/job_definitions_provider.dart';
import 'package:cv_exec_feed/utils/snackbar.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JobEditorSheet extends ConsumerStatefulWidget {
  final Job? job;
  const JobEditorSheet({super.key, this.job});

  @override
  ConsumerState<JobEditorSheet> createState() => _JobEditorSheetState();
}

class _JobEditorSheetState extends ConsumerState<JobEditorSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _jd = TextEditingController();
  final TextEditingController _instruction = TextEditingController();
  bool _saving = false;
  bool _improving = false;

  bool get _isEdit => widget.job != null;

  @override
  void initState() {
    super.initState();
    final job = widget.job;
    if (job != null) {
      _title.text = job.title;
      _jd.text = job.jdText;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _jd.dispose();
    _instruction.dispose();
    super.dispose();
  }

  Job _buildJob() {
    return Job(
      id: widget.job?.id ?? '',
      title: _title.text.trim(),
      jdText: _jd.text.trim(),
      createdAt: widget.job?.createdAt ?? '',
      updatedAt: widget.job?.updatedAt ?? '',
    );
  }

  Future<void> _improve() async {
    if (_title.text.trim().isEmpty && _jd.text.trim().isEmpty) {
      showAppSnackBar(context, 'Add a title or description first');
      return;
    }
    setState(() => _improving = true);
    try {
      final res = await ref
          .read(jobDefinitionsProvider.notifier)
          .improveDescription(
            title: _title.text.trim(),
            jdText: _jd.text.trim(),
            instruction: _instruction.text.trim(),
          );
      if (res.title.isNotEmpty) _title.text = res.title;
      if (res.jdText.isNotEmpty) _jd.text = res.jdText;
      if (mounted) showAppSnackBar(context, 'AI updated the description');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _improving = false);
    }
  }

  Future<void> _save() async {
    final jd = _jd.text.trim();
    if (jd.isEmpty) {
      showAppSnackBar(context, 'Job description is required');
      return;
    }
    setState(() => _saving = true);
    try {
      final job = _buildJob();
      final saved = _isEdit
          ? await ref.read(jobDefinitionsProvider.notifier).updateJob(job)
          : await ref.read(jobDefinitionsProvider.notifier).createJob(job);
      if (mounted) {
        Navigator.pop(context);
        showAppSnackBar(
          context,
          _isEdit ? 'Job updated' : 'Job “${saved.title}” created',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEdit ? 'Edit job' : 'New job',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Role title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _jd,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Job description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instruction,
              decoration: const InputDecoration(labelText: 'Optional AI instruction'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LiButton(
                    label: _improving ? 'Improving…' : 'Improve with AI',
                    icon: Icons.auto_awesome,
                    onPressed: _improving ? null : _improve,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LiButton(
                    label: _saving ? 'Saving…' : (_isEdit ? 'Save' : 'Create'),
                    icon: Icons.check,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void openJobEditor(BuildContext context, {Job? job}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => JobEditorSheet(job: job),
  );
}
