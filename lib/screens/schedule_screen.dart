import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

class Schedule {
  String id;
  String name;
  TimeOfDay time;
  bool enabled;
  List<int> days; // 1=Mon, 7=Sun
  String action; // 'water', 'nutrient', 'notify'
  int duration; // seconds

  Schedule({
    required this.id,
    required this.name,
    required this.time,
    required this.enabled,
    required this.days,
    required this.action,
    required this.duration,
  });
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final NotificationService _notificationService = NotificationService();
  
  List<Schedule> _schedules = [
    Schedule(
      id: '1',
      name: 'Morning Water',
      time: const TimeOfDay(hour: 6, minute: 0),
      enabled: true,
      days: [1, 2, 3, 4, 5, 6, 7],
      action: 'water',
      duration: 300,
    ),
    Schedule(
      id: '2',
      name: 'Evening Nutrient',
      time: const TimeOfDay(hour: 18, minute: 0),
      enabled: true,
      days: [1, 3, 5],
      action: 'nutrient',
      duration: 180,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _schedules.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _schedules.length,
                        itemBuilder: (context, index) {
                          return _buildScheduleCard(_schedules[index], index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewSchedule,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Add Schedule'),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Text(
            'Schedules',
            style: AppTheme.headingStyle,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showScheduleInfo,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Schedule schedule, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          // Header
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getActionColor(schedule.action).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getActionIcon(schedule.action),
                color: _getActionColor(schedule.action),
              ),
            ),
            title: Text(
              schedule.name,
              style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
            ),
            subtitle: Text(
              '${schedule.time.format(context)} • ${schedule.duration}s',
              style: AppTheme.bodyStyle.copyWith(fontSize: 12),
            ),
            trailing: Transform.scale(
              scale: 0.9,
              child: Switch(
                value: schedule.enabled,
                onChanged: (value) {
                  setState(() {
                    schedule.enabled = value;
                  });
                  _saveSchedules();
                },
                activeColor: AppTheme.successColor,
              ),
            ),
          ),
          
          // Days selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final isSelected = schedule.days.contains(dayNum);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        schedule.days.remove(dayNum);
                      } else {
                        schedule.days.add(dayNum);
                      }
                    });
                    _saveSchedules();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editSchedule(schedule),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteSchedule(index),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerColor,
                      side: BorderSide(color: AppTheme.dangerColor.withOpacity(0.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 80,
            color: AppTheme.textSecondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Schedules Yet',
            style: AppTheme.subheadingStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Create automated schedules for watering\nand nutrient dosing',
            textAlign: TextAlign.center,
            style: AppTheme.bodyStyle,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _addNewSchedule,
            icon: const Icon(Icons.add),
            label: const Text('Add First Schedule'),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'water':
        return Icons.water;
      case 'nutrient':
        return Icons.local_drink;
      case 'notify':
        return Icons.notifications;
      default:
        return Icons.schedule;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'water':
        return AppTheme.primaryColor;
      case 'nutrient':
        return AppTheme.secondaryColor;
      case 'notify':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  void _addNewSchedule() {
    showDialog(
      context: context,
      builder: (context) => _ScheduleDialog(
        onSave: (schedule) {
          setState(() {
            _schedules.add(schedule);
          });
          _saveSchedules();
        },
      ),
    );
  }

  void _editSchedule(Schedule schedule) {
    showDialog(
      context: context,
      builder: (context) => _ScheduleDialog(
        schedule: schedule,
        onSave: (updated) {
          setState(() {
            final index = _schedules.indexWhere((s) => s.id == schedule.id);
            if (index != -1) {
              _schedules[index] = updated;
            }
          });
          _saveSchedules();
        },
      ),
    );
  }

  void _deleteSchedule(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Schedule?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _schedules.removeAt(index);
              });
              _saveSchedules();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showScheduleInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Text('Schedule Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem('📅', 'Select days when schedule is active'),
            _buildInfoItem('⏰', 'Set exact time for automation'),
            _buildInfoItem('💧', 'Choose action: Water, Nutrient, or Notify'),
            _buildInfoItem('⏱️', 'Set duration for pump operation'),
            _buildInfoItem('🔔', 'Receive notifications when schedule runs'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyStyle.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _saveSchedules() {
    // TODO: Save to SharedPreferences
    _notificationService.showCustomNotification(
      'Schedule Updated',
      'Your schedules have been saved successfully',
    );
  }
}

// Dialog for adding/editing schedule
class _ScheduleDialog extends StatefulWidget {
  final Schedule? schedule;
  final Function(Schedule) onSave;

  const _ScheduleDialog({
    this.schedule,
    required this.onSave,
  });

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late TextEditingController _nameController;
  late TimeOfDay _selectedTime;
  late String _selectedAction;
  late int _duration;
  late List<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.schedule?.name ?? 'New Schedule',
    );
    _selectedTime = widget.schedule?.time ?? const TimeOfDay(hour: 8, minute: 0);
    _selectedAction = widget.schedule?.action ?? 'water';
    _duration = widget.schedule?.duration ?? 300;
    _selectedDays = widget.schedule?.days ?? [1, 2, 3, 4, 5, 6, 7];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: Text(widget.schedule == null ? 'New Schedule' : 'Edit Schedule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Schedule Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Time'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) {
                  setState(() {
                    _selectedTime = time;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedAction,
              decoration: const InputDecoration(
                labelText: 'Action',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'water', child: Text('💧 Water Pump')),
                DropdownMenuItem(value: 'nutrient', child: Text('🥤 Nutrient Pump')),
                DropdownMenuItem(value: 'notify', child: Text('🔔 Notification Only')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Duration (seconds)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _duration.toString()),
              onChanged: (value) {
                _duration = int.tryParse(value) ?? 300;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final schedule = Schedule(
              id: widget.schedule?.id ?? DateTime.now().toString(),
              name: _nameController.text,
              time: _selectedTime,
              enabled: widget.schedule?.enabled ?? true,
              days: _selectedDays,
              action: _selectedAction,
              duration: _duration,
            );
            widget.onSave(schedule);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}