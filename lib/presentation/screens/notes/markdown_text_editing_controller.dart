import 'package:flutter/material.dart';

class MarkdownTextEditingController extends TextEditingController {
  MarkdownTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textVal = value.text;
    final List<TextSpan> children = [];
    final baseStyle = style ?? const TextStyle(color: Colors.white70);

    final lines = textVal.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLastLine = i == lines.length - 1;

      TextStyle lineStyle = baseStyle;
      String remainingText = line;
      String prefixText = '';

      if (line.startsWith('[ ] ')) {
        prefixText = '[ ] ';
        remainingText = line.substring(4);
      } else if (line.startsWith('[x] ') || line.startsWith('[X] ')) {
        prefixText = line.substring(0, 4);
        remainingText = line.substring(4);
        lineStyle = baseStyle.copyWith(
          decoration: TextDecoration.lineThrough,
          color: Colors.white38,
        );
      } else if (line.startsWith('- ') || line.startsWith('• ')) {
        prefixText = line.substring(0, 2);
        remainingText = line.substring(2);
      } else {
        final numRegex = RegExp(r'^([0-9]+\. )');
        final match = numRegex.firstMatch(line);
        if (match != null) {
          prefixText = match.group(0)!;
          remainingText = line.substring(prefixText.length);
        }
      }

      List<TextSpan> lineSpans = [];
      if (prefixText.isNotEmpty) {
        TextStyle prefixStyle = baseStyle.copyWith(
          color: const Color(0xFF7C3AED), // custom accent color
          fontWeight: FontWeight.bold,
        );
        if (prefixText == '[ ] ') {
          prefixStyle = baseStyle.copyWith(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
          );
        } else if (prefixText.toLowerCase() == '[x] ') {
          prefixStyle = baseStyle.copyWith(
            color: const Color(0xFF10B981),
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.lineThrough,
          );
        }
        lineSpans.add(TextSpan(text: prefixText, style: prefixStyle));
      }

      lineSpans.addAll(_parseInlineFormatting(remainingText, lineStyle));

      children.add(TextSpan(children: lineSpans));
      if (!isLastLine) {
        children.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(children: children, style: baseStyle);
  }

  List<TextSpan> _parseInlineFormatting(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    int index = 0;

    while (index < text.length) {
      int nextBold = text.indexOf('**', index);
      int nextStrike = text.indexOf('~~', index);

      int firstTag = -1;
      String tagType = '';

      if (nextBold != -1 && (nextStrike == -1 || nextBold < nextStrike)) {
        firstTag = nextBold;
        tagType = 'bold';
      } else if (nextStrike != -1) {
        firstTag = nextStrike;
        tagType = 'strike';
      }

      if (firstTag == -1) {
        spans.add(TextSpan(text: text.substring(index), style: baseStyle));
        break;
      }

      if (firstTag > index) {
        spans.add(TextSpan(text: text.substring(index, firstTag), style: baseStyle));
      }

      if (tagType == 'bold') {
        int closingIndex = text.indexOf('**', firstTag + 2);
        if (closingIndex != -1) {
          spans.add(TextSpan(text: '**', style: baseStyle.copyWith(color: Colors.white24)));
          spans.add(TextSpan(
            text: text.substring(firstTag + 2, closingIndex),
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ));
          spans.add(TextSpan(text: '**', style: baseStyle.copyWith(color: Colors.white24)));
          index = closingIndex + 2;
        } else {
          spans.add(TextSpan(text: '**', style: baseStyle));
          index = firstTag + 2;
        }
      } else if (tagType == 'strike') {
        int closingIndex = text.indexOf('~~', firstTag + 2);
        if (closingIndex != -1) {
          spans.add(TextSpan(text: '~~', style: baseStyle.copyWith(color: Colors.white24)));
          spans.add(TextSpan(
            text: text.substring(firstTag + 2, closingIndex),
            style: baseStyle.copyWith(
              decoration: TextDecoration.lineThrough,
              color: baseStyle.color?.withValues(alpha: 0.5) ?? Colors.white38,
            ),
          ));
          spans.add(TextSpan(text: '~~', style: baseStyle.copyWith(color: Colors.white24)));
          index = closingIndex + 2;
        } else {
          spans.add(TextSpan(text: '~~', style: baseStyle));
          index = firstTag + 2;
        }
      }
    }

    return spans;
  }
}
