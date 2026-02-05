import 'package:equatable/equatable.dart';

class CourseCertificate extends Equatable {
  final int? id;
  final int courseId;
  final String certificatePath;
  final DateTime dateEarned;

  const CourseCertificate({
    this.id,
    required this.courseId,
    required this.certificatePath,
    required this.dateEarned,
  });

  @override
  List<Object?> get props => [id, courseId, certificatePath, dateEarned];
}
