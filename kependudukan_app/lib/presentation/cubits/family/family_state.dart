part of 'family_cubit.dart';

abstract class FamilyState extends Equatable {
  const FamilyState();

  @override
  List<Object> get props => [];
}

class FamilyInitial extends FamilyState {}

class FamilyLoading extends FamilyState {
  final List<FamilyMemberModel> currentMembers;

  const FamilyLoading({this.currentMembers = const []});

  @override
  List<Object> get props => [currentMembers];
}

class FamilyLoaded extends FamilyState {
  final List<FamilyMemberModel> members;
  final List<FamilyMemberModel> allMembers;
  final int currentPage;
  final bool hasMorePages;

  const FamilyLoaded({
    required this.members,
    required this.allMembers,
    required this.currentPage,
    required this.hasMorePages,
  });

  @override
  List<Object> get props => [members, allMembers, currentPage, hasMorePages];
}

class FamilyEmpty extends FamilyState {}

class FamilyError extends FamilyState {
  final String message;

  const FamilyError({required this.message});

  @override
  List<Object> get props => [message];
}
