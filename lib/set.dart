import 'package:flutter/material.dart';

class GlobalSettings {
  static final ValueNotifier<bool> isTouchEffectOn = ValueNotifier<bool>(true);
  
  static void toggleTouchEffect() {
    isTouchEffectOn.value = !isTouchEffectOn.value;
  }
}