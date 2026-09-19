import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TypewriterSearchHint extends StatefulWidget {
  final List<String> items;
  final String prefix;
  final String suffix;
  final TextStyle? textStyle;
  final Duration typingSpeed;
  final Duration backspaceSpeed;
  final Duration pauseDuration;

  const TypewriterSearchHint({
    super.key,
    required this.items,
    this.prefix = 'Search "',
    this.suffix = '"',
    this.textStyle,
    this.typingSpeed = const Duration(milliseconds: 45),
    this.backspaceSpeed = const Duration(milliseconds: 22),
    this.pauseDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<TypewriterSearchHint> createState() => _TypewriterSearchHintState();
}

class _TypewriterSearchHintState extends State<TypewriterSearchHint> {
  int _itemIndex = 0;
  String _currentTypedText = '';
  bool _isDeleting = false;
  Timer? _timer;

  static const List<String> _fallbackItems = [
    'Tea & Coffee',
    'Amul Milk',
    'Dairy & Breakfast',
    'Fresh Bread',
    'Snacks & Munchies',
    'Cold Drinks',
    'Farm Fresh Fruits',
    'Instant Noodles',
  ];

  List<String> get _effectiveItems {
    if (widget.items.isNotEmpty) return widget.items;
    return _fallbackItems;
  }

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant TypewriterSearchHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      if (_itemIndex >= _effectiveItems.length) {
        _itemIndex = 0;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    _timer?.cancel();
    final items = _effectiveItems;
    if (items.isEmpty) return;

    final targetWord = items[_itemIndex % items.length];

    if (!_isDeleting) {
      // TYPING FORWARD
      if (_currentTypedText.length < targetWord.length) {
        _currentTypedText =
            targetWord.substring(0, _currentTypedText.length + 1);
        setState(() {});
        _timer = Timer(widget.typingSpeed, _startAnimation);
      } else {
        // Finished typing word, pause so user can read it
        _isDeleting = true;
        _timer = Timer(widget.pauseDuration, _startAnimation);
      }
    } else {
      // BACKSPACING / CLEARING OUT
      if (_currentTypedText.isNotEmpty) {
        _currentTypedText =
            _currentTypedText.substring(0, _currentTypedText.length - 1);
        setState(() {});
        _timer = Timer(widget.backspaceSpeed, _startAnimation);
      } else {
        // Completely cleared out, move to next item
        _isDeleting = false;
        _itemIndex = (_itemIndex + 1) % items.length;
        _timer = Timer(const Duration(milliseconds: 180), _startAnimation);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = AppTheme.bodyMd.copyWith(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final style = widget.textStyle ?? defaultStyle;
    final textColor = style.color ?? Colors.black;

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(
            text: widget.prefix,
            style: style.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: _currentTypedText,
            style: style.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_currentTypedText.isNotEmpty)
            TextSpan(
              text: widget.suffix,
              style: style.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          // Subtle soft cursor tick
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(left: 2.0),
              child: Container(
                width: 1.5,
                height: 14,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
