part of 'domisili_cubit.dart';

abstract class DomisiliState extends Equatable {
  const DomisiliState();

  @override
  List<Object?> get props => [];
}

class DomisiliInitial extends DomisiliState {}

class DomisiliLoading extends DomisiliState {}

class DomisiliLoaded extends DomisiliState {
  final FamilyMemberModel member;

  const DomisiliLoaded({required this.member});

  @override
  List<Object?> get props => [member];
}

class DomisiliUpdating extends DomisiliState {
  final FamilyMemberModel? member;

  const DomisiliUpdating({this.member});

  @override
  List<Object?> get props => [member];
}

class DomisiliError extends DomisiliState {
  final String message;

  const DomisiliError({required this.message});

  @override
  List<Object?> get props => [message];
}
