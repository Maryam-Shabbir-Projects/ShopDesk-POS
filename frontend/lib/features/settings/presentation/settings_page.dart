import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopdesk/core/constants/app_constants.dart';
import 'package:shopdesk/core/utils/formatters.dart';
import 'package:shopdesk/features/auth/application/auth_controller.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late String _code;
  late final TextEditingController _tax;
  late final TextEditingController _shop;
  late final TextEditingController _footer;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _code = s.currencyCode;
    _tax = TextEditingController(text: Fmt.number(s.taxRate));
    _shop = TextEditingController(text: s.shopName);
    _footer = TextEditingController(text: s.receiptFooter);
  }

  @override
  void dispose() {
    _tax.dispose();
    _shop.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tax = (double.tryParse(_tax.text) ?? 0).clamp(0, 100).toDouble();
    await ref.read(settingsProvider.notifier).save(
          ref.read(settingsProvider).copyWith(
                currencyCode: _code,
                taxRate: tax,
                shopName: _shop.text.trim().isEmpty ? AppConstants.appName : _shop.text.trim(),
                receiptFooter: _footer.text.trim(),
              ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_outlined, size: 36),
              title: Text(user.email),
              subtitle: Text(user.role.label),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
            const Divider(height: 32),
          ],
          TextField(controller: _shop, decoration: const InputDecoration(labelText: 'Shop name (shown on receipts)')),
          const SizedBox(height: 16),
          DropdownMenu<String>(
            initialSelection: _code,
            label: const Text('Currency'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final c in AppConstants.currencies)
                DropdownMenuEntry(value: c.code, label: '${c.code} (${c.symbol.trim()})'),
            ],
            onSelected: (v) => setState(() => _code = v ?? _code),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tax,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Default tax rate (%)'),
          ),
          const SizedBox(height: 16),
          TextField(controller: _footer, decoration: const InputDecoration(labelText: 'Receipt footer')),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save settings')),
        ],
      ),
    );
  }
}
