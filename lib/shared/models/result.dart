import '../../core/errors/failures.dart' as failures;

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get data => this is Success<T> ? (this as Success<T>).value : null;
  failures.Failure? get failure => this is Failure<T> ? (this as Failure<T>).error : null;

  R when<R>({
    required R Function(T data) success,
    required R Function(failures.Failure failure) failure,
  }) {
    if (this is Success<T>) {
      return success((this as Success<T>).value);
    } else {
      return failure((this as Failure<T>).error);
    }
  }

  R? whenSuccess<R>(R Function(T data) success) {
    if (this is Success<T>) {
      return success((this as Success<T>).value);
    }
    return null;
  }

  R? whenFailure<R>(R Function(failures.Failure failure) failure) {
    if (this is Failure<T>) {
      return failure((this as Failure<T>).error);
    }
    return null;
  }

  Result<R> map<R>(R Function(T data) mapper) {
    if (this is Success<T>) {
      return Success(mapper((this as Success<T>).value));
    } else {
      return Failure((this as Failure<T>).error);
    }
  }

  Future<Result<R>> asyncMap<R>(Future<R> Function(T data) mapper) async {
    if (this is Success<T>) {
      return Success(await mapper((this as Success<T>).value));
    } else {
      return Failure((this as Failure<T>).error);
    }
  }

  Result<R> flatMap<R>(Result<R> Function(T data) mapper) {
    if (this is Success<T>) {
      return mapper((this as Success<T>).value);
    } else {
      return Failure((this as Failure<T>).error);
    }
  }

  T getOrElse(T defaultValue) {
    if (this is Success<T>) {
      return (this as Success<T>).value;
    }
    return defaultValue;
  }

  T? getOrNull() {
    if (this is Success<T>) {
      return (this as Success<T>).value;
    }
    return null;
  }
}

class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Success<T> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

class Failure<T> extends Result<T> {
  final failures.Failure error;

  const Failure(this.error);

  @override
  String toString() => 'Failure(${error.message})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure<T> && other.error == error;
  }

  @override
  int get hashCode => error.hashCode;
}
