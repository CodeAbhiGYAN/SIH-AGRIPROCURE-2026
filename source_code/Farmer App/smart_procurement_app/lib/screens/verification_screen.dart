import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/localization_service.dart';
import '../widgets/common.dart';

class _BankAccountResult {
  final String bank;
  final String account;
  final String confirmAccount;
  final String ifsc;

  const _BankAccountResult({
    required this.bank,
    required this.account,
    required this.confirmAccount,
    required this.ifsc,
  });
}

class _BankAccountDialog extends StatefulWidget {
  final String farmerName;
  final String initialBank;
  final String initialAccount;
  final String initialConfirmAccount;
  final String initialIfsc;
  final List<String> banks;
  final List<String> moreBanks;
  final String language;

  const _BankAccountDialog({
    required this.farmerName,
    required this.initialBank,
    required this.initialAccount,
    required this.initialConfirmAccount,
    required this.initialIfsc,
    required this.banks,
    required this.moreBanks,
    required this.language,
  });

  @override
  State<_BankAccountDialog> createState() => _BankAccountDialogState();
}

class _BankAccountDialogState extends State<_BankAccountDialog> {
  late final TextEditingController _accountController;
  late final TextEditingController _confirmController;
  late final TextEditingController _ifscController;
  final _formKey = GlobalKey<FormState>();
  late String _bank;

  @override
  void initState() {
    super.initState();
    _bank = widget.initialBank;
    _accountController = TextEditingController(text: widget.initialAccount);
    _confirmController = TextEditingController(text: widget.initialConfirmAccount);
    _ifscController = TextEditingController(text: widget.initialIfsc);
  }

  @override
  void dispose() {
    _accountController.dispose();
    _confirmController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _openMoreBanks() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
             Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                FarmerLocalizer.text('English', 'more_banks'), 
                style: TextStyle(
                  fontSize: 20,
                   fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ...widget.moreBanks.map(
              (bank) => ListTile(
                title: Text(bank),
                onTap: () => Navigator.pop(sheetContext, bank),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _bank = selected);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.pop(
      context,
      _BankAccountResult(
        bank: _bank,
        account: _accountController.text.trim(),
        confirmAccount: _confirmController.text.trim(),
        ifsc: _ifscController.text.trim().toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(FarmerLocalizer.text(widget.language, 'bank_details')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(FarmerLocalizer.text(widget.language, 'bank_details_sub')),
                const SizedBox(height: 16),
                Text('Account holder: ${widget.farmerName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _bank.isEmpty ? null : _bank,
                  decoration: InputDecoration(labelText: FarmerLocalizer.text(widget.language, 'bank_name')),
                  items: [
                    ...widget.banks.map((bank) => DropdownMenuItem(value: bank, child: Text(bank))),
                    const DropdownMenuItem(
                      value: '__more__',
                      child: Text('... More options'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == '__more__') {
                      _openMoreBanks();
                    } else if (value != null) {
                      setState(() => _bank = value);
                    }
                  },
                  validator: (_) => _bank.isEmpty ? 'Select your bank' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: FarmerLocalizer.text(widget.language, 'account_number')),
                  maxLength: 18,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (!RegExp(r'^\d{9,18}$').hasMatch(v)) return 'Enter a valid account number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _confirmController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: FarmerLocalizer.text(widget.language, 'confirm_account_number')),
                  maxLength: 18,
                  validator: (value) {
                    if (value != _accountController.text) return 'Account numbers do not match';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _ifscController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')), _UpperCaseTextFormatter()],
                  decoration: InputDecoration(labelText: FarmerLocalizer.text(widget.language, 'ifsc_code')),
                  maxLength: 11,
                  validator: (value) {
                    final v = value?.trim().toUpperCase() ?? '';
                    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v)) return 'Enter a valid 11-character IFSC';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(FarmerLocalizer.text(widget.language, 'cancel'))),
        FilledButton(onPressed: _submit, child: Text(FarmerLocalizer.text(widget.language, 'confirm_bank'))),
      ],
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(text: upper, selection: TextSelection.collapsed(offset: upper.length));
  }
}

class _CropDetailsResult {
  final String crop;
  final String quantity;
  final String season;

  const _CropDetailsResult({
    required this.crop,
    required this.quantity,
    required this.season,
  });
}

class _CropDetailsDialog extends StatefulWidget {
  final String language;
  final String initialCrop;
  final String initialQuantity;
  final String initialSeason;

  const _CropDetailsDialog({
    required this.language,
    required this.initialCrop,
    required this.initialQuantity,
    required this.initialSeason,
  });

  @override
  State<_CropDetailsDialog> createState() => _CropDetailsDialogState();
}

class _CropDetailsDialogState extends State<_CropDetailsDialog> {
  late String _crop;
  late String _season;
  late final TextEditingController _quantityController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _crop = widget.initialCrop;
    _season = widget.initialSeason;
    _quantityController = TextEditingController(text: widget.initialQuantity);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.pop(
      context,
      _CropDetailsResult(
        crop: _crop,
        quantity: _quantityController.text.trim(),
        season: _season,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(FarmerLocalizer.text(widget.language, 'crop_details')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _crop,
                decoration: InputDecoration(labelText: FarmerLocalizer.text(widget.language, 'crop')),
                items: const [
                  DropdownMenuItem(value: 'Wheat', child: Text('Wheat')),
                  DropdownMenuItem(value: 'Paddy', child: Text('Paddy')),
                  DropdownMenuItem(value: 'Mustard', child: Text('Mustard')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _crop = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: FarmerLocalizer.text(widget.language, 'expected_quantity')),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter the expected quantity';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _season,
                decoration: InputDecoration(labelText: FarmerLocalizer.text(widget.language, 'season')),
                items: const [
                  DropdownMenuItem(value: 'Rabi', child: Text('Rabi')),
                  DropdownMenuItem(value: 'Kharif', child: Text('Kharif')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _season = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(FarmerLocalizer.text(widget.language, 'cancel'))),
        FilledButton(onPressed: _submit, child: Text(FarmerLocalizer.text(widget.language, 'confirm_crop'))),
      ],
    );
  }
}

class VerificationScreen extends StatefulWidget {
  final AppState state;
  const VerificationScreen({super.key, required this.state});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  int stepIndex = 0;

  static const stages = ['Identity', 'Land Record', 'Bank Account', 'Crop', 'Eligibility'];
  static const banks = [
    'State Bank of India',
    'Punjab National Bank',
    'Bank of Baroda',
    'HDFC Bank',
    'ICICI Bank',
  ];
  static const moreBanks = [
    'Canara Bank',
    'Union Bank of India',
    'Indian Bank',
    'Bank of India',
    'Axis Bank',
    'Kotak Mahindra Bank',
    'Punjab & Sind Bank',
  ];

  @override
  void initState() {
    super.initState();
    _syncStep();
  }

  void _syncStep() {
    final completed = widget.state.verificationCompleted;
    if (completed.isEmpty) {
      stepIndex = 0;
      return;
    }
    final firstPending = stages.indexWhere((s) => !completed.contains(s));
    stepIndex = firstPending == -1 ? stages.length - 1 : firstPending;
  }

  Future<void> _markComplete(String stage) async {
    await widget.state.markVerificationComplete(stage);
    if (mounted) setState(() => _syncStep());
  }

  Future<void> _openStage(String stage) async {
    if (stage != stages[_activeStageIndex()]) {
      return;
    }

    switch (stage) {
      case 'Identity':
        await _identityDialog();
        break;
      case 'Land Record':
        await _landDialog();
        break;
      case 'Bank Account':
        await _bankDialog();
        break;
      case 'Crop':
        await _cropDialog();
        break;
      case 'Eligibility':
        await _eligibilityDialog();
        break;
    }
  }

  int _activeStageIndex() {
    final completed = widget.state.verificationCompleted;
    final index = stages.indexWhere((s) => !completed.contains(s));
    return index == -1 ? stages.length - 1 : index;
  }

  Future<void> _identityDialog() async {
    final farmer = widget.state.farmer;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.state.t('identity_verification')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.state.t('identity_retrieved')),
            const SizedBox(height: 18),
            _detailRow(widget.state.t('name'), farmer.name),
            const SizedBox(height: 10),
            _detailRow(widget.state.t('mobile_number'), _maskMobile(farmer.mobile)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(widget.state.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(widget.state.t('continue'))),
        ],
      ),
    );
    if (confirmed == true && mounted) _markComplete('Identity');
  }

  Future<void> _landDialog() async {
    final farmer = widget.state.farmer;
    final khasra = 'K-48${farmer.id.substring(1)}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.state.t('land_record')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.state.t('land_records_found')),
            const SizedBox(height: 18),
            _detailRow(widget.state.t('village'), farmer.village),
            const SizedBox(height: 8),
            _detailRow(widget.state.t('district'), 'South West Delhi'),
            const SizedBox(height: 8),
            _detailRow(widget.state.t('land_area'), '${farmer.cultivatedArea.toStringAsFixed(1)} acres'),
            const SizedBox(height: 8),
            _detailRow(widget.state.t('khasra'), khasra),
            const SizedBox(height: 8),
            _detailRow(widget.state.t('land_status'), widget.state.t('registered')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(widget.state.t('land_issue_help'))),
              );
            },
            child: Text(widget.state.t('report_issue')),
          ),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(widget.state.t('yes_confirm'))),
        ],
      ),
    );
    if (confirmed == true && mounted) _markComplete('Land Record');
  }

  Future<void> _bankDialog() async {
    final result = await showDialog<_BankAccountResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _BankAccountDialog(
        farmerName: widget.state.farmer.name,
        initialBank: widget.state.bankName,
        initialAccount: widget.state.bankAccount,
        initialConfirmAccount: widget.state.bankConfirmAccount,
        initialIfsc: widget.state.bankIfsc,
        banks: banks,
        moreBanks: moreBanks,
        language: widget.state.language,
      ),
    );

    // The dialog owns and disposes its controllers. Only update the parent
    // state after showDialog has fully completed and the dialog route is gone.
    if (result != null && mounted) {
      await widget.state.saveBankDetails(
        result.bank,
        result.account,
        result.confirmAccount,
        result.ifsc,
      );
      _markComplete('Bank Account');
    }
  }

  Future<void> _cropDialog() async {
    final farmer = widget.state.farmer;
    final result = await showDialog<_CropDetailsResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CropDetailsDialog(
        language: widget.state.language,
        initialCrop: widget.state.selectedCrop.isEmpty ? farmer.crop : widget.state.selectedCrop,
        initialQuantity: widget.state.cropQuantity,
        initialSeason: widget.state.cropSeason.isEmpty ? 'Rabi' : widget.state.cropSeason,
      ),
    );

    if (result != null && mounted) {
      await widget.state.saveCropDetails(result.crop, result.quantity, result.season);
      await _markComplete('Crop');
    }
  }

  Future<void> _eligibilityDialog() async {
    final complete = widget.state.verificationCompleted;
    final allInputsReady = complete.containsAll(const ['Identity', 'Land Record', 'Bank Account', 'Crop']);
    if (!allInputsReady) return;

    bool checking = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (checking) {
              Future<void>.delayed(const Duration(milliseconds: 900), () {
                if (dialogContext.mounted) setDialogState(() => checking = false);
              });
            }
            return AlertDialog(
              title: Text(widget.state.t('eligibility_check')),
              content: checking
                  ? SizedBox(
                      height: 90,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(widget.state.t('checking_records')),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.state.t('identity')} ✓'),
                        Text('${widget.state.t('land_record')} ✓'),
                        Text('${widget.state.t('bank_account')} ✓'),
                        Text('${widget.state.t('crop')} ✓'),
                        const SizedBox(height: 12),
                        Text(widget.state.t('eligible_for_procurement'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
              actions: [
                if (!checking) FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(widget.state.t('complete_verification'))),
              ],
            );
          },
        );
      },
    );
    if (result == true && mounted) {
      await _markComplete('Eligibility');
      await widget.state.completeVerification();
    }
  }

  String _stageLabel(AppState state, String stage) {
    switch (stage) {
      case 'Identity': return state.t('identity');
      case 'Land Record': return state.t('land_record');
      case 'Bank Account': return state.t('bank_account');
      case 'Crop': return state.t('crop');
      case 'Eligibility': return state.t('eligibility');
      default: return stage;
    }
  }

  Widget _detailRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 145, child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      );

  String _maskMobile(String value) {
    if (value.length < 4) return value;
    return '••••••${value.substring(value.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.state.verificationCompleted;
    final allComplete = completed.length == stages.length;
    final activeIndex = _activeStageIndex();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.state.t('verification'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          allComplete
              ? widget.state.t('all_verification_complete')
              : widget.state.t('verification_review'),
        ),
        const SizedBox(height: 18),
        ...List.generate(stages.length, (index) {
          final stage = stages[index];
          final done = completed.contains(stage);
          final active = !done && index == activeIndex;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(done ? Icons.check_circle : active ? Icons.play_circle_fill : Icons.radio_button_unchecked, color: done ? Colors.green : active ? Colors.blue : Colors.grey),
              title: Text(_stageLabel(widget.state, stage), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(done ? widget.state.t('verified') : active ? widget.state.t('action_required') : widget.state.t('complete_previous_step')),
              trailing: done
                  ? StatusChip(widget.state.t('verified'), good: true)
                  : active
                      ? const Icon(Icons.chevron_right)
                      : null,
              onTap: active ? () => _openStage(stage) : null,
            ),
          );
        }),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: completed.length / stages.length, minHeight: 9),
        const SizedBox(height: 14),
        if (allComplete) ...[
          StatusChip(widget.state.t('verification_complete'), good: true),
          const SizedBox(height: 12),
          InfoCard(
            title: widget.state.t('appointment'),
            icon: Icons.calendar_month,
            child: Text(widget.state.appointmentAssigned
                ? widget.state.t('appointment_confirmed_text')
                : widget.state.t('appointment_arranging_text')),
          ),
        ] else
          BigAction(
            text: '${widget.state.t('continue')} ${_stageLabel(widget.state, stages[activeIndex])}',
            icon: Icons.arrow_forward,
            onTap: () => _openStage(stages[activeIndex]),
          ),
      ],
    );
  }
}
