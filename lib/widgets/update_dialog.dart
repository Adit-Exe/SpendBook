import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../screens/update_screen.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App icon
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/app_icon.png',
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Update Available',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A new version (${updateInfo.versionName}) is available.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      actions: [
        Row(
          children: [
            // Later button
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: OutlinedButton(
                  onPressed: updateInfo.isForceUpdate
                      ? null
                      : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: updateInfo.isForceUpdate
                          ? theme.colorScheme.outline.withValues(alpha: 0.3)
                          : primaryColor,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Later',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: updateInfo.isForceUpdate
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                          : primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            // Update Now button
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UpdateScreen(updateInfo: updateInfo),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Update Now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
