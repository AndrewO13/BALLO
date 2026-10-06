import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
}

/// Hides the keyboard now and again after focus restoration on the route below.
void dismissKeyboardAfterFrame() {
  dismissKeyboard();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    dismissKeyboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      dismissKeyboard();
    });
  });
}
