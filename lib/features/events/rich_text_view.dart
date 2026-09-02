import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_palette.dart';
import '../../domain/event.dart';

/// Renders a Notion rich-text description with its formatting intact.
///
/// Notion returns a paragraph as a list of inline runs. The Expo app drew each
/// run in its own `View`, so a sentence with one bold word broke across three
/// lines. Composing them into a single [Text.rich] puts the sentence back
/// together, and picks up two marks the original dropped: underline, and links.
///
/// Stateful because a link needs a [TapGestureRecognizer], and a recognizer
/// built inside `build` is never disposed.
class RichTextView extends StatefulWidget {
  const RichTextView(this.runs, {super.key, this.maxLines, this.style});

  final List<RichRun> runs;
  final int? maxLines;
  final TextStyle? style;

  @override
  State<RichTextView> createState() => _RichTextViewState();
}

class _RichTextViewState extends State<RichTextView> {
  /// One recognizer per link run, keyed by its index in [RichTextView.runs].
  final _recognizers = <int, TapGestureRecognizer>{};

  @override
  void didUpdateWidget(RichTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runs != widget.runs) _disposeRecognizers();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = widget.style ??
        Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: palette.textSecondary,
            );

    return Text.rich(
      TextSpan(
        children: [
          for (final (index, run) in widget.runs.indexed)
            _span(index, run, base, palette),
        ],
      ),
      maxLines: widget.maxLines,
      overflow:
          widget.maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }

  InlineSpan _span(int index, RichRun run, TextStyle base, AppPalette palette) {
    var style = base.copyWith(
      fontWeight: run.bold ? FontWeight.bold : null,
      fontStyle: run.italic ? FontStyle.italic : null,
      decoration: TextDecoration.combine([
        if (run.strikethrough) TextDecoration.lineThrough,
        if (run.underline || run.isLink) TextDecoration.underline,
      ]),
    );

    if (run.code) {
      style = style.copyWith(
        fontFamily: 'monospace',
        fontSize: (base.fontSize ?? 15) - 1,
        color: palette.primary,
        backgroundColor: context.tint(palette.primary, 0.12),
      );
    }

    if (!run.isLink) return TextSpan(text: run.text, style: style);

    final href = run.href!;
    final recognizer = _recognizers.putIfAbsent(
      index,
      () => TapGestureRecognizer()..onTap = () => _open(href),
    );

    return TextSpan(
      text: run.text,
      style: style.copyWith(color: palette.primary),
      recognizer: recognizer,
      mouseCursor: SystemMouseCursors.click,
    );
  }

  Future<void> _open(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
