import 'package:flutter/material.dart';

class RouteUtils {
  static PageRoute createRoute(Widget page) {
    return MaterialPageRoute(
      builder: (context) => page,
    );
  }

  static PageRouteBuilder noAnimationRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}
