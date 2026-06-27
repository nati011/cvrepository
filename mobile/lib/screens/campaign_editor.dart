import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/campaigns_provider.dart';
import 'package:cv_exec_feed/utils/snackbar.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CampaignEditorSheet extends ConsumerStatefulWidget {
  const CampaignEditorSheet({super.key});

  @override
  ConsumerState<CampaignEditorSheet> createState() =>
      _CampaignEditorSheetState();
}

class _CampaignEditorSheetState extends ConsumerState<CampaignEditorSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _jd = TextEditingController();
  final TextEditingController _client = TextEditingController();
  final TextEditingController _hiringManager = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _headcount = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  String _status = 'active';
  bool _saving = false;
  bool _improving = false;

  @override
  void dispose() {
    _title.dispose();
    _jd.dispose();
    _client.dispose();
    _hiringManager.dispose();
    _location.dispose();
    _headcount.dispose();
    _tags.dispose();
    super.dispose();
  }

  Job _buildJob() {
    final hc = int.tryParse(_headcount.text.trim());
    return Job(
      id: '',
      title: _title.text.trim(),
      jdText: _jd.text.trim(),
      status: _status,
      client: _client.text.trim(),
      hiringManager: _hiringManager.text.trim(),
      location: _location.text.trim(),
      headcount: hc,
      tags: _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      createdAt: '',
      updatedAt: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New campaign',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Role title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'paused', child: Text('Paused')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _client,
              decoration: const InputDecoration(labelText: 'Client'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hiringManager,
              decoration: const InputDecoration(labelText: 'Hiring manager'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _headcount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Headcount'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jd,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Job description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LiButton(
                    label: 'Improve with AI',
                    icon: Icons.auto_awesome,
                    variant: LiButtonVariant.secondary,
                    onPressed: _improving || _saving ? null : _improve,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LiButton(
                    label: 'Create',
                    icon: Icons.check,
                    onPressed: _saving || _improving ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _improve() async {
    setState(() => _improving = true);
    try {
      final res = await ref.read(campaignsProvider.notifier).improveDescription(
            title: _title.text.trim(),
            jdText: _jd.text.trim(),
          );
      _title.text = res.title;
      _jd.text = res.jdText;
      if (mounted) {
        showAppSnackBar(
          context,
          res.summary.isNotEmpty ? res.summary : 'Description improved',
        );
      }
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
      final job = await ref
          .read(campaignsProvider.notifier)
          .createCampaign(_buildJob());
      if (mounted) {
        Navigator.pop(context);
        showAppSnackBar(context, 'Campaign “${job.title}” created');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

void openCampaignEditor(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const CampaignEditorSheet(),
  );
}
