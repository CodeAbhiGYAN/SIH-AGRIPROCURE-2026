import 'package:flutter/material.dart';
import '../models/models.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final bool good;
  final bool warning;
  const StatusChip(this.label, {super.key, this.good = false, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final background = good
        ? Colors.green.shade50
        : warning
            ? Colors.orange.shade50
            : Colors.red.shade50;
    final foreground = good
        ? Colors.green.shade800
        : warning
            ? Colors.orange.shade800
            : Colors.red.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, color: foreground),
      ),
    );
  }
}

class BigAction extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  const BigAction({super.key, required this.text, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  const InfoCard({super.key, required this.title, required this.child, this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) Icon(icon, size: 22),
                if (icon != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

String centreStatus(CentreStatus s) => switch (s) {
      CentreStatus.normal => 'NORMAL',
      CentreStatus.busy => 'BUSY',
      CentreStatus.highLoad => 'HIGH LOAD',
      CentreStatus.delayed => 'DELAYED',
      CentreStatus.degraded => 'DEGRADED',
      CentreStatus.unavailable => 'UNAVAILABLE',
    };

class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const NumericKeypad({super.key, required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'back', '0', 'check'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 2.05,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final key in keys)
          FilledButton.tonal(
            onPressed: () => onKey(key),
            child: key == 'back'
                ? const Icon(Icons.backspace_outlined)
                : key == 'check'
                    ? const Icon(Icons.check)
                    : Text(key, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class AndroidLikeNotification extends StatefulWidget {
  final String title;
  final String message;
  final String details;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final bool critical;

  const AndroidLikeNotification({
    super.key,
    required this.title,
    required this.message,
    this.details = '',
    this.onTap,
    this.onDismiss,
    this.critical = false,
  });

  @override
  State<AndroidLikeNotification> createState() => _AndroidLikeNotificationState();
}

class _AndroidLikeNotificationState extends State<AndroidLikeNotification> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Material(
        elevation: 14,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (widget.details.isNotEmpty) {
                setState(() => expanded = !expanded);
              } else {
                widget.onTap?.call();
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.critical ? Colors.orange.shade100 : Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.critical ? Icons.notifications_active_outlined : Icons.sms_outlined, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('Messages', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                            Text('now', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(widget.message, maxLines: expanded ? 10 : 2, overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis),
                        if (expanded && widget.details.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(widget.details, style: const TextStyle(fontSize: 13, height: 1.35)),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          expanded ? 'Tap to collapse' : (widget.details.isNotEmpty ? 'Tap to expand' : 'Tap to open'),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.onDismiss?.call(),
                    icon: const Icon(Icons.close, size: 18),
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

