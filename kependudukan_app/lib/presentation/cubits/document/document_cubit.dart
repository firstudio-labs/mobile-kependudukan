import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/domain/repositories/family_repository.dart';
import 'package:ladimas/presentation/cubits/document/document_state.dart';

class DocumentCubit extends Cubit<DocumentState> {
  final FamilyRepository repository;

  DocumentCubit({required this.repository}) : super(DocumentInitial());

  Future<void> loadFamilyMemberDocuments(String nik,
      {bool forceRefresh = false}) async {
    emit(DocumentLoading());

    final result = await repository.getFamilyMemberDocuments(nik,
        forceRefresh: forceRefresh);

    result.fold(
      (failure) => emit(DocumentError(message: failure.message)),
      (documents) => emit(DocumentLoaded(documents: documents)),
    );
  }

  Future<void> uploadDocument(
      String nik, String documentType, File file) async {
    emit(DocumentUploading());

    final result =
        await repository.uploadFamilyMemberDocument(nik, documentType, file);

    result.fold(
      (failure) => emit(DocumentError(message: failure.message)),
      (document) => emit(DocumentUploaded(document: document)),
    );

    // Reload documents after upload with forceRefresh = true
    await loadFamilyMemberDocuments(nik, forceRefresh: true);
  }

  Future<void> deleteDocument(String nik, String documentType) async {
    emit(DocumentDeleting());

    final result =
        await repository.deleteFamilyMemberDocument(nik, documentType);

    result.fold((failure) => emit(DocumentError(message: failure.message)),
        (success) => emit(DocumentDeleted()));

    // Reload documents after deletion with forceRefresh = true
    await loadFamilyMemberDocuments(nik, forceRefresh: true);
  }
}
