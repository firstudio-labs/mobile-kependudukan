import 'package:equatable/equatable.dart';
import 'package:ladimas/data/models/document_model.dart';

abstract class DocumentState extends Equatable {
  const DocumentState();

  @override
  List<Object?> get props => [];
}

class DocumentInitial extends DocumentState {}

class DocumentLoading extends DocumentState {}

class DocumentLoaded extends DocumentState {
  final FamilyMemberDocuments documents;

  const DocumentLoaded({required this.documents});

  @override
  List<Object?> get props => [documents];
}

class DocumentError extends DocumentState {
  final String message;

  const DocumentError({required this.message});

  @override
  List<Object?> get props => [message];
}

class DocumentUploading extends DocumentState {}

class DocumentUploaded extends DocumentState {
  final DocumentModel document;

  const DocumentUploaded({required this.document});

  @override
  List<Object?> get props => [document];
}

// Add new states for document deletion
class DocumentDeleting extends DocumentState {}

class DocumentDeleted extends DocumentState {}
