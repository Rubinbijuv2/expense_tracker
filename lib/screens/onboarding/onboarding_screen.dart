import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/detected_sms_provider.dart';
import '../../providers/settings_provider.dart';
import 'setup_pages.dart';

/// First launch only: 3 intro pages, then name + budget, PIN (twice),
/// optional fingerprint and the SMS permission page.
///
/// Nothing is saved until the last page, so if the app is closed half-way
/// the user simply starts onboarding again next time.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // A PageController moves the PageView to a page from code (Next / Back).
  final _pages = PageController();
  int _page = 0;

  String _name = '';
  int? _budgetPaise;
  String? _pin;
  bool _fingerprint = false;
  bool _saving = false;

  static const _intro = [
    (
      icon: Icons.account_balance_wallet_outlined,
      title: 'Track every rupee',
      text: 'Add expenses and income in seconds and see where your money goes.',
    ),
    (
      icon: Icons.sms_outlined,
      title: 'Bank SMS, done for you',
      text: 'Bank and UPI SMS are turned into suggested transactions. '
          'You just tap Save.',
    ),
    (
      icon: Icons.savings_outlined,
      title: 'Stay within budget',
      text: 'Set a monthly budget and get an alert at 80% and 100%. '
          'Everything stays on your phone.',
    ),
  ];

  void _next() {
    FocusScope.of(context).unfocus();
    _pages.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _back() {
    _pages.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _finish({required bool allowSms}) async {
    if (_saving || _pin == null) return;
    setState(() => _saving = true);
    final settings = context.read<SettingsProvider>();
    final lock = context.read<AppLockProvider>();
    final budgets = context.read<BudgetProvider>();
    final dash = context.read<DashboardProvider>();
    final detected = context.read<DetectedSmsProvider>();
    try {
      await settings.setName(_name);
      if (_budgetPaise != null) {
        await budgets.setLimit(null, _budgetPaise!); // this month, overall
        await dash.loadBudget();
      }
      await lock.savePin(_pin!);
      await lock.setFingerprintEnabled(_fingerprint);
      // Home must not ask about SMS again — this page already did.
      await detected.markPermissionAsked();
      if (allowSms) await detected.requestPermission();
      // This swaps onboarding for the main app (see AppGate in main.dart).
      await settings.completeOnboarding();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope: the Android back button goes to the previous page
    // instead of closing the app (except on the first page).
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: PageView(
            controller: _pages,
            // Only the buttons move between pages, so a form can't be skipped.
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (var i = 0; i < _intro.length; i++)
                _IntroPage(
                  icon: _intro[i].icon,
                  title: _intro[i].title,
                  text: _intro[i].text,
                  index: i,
                  count: _intro.length,
                  onNext: _next,
                ),
              ProfilePage(
                onDone: (name, budgetPaise) {
                  _name = name;
                  _budgetPaise = budgetPaise;
                  _next();
                },
              ),
              PinSetupPage(
                onDone: (pin) {
                  _pin = pin;
                  _next();
                },
              ),
              FingerprintPage(
                onDone: (enabled) {
                  _fingerprint = enabled;
                  _next();
                },
              ),
              SmsPermissionPage(
                saving: _saving,
                onAllow: () => _finish(allowSms: true),
                onSkip: () => _finish(allowSms: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.icon,
    required this.title,
    required this.text,
    required this.index,
    required this.count,
    required this.onNext,
  });

  final IconData icon;
  final String title;
  final String text;
  final int index;
  final int count;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Spacer(),
          CircleAvatar(
            radius: 64,
            backgroundColor: scheme.primaryContainer,
            child: Icon(icon, size: 64, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 32),
          Text(title,
              style: textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(text,
              style: textTheme.bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                Container(
                  margin: const EdgeInsets.all(4),
                  width: i == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == index ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              child: Text(index == count - 1 ? 'Get started' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }
}
