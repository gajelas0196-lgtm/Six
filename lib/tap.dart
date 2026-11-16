import 'package:flutter/material.dart';

/// Efek tap dinonaktifkan — hanya meneruskan child.
class GlobalTouchWrapper extends StatelessWidget {
  final Widget child;

  const GlobalTouchWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
