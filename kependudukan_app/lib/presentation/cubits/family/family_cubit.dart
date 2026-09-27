import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ladimas/data/models/family_member_model.dart';
import 'package:ladimas/domain/repositories/family_repository.dart';

part 'family_state.dart';

class FamilyCubit extends Cubit<FamilyState> {
  final FamilyRepository repository;
  static const int pageSize = 10; // Number of items per page

  FamilyCubit({required this.repository}) : super(FamilyInitial());

  Future<void> loadFamilyMembers(String kk, {bool forceRefresh = false}) async {
    if (state is FamilyLoading) return;

    emit(FamilyLoading(
        currentMembers:
            state is FamilyLoaded ? (state as FamilyLoaded).members : []));

    final result =
        await repository.getFamilyMembers(kk, forceRefresh: forceRefresh);

    result.fold((failure) => emit(FamilyError(message: failure.message)),
        (members) {
      if (members.isEmpty) {
        emit(FamilyEmpty());
      } else {
        final initialMembers = members.take(pageSize).toList();
        final hasMore = members.length > pageSize;

        emit(FamilyLoaded(
          members: initialMembers,
          allMembers: members,
          currentPage: 1,
          hasMorePages: hasMore,
        ));
      }
    });
  }

  void loadMoreMembers() {
    if (state is FamilyLoaded) {
      final currentState = state as FamilyLoaded;

      if (!currentState.hasMorePages) return;

      final nextPage = currentState.currentPage + 1;
      final startIndex = currentState.currentPage * pageSize;
      final endIndex = startIndex + pageSize;

      final nextPageItems =
          currentState.allMembers.skip(startIndex).take(pageSize).toList();

      if (nextPageItems.isNotEmpty) {
        final newMembers = [...currentState.members, ...nextPageItems];
        final hasMore = endIndex < currentState.allMembers.length;

        emit(FamilyLoaded(
          members: newMembers,
          allMembers: currentState.allMembers,
          currentPage: nextPage,
          hasMorePages: hasMore,
        ));
      }
    }
  }

  void clearCache() {
    repository.clearCache();
  }
}
