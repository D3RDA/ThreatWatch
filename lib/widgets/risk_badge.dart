import 'package:flutter/material.dart';

import '../models/risk_level.dart';

class RiskBadge extends StatelessWidget {
  final RiskLevel level;

  const RiskBadge({super.key, required this.level});

  Color get _color {
    switch (level) {
      case RiskLevel.safe:
        return Colors.green;
      case RiskLevel.suspicious:
        return Colors.orange;
      case RiskLevel.dangerous:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level.label,
        style: TextStyle(color: _color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
