import 'package:flutter/services.dart';

class DOBInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // If deleting allow it
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    // Remove all slashes to get raw digits
    final text = newValue.text.replaceAll('/', '');

    // Only allow digits
    final digitsOnly = RegExp(r'^\d*$');
    if (!digitsOnly.hasMatch(text)) {
      return oldValue;
    }

    // Max 8 digits (DD MM YYYY)
    if (text.length > 8) return oldValue;

    // Format as DD/MM/YYYY
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      // Add slash after day (position 2)
      if (i == 2) formatted += '/';
      // Add slash after month (position 4)
      if (i == 4) formatted += '/';
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }
}
