import 'package:flutter/material.dart';
import '../main.dart';

class ProfileScreen extends StatelessWidget {
  final AppState state;
  const ProfileScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(state.t('profile_settings'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)),
              const SizedBox(height: 12),
              Center(child: Text(state.farmerName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(state.t('mobile')),
                subtitle: Text(state.farmerMobile),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(state.t('language')),
                subtitle: Text(state.language == 'Hindi' ? 'हिन्दी' : 'English'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _chooseLanguage(context),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(state.t('home_location')),
                subtitle: Text(state.t('home_location_sub')),
              ),
              ListTile(
                leading: const Icon(Icons.security),
                title: Text(state.t('app_security')),
                subtitle: Text(state.t('app_security_sub')),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: Text(state.t('help_support')),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () {
                  state.logout();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.logout),
                label: Text(state.t('log_out')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                state.t('choose_language'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            RadioListTile<String>(
              value: 'English',
              groupValue: state.language,
              title: const Text('English'),
              onChanged: (v) => Navigator.pop(sheetContext, v),
            ),
            RadioListTile<String>(
              value: 'Hindi',
              groupValue: state.language,
              title: const Text('हिन्दी'),
              onChanged: (v) => Navigator.pop(sheetContext, v),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) state.setLanguage(selected);
  }
}
