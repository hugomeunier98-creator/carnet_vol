import 'package:flutter/material.dart';

import '../services/page_colors.dart';

/// Declares the colour of a screen's top bar, so the iPhone status bar area
/// matches it (see web/index.html). Screens stack like routes: the most
/// recently opened one wins, and closing it restores the one below.
class PageColors extends StatefulWidget {
  final Color top;
  final Widget child;

  const PageColors({super.key, required this.top, required this.child});

  @override
  State<PageColors> createState() => _PageColorsState();
}

class _PageColorsState extends State<PageColors> {
  static final _stack = <_PageColorsState>[];

  Color? _background;

  static void _apply() {
    if (_stack.isEmpty) return;
    final current = _stack.last;
    final background = current._background;
    if (background != null) setPageColors(current.widget.top, background);
  }

  @override
  void initState() {
    super.initState();
    _stack.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _background = Theme.of(context).scaffoldBackgroundColor;
    _apply();
  }

  @override
  void didUpdateWidget(PageColors oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.top != widget.top) _apply();
  }

  @override
  void dispose() {
    _stack.remove(this);
    _apply();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
