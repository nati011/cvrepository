import 'dart:typed_data';

import 'package:cv_exec_feed/data/providers.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

final cvPdfProvider =
    FutureProvider.autoDispose.family<Uint8List, String>((ref, cvId) {
  return ref.read(apiClientProvider).downloadCvFile(cvId);
});

void openOriginalCv(
  BuildContext context, {
  required String cvId,
  required String title,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CvViewerScreen(cvId: cvId, title: title),
    ),
  );
}

class CvViewerScreen extends ConsumerStatefulWidget {
  final String cvId;
  final String title;

  const CvViewerScreen({
    super.key,
    required this.cvId,
    required this.title,
  });

  @override
  ConsumerState<CvViewerScreen> createState() => _CvViewerScreenState();
}

class _CvViewerScreenState extends ConsumerState<CvViewerScreen> {
  PdfControllerPinch? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pdfAsync = ref.watch(cvPdfProvider(widget.cvId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: pdfAsync.when(
        loading: () => const LoadingView(label: 'Loading CV…'),
        error: (e, _) => StateView(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Could not load CV',
          subtitle: '$e',
          action: LiButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: () => ref.invalidate(cvPdfProvider(widget.cvId)),
          ),
        ),
        data: (bytes) {
          _controller ??= PdfControllerPinch(
            document: PdfDocument.openData(bytes),
          );
          return PdfViewPinch(
            controller: _controller!,
            padding: 12,
            scrollDirection: Axis.vertical,
          );
        },
      ),
    );
  }
}
