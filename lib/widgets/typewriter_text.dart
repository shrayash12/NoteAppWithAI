import 'dart:async';
import 'package:flutter/material.dart';

/// Animates [text] appearing character by character, with a blinking
/// cursor at the end. If [text] grows (e.g. live speech-to-text results),
/// only the new suffix is typed instead of restarting from scratch.
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDuration;
  final bool showCursor;
  final Color? cursorColor;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charDuration = const Duration(milliseconds: 30),
    this.showCursor = true,
    this.cursorColor,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  String _displayed = '';
  Timer? _typeTimer;
  late final AnimationController _cursorController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _startTyping(widget.text);
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _startTyping(widget.text);
    }
  }

  void _startTyping(String target) {
    _typeTimer?.cancel();

    if (!target.startsWith(_displayed)) {
      _displayed = '';
    }

    if (_displayed.length >= target.length) {
      _displayed = target;
      return;
    }

    _typeTimer = Timer.periodic(widget.charDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_displayed.length >= target.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _displayed = target.substring(0, _displayed.length + 1);
      });
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cursorColor = widget.cursorColor ?? widget.style?.color ?? Colors.black;
    final fontSize = widget.style?.fontSize ?? 14;

    return RichText(
      text: TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: _displayed),
          if (widget.showCursor)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: FadeTransition(
                opacity: _cursorController,
                child: Container(
                  width: 2,
                  height: fontSize * 1.1,
                  margin: const EdgeInsets.only(left: 2),
                  color: cursorColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
