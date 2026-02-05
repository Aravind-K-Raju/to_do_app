class DailyStats {
  final DateTime date;
  final int tasksCompleted;
  final int tasksPending; // Tasks due today that are not done
  final int studyMinutes;
  final double productivityScore;

  DailyStats({
    required this.date,
    required this.tasksCompleted,
    required this.tasksPending,
    required this.studyMinutes,
    required this.productivityScore,
  });
}
