// lib/widgets/language_selection_dialog.dart

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/language_service.dart';
import '../utils/constants.dart';

class LanguageSelectionDialog extends StatelessWidget {
  const LanguageSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLanguage = LanguageService.instance.getCurrentLanguageCode();
    
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.selectLanguage),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Radio<String>(
              value: 'en',
              groupValue: currentLanguage,
              onChanged: (value) async {
                if (value != null) {
                  await _changeLanguage(context, value);
                }
              },
            ),
            title: Text(AppLocalizations.of(context)!.english),
            onTap: () async {
              await _changeLanguage(context, 'en');
            },
          ),
          ListTile(
            leading: Radio<String>(
              value: 'ar',
              groupValue: currentLanguage,
              onChanged: (value) async {
                if (value != null) {
                  await _changeLanguage(context, value);
                }
              },
            ),
            title: Text(AppLocalizations.of(context)!.arabic),
            onTap: () async {
              await _changeLanguage(context, 'ar');
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
      ],
    );
  }

  Future<void> _changeLanguage(BuildContext context, String languageCode) async {
    try {
      // Save language preference
      final success = await LanguageService.instance.setLanguage(languageCode);
      
      if (success) {
        // Update app locale immediately if callback is available
        if (globalLocaleChangeCallback != null) {
          globalLocaleChangeCallback!(Locale(languageCode));
        }
        
        // Close dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        
        // Show success message
        if (context.mounted) {
          context.showSnackBar(AppLocalizations.of(context)!.languageChanged);
        }
      } else {
        // Show error message
        if (context.mounted) {
          context.showSnackBar(
            AppLocalizations.of(context)!.unexpectedError,
            isError: true,
          );
        }
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        context.showSnackBar(
          AppLocalizations.of(context)!.unexpectedError,
          isError: true,
        );
      }
    }
  }
}

// Helper function to show language selection dialog
void showLanguageSelectionDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const LanguageSelectionDialog(),
  );
}