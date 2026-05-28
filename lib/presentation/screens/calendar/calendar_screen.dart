import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/presentation/providers/notes_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Calendar',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddReminderSheet(context),
            icon: const Icon(Icons.add_alarm_rounded),
            tooltip: 'Add Reminder',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Calendar Widget ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
              ),
            ),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: GoogleFonts.dmSans(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                defaultTextStyle: GoogleFonts.dmSans(
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                ),
                weekendTextStyle: GoogleFonts.dmSans(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                outsideTextStyle: GoogleFonts.dmSans(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              headerStyle: HeaderStyle(
                titleTextStyle: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                ),
                formatButtonTextStyle: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.primary,
                ),
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                leftChevronIcon:
                    const Icon(Icons.chevron_left, color: AppTheme.primary),
                rightChevronIcon:
                    const Icon(Icons.chevron_right, color: AppTheme.primary),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                weekendStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Reminders Section ──
          Expanded(
            child: _buildRemindersList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersList(bool isDark) {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: ref.watch(notesRepositoryProvider).getReminders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final reminders = snapshot.data ?? [];

        if (reminders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none_rounded,
                    size: 64,
                    color:
                        isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No reminders',
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to add a reminder',
                  style: GoogleFonts.dmSans(
                    color:
                        isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        }

        // Group reminders by date
        final grouped = <String, List<QueryDocumentSnapshot>>{};
        for (final doc in reminders) {
          final data = doc.data() as Map<String, dynamic>;
          final scheduledAt =
              (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final dateKey =
              '${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year}';
          grouped.putIfAbsent(dateKey, () => []).add(doc);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final dateKey = grouped.keys.elementAt(index);
            final dayReminders = grouped[dateKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    dateKey,
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                ...dayReminders.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] ?? '';
                  final scheduledAt =
                      (data['scheduledAt'] as Timestamp?)?.toDate() ??
                          DateTime.now();
                  return _buildReminderTile(
                      doc.id, title, scheduledAt, isDark);
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReminderTile(
      String id, String title, DateTime scheduledAt, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.textLight : AppTheme.textDark,
                  ),
                ),
                Text(
                  '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(notesRepositoryProvider).completeReminder(id);
            },
            icon: const Icon(Icons.check_circle_outline_rounded,
                color: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context) {
    final titleController = TextEditingController();
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Reminder',
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Title',
                  prefixIcon: Icon(Icons.notification_important_rounded),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setSheetState(() => selectedDate = date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: GoogleFonts.dmSans(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          setSheetState(() => selectedTime = time);
                        }
                      },
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(
                        selectedTime.format(ctx),
                        style: GoogleFonts.dmSans(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty) {
                      final scheduledAt = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      ref.read(notesProvider.notifier).createReminder(
                            noteId: '',
                            title: titleController.text.trim(),
                            scheduledAt: scheduledAt,
                          );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reminder created')),
                      );
                    }
                  },
                  child: const Text('Create Reminder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
