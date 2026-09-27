import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/data/models/document_model.dart';
import 'package:ladimas/data/models/family_member_model.dart';

abstract class FamilyRepository {
  Future<Either<Failure, List<FamilyMemberModel>>> getFamilyMembers(String kk,
      {bool forceRefresh = false});
  Future<Either<Failure, bool>> updateFamilyMemberCoordinate(
      String nik, String coordinate);
  Future<Either<Failure, FamilyMemberDocuments>> getFamilyMemberDocuments(
      String nik,
      {bool forceRefresh = false});
  Future<Either<Failure, DocumentModel>> uploadFamilyMemberDocument(
    String nik,
    String documentType,
    File file,
  );
  // Add new method for document deletion
  Future<Either<Failure, bool>> deleteFamilyMemberDocument(
    String nik,
    String documentType,
  );
  void clearCache();
}
