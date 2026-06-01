import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/core/services/notification_service.dart';
import 'package:secure_notepad/presentation/providers/notes_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remindersAsync = ref.watch(remindersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reminders',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600),
        ),
      ),
      body: remindersAsync.when(
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm_off_rounded,
                      size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No reminders yet',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to add a reminder',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          final reminders = snapshot.docs;
          final now = DateTime.now();

          final upcoming = reminders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final scheduledAt =
                (data['scheduledAt'] as Timestamp?)?.toDate();
            return scheduledAt != null && scheduledAt.isAfter(now);
          }).toList();

          final past = reminders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final scheduledAt =
                (data['scheduledAt'] as Timestamp?)?.toDate();
            return scheduledAt != null &&
                scheduledAt.isBefore(now) &&
                !(data['isCompleted'] ?? false);
          }).toList();

          final completed = reminders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isCompleted'] ?? false;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (upcoming.isNotEmpty) ...[
                _sectionHeader('Upcoming', AppTheme.primary, isDark),
                ...upcoming.map((doc) => _reminderTile(doc, isDark)),
                const SizedBox(height: 16),
              ],
              if (past.isNotEmpty) ...[
                _sectionHeader('Past', Colors.orange, isDark),
                ...past.map((doc) => _reminderTile(doc, isDark)),
                const SizedBox(height: 16),
              ],
              if (completed.isNotEmpty) ...[
                _sectionHeader('Completed', Colors.grey, isDark),
                ...completed.map((doc) => _reminderTile(doc, isDark)),
              ],
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReminderSheet(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add_alarm_rounded, color: Colors.white),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textLight : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderTile(DocumentSnapshot doc, bool isDark) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? '';
    final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate();
    final isPast = scheduledAt != null && scheduledAt.isBefore(DateTime.now());

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        final id = (scheduledAt?.millisecondsSinceEpoch ?? 0) ~/ 1000;
        NotificationService.cancelReminder(id);
        ref.read(notesRepositoryProvider).deleteReminder(doc.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(
            isPast ? Icons.check_circle_outline : Icons.alarm_rounded,
            color: isPast ? Colors.grey : AppTheme.primary,
          ),
          title: Text(
            title,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textLight : AppTheme.textDark,
            ),
          ),
          subtitle: scheduledAt != null
              ? Text(
                  DateFormat('MMM d, yyyy - h:mm a').format(scheduledAt),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade400,
                  ),
                )
              : null,
          trailing: isPast
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Past',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                )
              : null,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context) {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark =
              Theme.of(context).brightness == Brightness.dark;
          final canSave = titleController.text.trim().isNotEmpty &&
              selectedDate != null &&
              selectedTime != null;

          return Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20,
                MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add Reminder',
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? AppTheme.textLight : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Reminder title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setSheetState(() => selectedDate = date);
                          }
                        },
                        icon: const Icon(Icons.calendar_today_rounded,
                            size: 18),
                        label: Text(selectedDate != null
                            ? DateFormat('MMM d, yyyy')
                                .format(selectedDate!)
                            : 'Pick Date'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setSheetState(() => selectedTime = time);
                          }
                        },
                        icon:
                            const Icon(Icons.access_time_rounded, size: 18),
                        label: Text(selectedTime != null
                            ? selectedTime!.format(context)
                            : 'Pick Time'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canSave
                        ? () async {
                            final dateTime = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              selectedTime!.hour,
                              selectedTime!.minute,
                            );

                            if (dateTime.isBefore(DateTime.now())) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please pick a future time'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            final repo =
                                ref.read(notesRepositoryProvider);
                            await repo.addReminder({
                              'title': titleController.text.trim(),
                              'scheduledAt':
                                  Timestamp.fromDate(dateTime),
                              'isCompleted': false,
                              'createdAt':
                                  FieldValue.serverTimestamp(),
                            });

                            await NotificationService.scheduleReminder(
                              id: dateTime.millisecondsSinceEpoch ~/
                                  1000,
                              title: titleController.text.trim(),
                              body:
                                  'Reminder: ${titleController.text.trim()}',
                              scheduledDate: dateTime,
                            );

                            if (ctx.mounted) Navigator.pop(ctx);

                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(
                                    'Reminder set for ${DateFormat('MMM d').format(dateTime)} at ${selectedTime!.format(context)}'),
                                backgroundColor: AppTheme.primary,
                              ));
                            }
                          }
                        : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Save Reminder'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
