import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../firebase_options.dart';
import '../format.dart';
import '../state/auth_state.dart';
import '../support.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'plans_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: const Text('Log out?'),
        content: const Text('You will stop receiving signal notifications on this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      await context.read<AuthState>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final sub = auth.sub;
    final active = auth.subscribed;
    final planLabel = auth.isTrial ? 'Free trial' : (asS(sub['plan']).isEmpty ? 'No plan' : asS(sub['plan']));
    final statusColor = !active ? C.red : (auth.daysLeft <= 3 ? C.amber : C.green);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: PageBody(
      onRefresh: auth.refresh,
      children: [
        Panel(
          child: Row(children: [
            CircleAvatar(
              backgroundColor: C.accent.withAlpha(50),
              child: Text(auth.email.isEmpty ? '?' : auth.email[0].toUpperCase(),
                  style: const TextStyle(color: C.accent, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(auth.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.text, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SectionTitle('Subscription'),
        Panel(
          borderColor: statusColor.withAlpha(120),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(planLabel[0].toUpperCase() + planLabel.substring(1),
                  style: const TextStyle(color: C.text, fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              Pill(active ? 'ACTIVE' : 'INACTIVE', color: statusColor),
            ]),
            const SizedBox(height: 8),
            Text(
                active
                    ? '${auth.daysLeft} day${auth.daysLeft == 1 ? '' : 's'} left · valid until ${fmtDate(sub['expiry'])}'
                    : 'Live signals, stoploss updates and notifications are locked.',
                style: const TextStyle(color: C.muted)),
            if (AppConfig.canPurchaseInApp) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen())),
                child: Text(active ? (auth.isTrial ? 'Upgrade now' : 'Extend subscription') : 'Subscribe'),
              ),
            ],
          ]),
        ),
        const SectionTitle('Notifications'),
        Panel(
          child: Row(children: [
            Icon(FirebaseCfg.enabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                color: FirebaseCfg.enabled ? C.green : C.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  FirebaseCfg.enabled
                      ? 'You get an alert for every new signal, stoploss move and exit.'
                      : 'Push alerts are not enabled in this build.',
                  style: const TextStyle(color: C.text, fontSize: 13)),
            ),
          ]),
        ),
        const SectionTitle('Help & support'),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => contactSupport(accountEmail: auth.email),
          child: Panel(
            child: Row(children: [
              const Icon(Icons.mail_outline_rounded, color: C.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Contact support', style: T.body(13.5, w: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(AppConfig.supportEmail, style: T.mono(12, w: FontWeight.w400, color: C.gold)),
                  const SizedBox(height: 2),
                  Text('Payments, subscription or app problems — we reply by email.',
                      style: T.body(11.5, color: C.muted)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: C.dim),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: C.red),
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
        const Disclaimer(AppConfig.disclaimer),
      ],
    ),
      ),
    );
  }
}
