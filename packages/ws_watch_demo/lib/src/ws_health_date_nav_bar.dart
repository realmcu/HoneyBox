import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ws_data_catalog.dart';
import 'ws_health_app_theme.dart';

/// 对齐 App `DateMoveView` + 健康详情日期条（步数/心率等共用）。
///
/// 布局：全宽；中间 `<  日期  >` 始终居中；右侧「回今天」位永远占位
/// （今天时 invisible，对齐 App `View.INVISIBLE`）。
/// 左右滑动只绑在中间日期文字上，避免和 `<`/`>` 点击抢手势。
class WsHealthDateNavBar extends StatelessWidget {
  const WsHealthDateNavBar({
    super.key,
    required this.day,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    this.onPick,
    this.onToday,
    this.prevKey,
    this.nextKey,
    this.pickKey,
  });

  static const height = 48.0;
  static const _dateWidth = 120.0;
  static const _hPad = 20.0;

  final DateTime day;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onPick;
  final VoidCallback? onToday;
  final Key? prevKey;
  final Key? nextKey;
  final Key? pickKey;

  bool get _isToday =>
      jwDataDayStart(day) == jwDataDayStart(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final showToday = !_isToday && onToday != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavHit(
                key: prevKey,
                onTap: onPrev,
                child: const _TurnText('<', enabled: true),
              ),
              SizedBox(
                width: _dateWidth,
                height: height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPick,
                  onHorizontalDragEnd: (details) {
                    final dx = details.primaryVelocity ?? 0;
                    if (dx > 200) {
                      onPrev();
                    } else if (dx < -200) {
                      if (canGoNext) onNext();
                    }
                  },
                  child: Center(
                    child: Text(
                      key: pickKey,
                      jwDataFormatDay(day),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WsHealthAppTheme.topDate,
                        fontSize: 17.3,
                        height: 1.15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
              _NavHit(
                key: nextKey,
                onTap: canGoNext ? onNext : null,
                child: _TurnText('>', enabled: canGoNext),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Visibility(
              visible: showToday,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _NavHit(
                onTap: showToday ? onToday : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: _hPad),
                  child: _TodayBackIcon(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavHit extends StatelessWidget {
  const _NavHit({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: WsHealthDateNavBar.height,
      width: 48,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: WsHealthAppTheme.topTurn,
          disabledForegroundColor: WsHealthAppTheme.topTurnDisabled,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: child,
      ),
    );
  }
}

class _TurnText extends StatelessWidget {
  const _TurnText(this.text, {required this.enabled});

  final String text;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: enabled
            ? WsHealthAppTheme.topTurn
            : WsHealthAppTheme.topTurnDisabled,
        fontSize: 17.3,
        height: 1.0,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _TodayBackIcon extends StatefulWidget {
  const _TodayBackIcon();

  @override
  State<_TodayBackIcon> createState() => _TodayBackIconState();
}

class _TodayBackIconState extends State<_TodayBackIcon> {
  static const _keys = [
    'assets/jw_health/btn_back.png',
    'packages/ws_watch_demo/assets/health/btn_back.png',
    'assets/health/btn_back.png',
  ];

  Uint8List? _bytes;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final key in _keys) {
      try {
        final data = await rootBundle.load(key);
        if (!mounted) return;
        setState(() {
          _bytes = data.buffer.asUint8List();
          _failed = false;
        });
        return;
      } catch (_) {
        // try next
      }
    }
    if (!mounted) return;
    setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    const w = 15.0;
    const h = 12.0;
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: w,
        height: h,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
    }
    return SizedBox(
      width: w,
      height: h,
      child: Icon(
        Icons.reply,
        size: 16,
        color: _failed
            ? WsHealthAppTheme.topTurn
            : WsHealthAppTheme.topTurn.withValues(alpha: 0.35),
      ),
    );
  }
}
