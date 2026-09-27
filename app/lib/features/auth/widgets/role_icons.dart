import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';

// Person icons for the three kinds of account, which Lucide doesn't have.
// From Hugeicons (free stroke-rounded set, MIT licence,
// https://hugeicons.com): "patient", "doctor-01" and "medicine-bottle-01".
const _patient =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M20 21.9999V18.9999C20 16.1715 20 14.7572 19.1213 13.8786C18.2426 12.9999 16.8284 12.9999 14 12.9999H10C7.17157 12.9999 5.75736 12.9999 4.87868 13.8786C4 14.7572 4 16.1715 4 18.9999C4 19.9318 4 20.3977 4.15224 20.7652C4.35523 21.2553 4.74458 21.6446 5.23463 21.8476C5.60218 21.9999 6.06812 21.9999 7 21.9999" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M9.5 12.9999L12.5 21.9999M7 13.4999V21.9999" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M12 18.9999H14.5C15.3284 18.9999 16 19.6715 16 20.4999C16 21.3283 15.3284 21.9999 14.5 21.9999H12.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M15.5 6.49997V5.49997C15.5 3.56697 13.933 1.99997 12 1.99997C10.067 1.99997 8.5 3.56697 8.5 5.49997V6.49997C8.5 8.43297 10.067 9.99997 12 9.99997C13.933 9.99997 15.5 8.43297 15.5 6.49997Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _doctor =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M20 22V19C20 16.1716 20 14.7574 19.1213 13.8787C18.2426 13 16.8284 13 14 13L12 15L10 13C7.17157 13 5.75736 13 4.87868 13.8787C4 14.7574 4 16.1716 4 19V22" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M16 13V18.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M8.5 13V17M8.5 17C9.60457 17 10.5 17.8954 10.5 19V20M8.5 17C7.39543 17 6.5 17.8954 6.5 19V20" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M15.5 6.5V5.5C15.5 3.567 13.933 2 12 2C10.067 2 8.5 3.567 8.5 5.5V6.5C8.5 8.433 10.067 10 12 10C13.933 10 15.5 8.433 15.5 6.5Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M16.75 19.25C16.75 19.6642 16.4142 20 16 20C15.5858 20 15.25 19.6642 15.25 19.25C15.25 18.8358 15.5858 18.5 16 18.5C16.4142 18.5 16.75 18.8358 16.75 19.25Z" stroke="currentColor" stroke-width="1.5"/>'
    '</svg>';

const _chemist =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M9.06845 2H14.9316C15.8529 2 16.3135 2 16.5997 2.29289C17.1334 2.83907 17.1334 5.16093 16.5997 5.70711C16.3135 6 15.8529 6 14.9316 6H9.06845C8.14715 6 7.6865 6 7.40029 5.70711C6.86657 5.16093 6.86657 2.83907 7.40029 2.29289C7.6865 2 8.14715 2 9.06845 2Z" stroke="currentColor" stroke-width="1.5"/>'
    '<path d="M8 6C8.16493 6.32986 8.24741 6.49481 8.30606 6.6557C8.61211 7.49515 8.52805 8.42732 8.07678 9.19848C7.99029 9.34628 7.87965 9.49381 7.65836 9.78885L7.25493 10.3268C6.80486 10.9269 6.57983 11.2269 6.41674 11.5556C6.252 11.8877 6.13421 12.241 6.06677 12.6055C6 12.9664 6 13.3414 6 14.0915V16C6 18.8284 6 20.2426 6.87868 21.1213C7.75736 22 9.17157 22 12 22C14.8284 22 16.2426 22 17.1213 21.1213C18 20.2426 18 18.8284 18 16V14.0915C18 13.3414 18 12.9664 17.9332 12.6055C17.8658 12.241 17.748 11.8877 17.5833 11.5556C17.4202 11.2269 17.1951 10.9269 16.7451 10.3268L16.3416 9.78885C16.1204 9.49381 16.0097 9.34628 15.9232 9.19848C15.4719 8.42732 15.3879 7.49515 15.6939 6.6557C15.7526 6.49481 15.8351 6.32987 16 6" stroke="currentColor" stroke-width="1.5"/>'
    '<path d="M12 13V18M9.5 15.5L14.5 15.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>'
    '</svg>';

/// The patient / doctor / chemist icon.
class RoleIcon extends StatelessWidget {
  const RoleIcon({
    super.key,
    required this.role,
    this.size = 28,
    this.color = AppColors.ink,
  });

  final UserRole role;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final svg = switch (role) {
      UserRole.patient => _patient,
      UserRole.doctor => _doctor,
      UserRole.chemist || UserRole.admin => _chemist,
    };
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
    );
  }
}
