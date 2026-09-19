import 'dart:async';
import 'package:flutter/foundation.dart';
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

  static String _capitalizeWords(String text) {
    if (text.trim().isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : '');
    }).join(' ');
  }

  List<String> get _effectiveItems {
    final rawList = widget.items.isNotEmpty ? widget.items : _fallbackItems;
    return rawList.map(_capitalizeWords).toList();
  }

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant TypewriterSearchHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemsChanged = !listEquals(widget.items, oldWidget.items) ||
        widget.prefix != oldWidget.prefix ||
        widget.suffix != oldWidget.suffix;
    if (itemsChanged) {
      _itemIndex = 0;
      _currentTypedText = '';
      _isDeleting = false;
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    _timer?.cancel();
    if (!mounted) return;

    final items = _effectiveItems;
    if (items.isEmpty) {
      if (_currentTypedText.isNotEmpty && mounted) {
        setState(() => _currentTypedText = '');
      }
      return;
    }

    if (_itemIndex >= items.length) {
      _itemIndex = 0;
    }

    final targetWord = items[_itemIndex];

    if (!_isDeleting) {
      // TYPING FORWARD
      if (_currentTypedText.length < targetWord.length) {
        final nextLen =
            (_currentTypedText.length + 1).clamp(0, targetWord.length);
        _currentTypedText = targetWord.substring(0, nextLen);
        if (mounted) setState(() {});
        _timer = Timer(widget.typingSpeed, _startAnimation);
      } else {
        // Finished typing word, pause so user can read it
        _isDeleting = true;
        _timer = Timer(widget.pauseDuration, _startAnimation);
      }
    } else {
      // BACKSPACING / CLEARING OUT
      if (_currentTypedText.isNotEmpty) {
        if (_currentTypedText.length > targetWord.length) {
          _currentTypedText = targetWord;
        } else {
          _currentTypedText =
              _currentTypedText.substring(0, _currentTypedText.length - 1);
        }
        if (mounted) setState(() {});
        _timer = Timer(widget.backspaceSpeed, _startAnimation);
      } else {
        // Completely cleared out, move to next item (loops seamlessly even if only 1 item)
        _isDeleting = false;
        _itemIndex = (_itemIndex + 1) % items.length;
        _timer = Timer(const Duration(milliseconds: 250), _startAnimation);
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
