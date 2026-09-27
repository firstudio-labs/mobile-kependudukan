import 'package:equatable/equatable.dart';
import 'package:ladimas/domain/entities/penduduk.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class NikCheckLoading extends AuthState {}

class PendudukAuthenticated extends AuthState {
  final Penduduk penduduk;

  const PendudukAuthenticated({required this.penduduk});

  @override
  List<Object?> get props => [penduduk];
}

class AdminAuthenticated extends AuthState {
  final Map<String, dynamic> adminData; // berisi user, role, token

  const AdminAuthenticated({required this.adminData});

  @override
  List<Object?> get props => [adminData];
}

class NikExists extends AuthState {
  final bool exists;

  const NikExists({required this.exists});

  @override
  List<Object?> get props => [exists];
}

class RegisterSuccess extends AuthState {}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}
