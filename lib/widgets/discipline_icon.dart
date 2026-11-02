import 'package:flutter/material.dart';

import '../models/discipline.dart';

/// Icon of a discipline. Parapente is the paraglider (a big wing for
/// distance flying); speedflying has no stock icon, so it's drawn as a
/// smaller wing with speed lines (a small fast wing flown close to the
/// ground). Takes its size and colour from the surrounding IconTheme unless
/// given.
class DisciplineIcon extends StatelessWidget {
  final Discipline discipline;
  final double? size;
  final Color? color;

  const DisciplineIcon(this.discipline, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = this.size ?? theme.size ?? 24;
    final color = this.color ?? theme.color;
    switch (discipline) {
      case Discipline.parapente:
        return Icon(Icons.paragliding, size: size, color: color);
      case Discipline.speedflying:
        Widget line(double length) => Container(
              width: size * length,
              height: size * 0.08,
              margin: EdgeInsets.symmetric(vertical: size * 0.045),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(size),
              ),
            );
        return SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              Positioned(
                right: -size * 0.04,
                top: size * 0.12,
                child: Icon(Icons.paragliding, size: size * 0.78, color: color),
              ),
              Positioned(
                left: 0,
                top: size * 0.3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [line(0.22), line(0.3), line(0.16)],
                ),
              ),
            ],
          ),
        );
    }
  }
}
