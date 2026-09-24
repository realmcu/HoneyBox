import 'package:flutter/material.dart';

class ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool enabled;
  final String? disabledMessage;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.enabled = true,
    this.disabledMessage,
  });

  @override
  State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final enabled = widget.enabled && widget.onTap != null;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.48,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? widget.onTap
                : widget.disabledMessage == null
                    ? null
                    : () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text(widget.disabledMessage!)),
                      ),
            onTapDown: enabled ? (_) => _scaleController.forward() : null,
            onTapUp: enabled ? (_) => _scaleController.reverse() : null,
            onTapCancel: enabled ? () => _scaleController.reverse() : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, size: 24, color: cs.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
