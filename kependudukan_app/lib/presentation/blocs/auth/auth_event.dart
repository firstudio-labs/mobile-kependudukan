import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginPendudukEvent extends AuthEvent {
  final String nik;
  final String password;

  const LoginPendudukEvent({required this.nik, required this.password});

  @override
  List<Object?> get props => [nik, password];
}

class RegisterPendudukEvent extends AuthEvent {
  final String nik;
  final String password;
  final String confirmPassword;
  final String noHp;

  const RegisterPendudukEvent({
    required this.nik,
    required this.password,
    required this.confirmPassword,
    required this.noHp,
  });

  @override
  List<Object?> get props => [nik, password, confirmPassword, noHp];
}

class CheckNikEvent extends AuthEvent {
  final String nik;

  const CheckNikEvent({required this.nik});

  @override
  List<Object?> get props => [nik];
}

class LogoutEvent extends AuthEvent {}

class AutoLoginEvent extends AuthEvent {}

class LoginAdminEvent extends AuthEvent {
  final String nikOrUsername;
  final String password;

  const LoginAdminEvent({required this.nikOrUsername, required this.password});

  @override
  List<Object?> get props => [nikOrUsername, password];
}
