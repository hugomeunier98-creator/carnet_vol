import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Takeoff or landing.
enum Spot {
  // An arrow leaving the slope, in the app's accent.
  takeoff(Icons.north_east, null),
  // The landing target.
  landing(Icons.adjust, Color(0xFF2E3440));

  final IconData icon;
  final Color? _color;
  const Spot(this.icon, this._color);

  Color get color => _color ?? AppColors.accent;
}

/// A round badge for a takeoff or landing: white glyph on the spot's
/// colour. With [onMap], a white ring and a soft shadow keep it readable
/// on any map.
class SpotMarker extends StatelessWidget {
  final Spot spot;
  final double size;
  final bool onMap;

  const SpotMarker(this.spot, {super.key, this.size = 28, this.onMap = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: spot.color,
        shape: BoxShape.circle,
        border: onMap
            ? Border.all(color: Colors.white, width: size * 0.09)
            : null,
        boxShadow: onMap
            ? const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(spot.icon, color: Colors.white, size: size * 0.55),
    );
  }
}
