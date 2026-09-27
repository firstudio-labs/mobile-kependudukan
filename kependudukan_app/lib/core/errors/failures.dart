import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final List properties;

  String get message;

  const Failure([this.properties = const <dynamic>[]]);

  @override
  List<Object> get props => [properties];
}

class ServerFailure extends Failure {
  @override
  final String message;

  ServerFailure({required this.message}) : super([message]);

  @override
  List<Object> get props => [message];
}

class CacheFailure extends Failure {
  @override
  final String message;

  CacheFailure({required this.message}) : super([message]);

  @override
  List<Object> get props => [message];
}

class AuthFailure extends Failure {
  @override
  final String message;

  AuthFailure({required this.message}) : super([message]);

  @override
  List<Object> get props => [message];
}

class DatabaseFailure extends Failure {
  @override
  final String message;

  DatabaseFailure({required this.message}) : super([message]);

  @override
  List<Object> get props => [message];
}

class AuthenticationFailure extends Failure {
  @override
  final String message;

  AuthenticationFailure({required this.message}) : super([message]);

  @override
  List<Object> get props => [message];
}

class NetworkFailure extends Failure {
  @override
  final String message;

  NetworkFailure({required this.message}) : super([message]);

  @override
  List<Object> get props => [message];
}
