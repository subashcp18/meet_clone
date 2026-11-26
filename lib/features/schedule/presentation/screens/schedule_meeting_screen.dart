import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../data/models/schedule_meeting_request.dart';
import '../../providers/schedule_provider.dart';

class ScheduleMeetingScreen extends ConsumerStatefulWidget {
  const ScheduleMeetingScreen({super.key});

  @override
  ConsumerState<ScheduleMeetingScreen> createState() =>
      _ScheduleMeetingScreenState();
}

class _ScheduleMeetingScreenState extends ConsumerState<ScheduleMeetingScreen> {
  // region: CONTROLLERS & STATE
  static const List<int> _durations = [15, 30, 45, 60, 90];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _guestController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  int _durationMinutes = 30;
  final List<String> _invitees = <String>[];
  String? _guestError;

  @override
  void initState() {
    super.initState();
    final nextHour = DateTime.now().add(const Duration(hours: 1));
    _selectedDate = DateTime(nextHour.year, nextHour.month, nextHour.day);
    _selectedTime = TimeOfDay(hour: nextHour.hour, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _guestController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  // endregion

  // region: ACTIONS
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  void _addGuest() {
    final email = _guestController.text.trim();
    final validationError = Validators.email(email);
    if (validationError != null) {
      setState(() => _guestError = validationError);
      return;
    }
    if (_invitees.contains(email)) {
      setState(() => _guestError = 'Guest is already invited');
      return;
    }
    setState(() {
      _invitees.add(email);
      _guestController.clear();
      _guestError = null;
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final startTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final notes = _notesController.text.trim();

    final meeting = await ref
        .read(scheduleControllerProvider.notifier)
        .submit(
          ScheduleMeetingRequest(
            title: _titleController.text.trim(),
            startTime: startTime,
            durationMinutes: _durationMinutes,
            invitees: List<String>.unmodifiable(_invitees),
            notes: notes.isEmpty ? null : notes,
          ),
        );

    if (!mounted || meeting == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Scheduled "${meeting.title}"')),
      );
    context.pop();
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(scheduleControllerProvider);
    final colors = context.colors;
    final textStyles = context.textStyles;
    final combinedStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule meeting'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: scheduleState.isSubmitting ? null : _submit,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      enabled: !scheduleState.isSubmitting,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          Validators.requiredField(value, label: 'Meeting title'),
                      decoration: const InputDecoration(
                        labelText: 'Meeting title',
                        hintText: 'Weekly sync, design review...',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            onTap: scheduleState.isSubmitting ? null : _pickDate,
                            leading: const Icon(Icons.calendar_today_outlined),
                            title: const Text('Date'),
                            trailing: Text(
                              Formatters.formatFullDate(combinedStart),
                              style: textStyles.labelLarge.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            onTap: scheduleState.isSubmitting ? null : _pickTime,
                            leading: const Icon(Icons.access_time_rounded),
                            title: const Text('Start time'),
                            trailing: Text(
                              Formatters.formatTime(combinedStart),
                              style: textStyles.labelLarge.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Duration',
                      style: textStyles.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final minutes in _durations)
                          ChoiceChip(
                            label: Text('$minutes min'),
                            selected: _durationMinutes == minutes,
                            onSelected: scheduleState.isSubmitting
                                ? null
                                : (_) =>
                                    setState(() => _durationMinutes = minutes),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Invite guests',
                      style: textStyles.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _guestController,
                            enabled: !scheduleState.isSubmitting,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addGuest(),
                            onChanged: (_) {
                              if (_guestError != null) {
                                setState(() => _guestError = null);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'guest@example.com',
                              prefixIcon: const Icon(
                                Icons.person_add_alt_1_outlined,
                              ),
                              errorText: _guestError,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: scheduleState.isSubmitting
                                ? null
                                : _addGuest,
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_invitees.isEmpty)
                      Text(
                        'No guests added yet.',
                        style: textStyles.caption,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final email in _invitees)
                            InputChip(
                              label: Text(email),
                              onDeleted: scheduleState.isSubmitting
                                  ? null
                                  : () => setState(() => _invitees.remove(email)),
                            ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _notesController,
                      enabled: !scheduleState.isSubmitting,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'Add agenda or meeting notes',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (scheduleState.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      AppErrorBanner(message: scheduleState.errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    AppPrimaryButton(
                      label: 'Schedule meeting',
                      icon: Icons.event_available_rounded,
                      isLoading: scheduleState.isSubmitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  // endregion
}
