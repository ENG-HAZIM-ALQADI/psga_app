import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:psga_app/features/auth/domain/usecases/change_password_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/login_with_apple_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/login_with_google_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/send_email_verification_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:psga_app/features/auth/domain/usecases/upload_profile_photo_usecase.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:psga_app/core/services/data_sync_service.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';

/// BLoC إدارة حالة المصادقة
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final ResetPasswordUseCase resetPasswordUseCase;
  final SendEmailVerificationUseCase sendEmailVerificationUseCase;
  final UpdateProfileUseCase updateProfileUseCase;
  final UploadProfilePhotoUseCase uploadProfilePhotoUseCase;
  final ChangePasswordUseCase changePasswordUseCase;
  final DeleteAccountUseCase deleteAccountUseCase;
  final LoginWithGoogleUseCase loginWithGoogleUseCase;
  final LoginWithAppleUseCase loginWithAppleUseCase;
  final AuthRepository repository; // للوصول إلى uploadProgress stream
  
  StreamSubscription<double>? _uploadProgressSubscription;

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
    required this.resetPasswordUseCase,
    required this.sendEmailVerificationUseCase,
    required this.updateProfileUseCase,
    required this.uploadProfilePhotoUseCase,
    required this.changePasswordUseCase,
    required this.deleteAccountUseCase,
    required this.loginWithGoogleUseCase,
    required this.loginWithAppleUseCase,
    required this.repository,
  }) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
    on<SendEmailVerificationRequested>(_onSendEmailVerificationRequested);
    on<UpdateProfileRequested>(_onUpdateProfileRequested);
    on<UploadProfilePhotoRequested>(_onUploadProfilePhotoRequested);
    on<ChangePasswordRequested>(_onChangePasswordRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);
    on<LoginWithGoogleRequested>(_onLoginWithGoogleRequested);
    on<LoginWithAppleRequested>(_onLoginWithAppleRequested);
    on<UploadProgressUpdated>(_onUploadProgressUpdated);
    
    // الاستماع لـ upload progress
    _setupUploadProgressListener();
  }
  
  /// إعداد الاستماع لتقدم رفع الصورة
  void _setupUploadProgressListener() {
    _uploadProgressSubscription = repository.uploadProgress.listen((progress) {
      add(UploadProgressUpdated(progress));
    });
  }
  
  /// معالجة تحديث تقدم رفع الصورة
  Future<void> _onUploadProgressUpdated(
    UploadProgressUpdated event,
    Emitter<AuthState> emit,
  ) async {
    emit(UploadingPhoto(event.progress));
  }
  
  @override
  Future<void> close() {
    _uploadProgressSubscription?.cancel();
    return super.close();
  }

  /// التحقق من حالة المصادقة
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] التحقق من حالة المصادقة');
    emit(const AuthLoading());

    final result = await getCurrentUserUseCase();

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل التحقق من حالة المصادقة', failure.message);
        emit(const Unauthenticated());
      },
      (user) {
        if (user != null) {
          AppLogger.success('[AuthBloc] المستخدم مسجل دخول: \${user.email}');
          emit(Authenticated(user));
          // ✅ تحديث البيانات من السيرفر عند فتح التطبيق (عمد: لا ننتظرها)
          // ignore: unawaited_futures
        DataSyncService.instance.pullAllUserData(user.id);
        } else {
          AppLogger.info('[AuthBloc] المستخدم غير مسجل دخول');
          emit(const Unauthenticated());
        }
      },
    );
  }

  /// تسجيل الدخول
  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة تسجيل الدخول');
    emit(const AuthLoading());

    final result = await loginUseCase(
      email: event.email,
      password: event.password,
    );

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل تسجيل الدخول', failure.message);
        emit(AuthError(failure.message));
      },
      (user) {
        AppLogger.success('[AuthBloc] تم تسجيل الدخول بنجاح');
        emit(Authenticated(user));
        // ✅ جلب جميع بيانات المستخدم من السيرفر للمحلي (عمد: لا ننتظرها)
        // ignore: unawaited_futures
        DataSyncService.instance.pullAllUserData(user.id);
      },
    );
  }

  /// تسجيل حساب جديد
  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة التسجيل');
    emit(const AuthLoading());

    final result = await registerUseCase(
      email: event.email,
      password: event.password,
      name: event.name,
    );

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل التسجيل', failure.message);
        emit(AuthError(failure.message));
      },
      (user) {
        AppLogger.success('[AuthBloc] تم التسجيل بنجاح');
        emit(Authenticated(user));
        // ✅ تهيئة بيانات المستخدم الجديد (عمد: لا ننتظرها)
        // ignore: unawaited_futures
        DataSyncService.instance.pullAllUserData(user.id);
      },
    );
  }

  /// تسجيل الخروج
  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة تسجيل الخروج');
    emit(const AuthLoading());

    final result = await logoutUseCase();

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل تسجيل الخروج', failure.message);
        emit(AuthError(failure.message));
      },
      (_) {
        AppLogger.success('[AuthBloc] تم تسجيل الخروج بنجاح');
        emit(const Unauthenticated());
      },
    );
  }

  /// إعادة تعيين كلمة المرور
  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة إعادة تعيين كلمة المرور');
    emit(const AuthLoading());

    final result = await resetPasswordUseCase(email: event.email);

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل إرسال رابط إعادة التعيين', failure.message);
        emit(AuthError(failure.message));
      },
      (_) {
        AppLogger.success('[AuthBloc] تم إرسال رابط إعادة التعيين بنجاح');
        emit(const AuthOperationSuccess(
          'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني',
        ));
      },
    );
  }

  /// إرسال رابط التحقق من البريد
  Future<void> _onSendEmailVerificationRequested(
    SendEmailVerificationRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة إرسال رابط التحقق');
    emit(const AuthLoading());

    final result = await sendEmailVerificationUseCase();

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل إرسال رابط التحقق', failure.message);
        emit(AuthError(failure.message));
      },
      (_) {
        AppLogger.success('[AuthBloc] تم إرسال رابط التحقق بنجاح');
        emit(const EmailVerificationSent());
      },
    );
  }

  /// تحديث الملف الشخصي
  Future<void> _onUpdateProfileRequested(
    UpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة تحديث الملف الشخصي');
    emit(const AuthLoading());

    final result = await updateProfileUseCase(
      name: event.name,
      photoUrl: event.photoUrl,
      phoneNumber: event.phoneNumber,
    );

    await result.fold(
      (failure) async {
        AppLogger.error('[AuthBloc] فشل تحديث الملف الشخصي', failure.message);
        emit(AuthError(failure.message));
      },
      (user) async {
        AppLogger.success('[AuthBloc] تم تحديث الملف الشخصي بنجاح');
        emit(ProfileUpdated(user));
        // تحويل إلى Authenticated بعد فترة قصيرة لضمان عرض الرسالة وتحديث UI
        await Future.delayed(const Duration(milliseconds: 100));
        emit(Authenticated(user));
      },
    );
  }

  /// رفع صورة الملف الشخصي
  Future<void> _onUploadProfilePhotoRequested(
    UploadProfilePhotoRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة رفع صورة الملف الشخصي');
    emit(const AuthLoading());

    final result = await uploadProfilePhotoUseCase(event.imageFile);

    await result.fold(
      (failure) async {
        AppLogger.error('[AuthBloc] فشل رفع الصورة', failure.message);
        emit(AuthError(failure.message));
      },
      (user) async {
        AppLogger.success('[AuthBloc] تم رفع الصورة بنجاح');
        emit(ProfileUpdated(user));
        // تحويل إلى Authenticated بعد فترة قصيرة
        await Future.delayed(const Duration(milliseconds: 100));
        emit(Authenticated(user));
      },
    );
  }

  /// تغيير كلمة المرور
  Future<void> _onChangePasswordRequested(
    ChangePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة تغيير كلمة المرور');
    emit(const AuthLoading());

    final result = await changePasswordUseCase(
      currentPassword: event.currentPassword,
      newPassword: event.newPassword,
    );

    await result.fold(
      (failure) async {
        AppLogger.error('[AuthBloc] فشل تغيير كلمة المرور', failure.message);
        emit(AuthError(failure.message));
      },
      (_) async {
        AppLogger.success('[AuthBloc] تم تغيير كلمة المرور بنجاح');
        emit(const PasswordChanged());
        
        // تسجيل الخروج التلقائي بعد تغيير كلمة المرور
        AppLogger.info('[AuthBloc] تسجيل خروج تلقائي بعد تغيير كلمة المرور');
        await Future.delayed(const Duration(milliseconds: 500)); // إعطاء وقت لعرض الرسالة
        final logoutResult = await logoutUseCase();
        logoutResult.fold(
          (failure) {
            AppLogger.error('[AuthBloc] فشل تسجيل الخروج التلقائي', failure.message);
            emit(const Unauthenticated()); // إجبار تسجيل الخروج حتى لو فشل
          },
          (_) {
            AppLogger.success('[AuthBloc] تم تسجيل الخروج التلقائي بنجاح');
            emit(const Unauthenticated());
          },
        );
      },
    );
  }

  /// حذف الحساب
  Future<void> _onDeleteAccountRequested(
    DeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة حذف الحساب');
    emit(const AuthLoading());

    final result = await deleteAccountUseCase();

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل حذف الحساب', failure.message);
        emit(AuthError(failure.message));
      },
      (_) {
        AppLogger.success('[AuthBloc] تم حذف الحساب بنجاح');
        emit(const Unauthenticated());
      },
    );
  }

  /// تسجيل الدخول بواسطة Google
  Future<void> _onLoginWithGoogleRequested(
    LoginWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة تسجيل الدخول بواسطة Google');
    emit(const AuthLoading());

    final result = await loginWithGoogleUseCase();

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل تسجيل الدخول بواسطة Google', failure.message);
        emit(AuthError(failure.message));
      },
      (user) {
        AppLogger.success('[AuthBloc] تم تسجيل الدخول بواسطة Google بنجاح');
        emit(Authenticated(user));
      },
    );
  }

  /// تسجيل الدخول بواسطة Apple
  Future<void> _onLoginWithAppleRequested(
    LoginWithAppleRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] محاولة تسجيل الدخول بواسطة Apple');
    emit(const AuthLoading());

    final result = await loginWithAppleUseCase();

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل تسجيل الدخول بواسطة Apple', failure.message);
        emit(AuthError(failure.message));
      },
      (user) {
        AppLogger.success('[AuthBloc] تم تسجيل الدخول بواسطة Apple بنجاح');
        emit(Authenticated(user));
      },
    );
  }
}
