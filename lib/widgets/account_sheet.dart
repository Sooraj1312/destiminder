import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, CloudSyncService>(
      builder: (context, auth, sync, _) {
        final theme = Theme.of(context);

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!auth.isAvailable)
                    _buildUnavailable(theme)
                  else if (!auth.isSignedIn)
                    _buildSignedOut(context, auth, theme)
                  else
                    _buildSignedIn(context, auth, sync, theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnavailable(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.outline),
        const SizedBox(height: 12),
        Text(
          'Cloud sync unavailable',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Firebase is not configured on this build. All your data still works locally on this device.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  Widget _buildSignedOut(
    BuildContext context,
    AuthService auth,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.cloud_sync_rounded, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          'Back up & sync',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in with Google to keep your destinations, tasks, and arrival history safe across devices. Until you sign in, everything stays on this phone.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 12),
          Text(
            auth.error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: auth.isBusy
              ? null
              : () async {
                  final success = await auth.signInWithGoogle();
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.pop(context);
                  } else if (auth.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(auth.error!),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
          icon: auth.isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login_rounded),
          label: Text(auth.isBusy ? 'Signing in...' : 'Continue with Google'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Continue without account'),
        ),
      ],
    );
  }

  Widget _buildSignedIn(
    BuildContext context,
    AuthService auth,
    CloudSyncService sync,
    ThemeData theme,
  ) {
    final photoUrl = auth.user?.photoURL;
    final name = auth.user?.displayName;
    final email = auth.user?.email ?? 'Signed in';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage:
                  photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Icon(Icons.person_rounded, color: theme.colorScheme.primary)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name == null || name.isEmpty ? 'Google account' : name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.sync_rounded, color: theme.colorScheme.primary),
          title: const Text('Sync now'),
          subtitle: Text(
            sync.isSyncing
                ? 'Syncing...'
                : sync.lastSync == null
                    ? 'Not synced yet'
                    : 'Last sync: ${DateFormat.yMMMd().add_jm().format(sync.lastSync!.toLocal())}',
          ),
          trailing: sync.isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right_rounded),
          onTap: sync.isSyncing ? null : () => sync.syncNow(),
        ),
        if (sync.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              sync.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Sign out'),
          subtitle: const Text('Local data stays on this device'),
          onTap: auth.isBusy
              ? null
              : () async {
                  await auth.signOut();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.delete_forever_rounded,
            color: theme.colorScheme.error,
          ),
          title: Text(
            'Delete account & cloud data',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          subtitle: const Text('Local data stays on this device'),
          onTap: auth.isBusy ? null : () => _confirmDelete(context, auth),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, AuthService auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This removes your cloud backup and deletes your sign-in. Local data on this device stays. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await auth.deleteAccount();
    if (!context.mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account and cloud data deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
