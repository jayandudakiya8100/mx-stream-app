import 'package:flutter/material.dart';

/// Like [IndexedStack], but only builds a child the first time it is selected.
/// Previously visited children stay mounted so their state is preserved.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.sizing = StackFit.loose,
  });

  final int index;
  final List<Widget> children;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit sizing;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late List<bool> _activated;

  @override
  void initState() {
    super.initState();
    _activated = List<bool>.filled(widget.children.length, false);
    _activate(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      final next = List<bool>.filled(widget.children.length, false);
      for (var i = 0; i < next.length && i < _activated.length; i++) {
        next[i] = _activated[i];
      }
      _activated = next;
    }
    _activate(widget.index);
  }

  void _activate(int index) {
    if (index >= 0 && index < _activated.length && !_activated[index]) {
      _activated[index] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = List<Widget>.generate(widget.children.length, (i) {
      return _activated[i] ? widget.children[i] : const SizedBox.shrink();
    });

    return IndexedStack(
      index: widget.index,
      alignment: widget.alignment,
      textDirection: widget.textDirection,
      sizing: widget.sizing,
      children: children,
    );
  }
}
