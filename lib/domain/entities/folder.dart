import 'package:equatable/equatable.dart';

class Folder extends Equatable {
  final int? id;
  final String name;
  final int? parentId;
  final DateTime createdAt;

  const Folder({
    this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, parentId, createdAt];
}
