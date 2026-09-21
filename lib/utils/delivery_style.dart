import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Returns (label, color, icon) styling for a delivery status value.
(String, Color, IconData) deliveryStatusStyle(String status) {
  switch (status) {
    case 'dispatched':
      return ('Dispatched', const Color(0xFF4A90E2), Icons.local_shipping_rounded);
    case 'delivered':
      return ('Delivered', AppTheme.success, Icons.check_circle_rounded);
    case 'returned':
      return ('Returned', AppTheme.danger, Icons.assignment_return_rounded);
    default:
      return ('Pending', AppTheme.warning, Icons.schedule_rounded);
  }
}
