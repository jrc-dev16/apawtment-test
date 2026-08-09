class ScheduleConfig {
  final int? id;
  final String type;
  final List<int> allowedWeekdays;
  final int defaultSlotsPerDay;
  final String defaultTimeStart;
  final String defaultTimeEnd;

  const ScheduleConfig({
    this.id,
    required this.type,
    required this.allowedWeekdays,
    required this.defaultSlotsPerDay,
    required this.defaultTimeStart,
    required this.defaultTimeEnd,
  });

  factory ScheduleConfig.fromMap(Map<String, dynamic> m) {
    final raw = m['allowed_weekdays'];
    List<int> days = [];
    if (raw is List) {
      days = raw.map((e) => int.parse(e.toString())).toList();
    } else if (raw is String && raw.isNotEmpty) {
      days =
          raw
              .split(',')
              .where((s) => s.trim().isNotEmpty)
              .map((s) => int.parse(s.trim()))
              .toList();
    }
    return ScheduleConfig(
      id: m['config_id'] as int?,
      type: m['type']?.toString() ?? 'adoption',
      allowedWeekdays: days,
      defaultSlotsPerDay:
          int.tryParse(m['default_slots_per_day']?.toString() ?? '2') ?? 2,
      defaultTimeStart: m['default_time_start']?.toString() ?? '9:00 AM',
      defaultTimeEnd: m['default_time_end']?.toString() ?? '5:00 PM',
    );
  }

  static ScheduleConfig defaultFor(String type) => ScheduleConfig(
    type: type,
    allowedWeekdays: type == 'adoption' ? [1, 3, 5] : [2, 4, 6],
    defaultSlotsPerDay: 2,
    defaultTimeStart: type == 'adoption' ? '9:00 AM' : '1:00 PM',
    defaultTimeEnd: type == 'adoption' ? '12:00 PM' : '5:00 PM',
  );
}
