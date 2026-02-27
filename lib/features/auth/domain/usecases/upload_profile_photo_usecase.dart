import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';
import 'package:psga_app/features/auth/domain/repositories/auth_repository.dart';

/// حالة استخدام رفع صورة الملف الشخصي مع ضغط تلقائي
class UploadProfilePhotoUseCase {
  final AuthRepository repository;

  UploadProfilePhotoUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call(File imageFile) async {
    AppLogger.info('[UploadProfilePhotoUseCase] محاولة رفع صورة الملف الشخصي');

    // التحقق من وجود الملف
    if (!imageFile.existsSync()) {
      AppLogger.warning('[UploadProfilePhotoUseCase] الملف غير موجود');
      return const Left(ValidationFailure('الملف غير موجود'));
    }

    // التحقق من حجم الملف الأصلي
    final originalSize = imageFile.lengthSync();
    AppLogger.info('[UploadProfilePhotoUseCase] حجم الملف الأصلي: ${(originalSize / 1024).toStringAsFixed(2)} KB');

    // التحقق من نوع الملف
    final extension = path.extension(imageFile.path).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension)) {
      AppLogger.warning('[UploadProfilePhotoUseCase] نوع ملف غير مدعوم: $extension');
      return const Left(ValidationFailure('نوع الملف غير مدعوم. استخدم: jpg, png, gif, webp'));
    }

    File fileToUpload = imageFile;

    // ضغط الصورة إذا كانت أكبر من 500 KB
    if (originalSize > 500 * 1024) {
      AppLogger.info('[UploadProfilePhotoUseCase] جاري ضغط الصورة...');
      
      try {
        final compressedFile = await _compressImage(imageFile);
        if (compressedFile != null) {
          final compressedSize = compressedFile.lengthSync();
          AppLogger.success(
            '[UploadProfilePhotoUseCase] تم ضغط الصورة: ${(compressedSize / 1024).toStringAsFixed(2)} KB '
            '(توفير ${((1 - compressedSize / originalSize) * 100).toStringAsFixed(1)}%)'
          );
          fileToUpload = compressedFile;
        }
      } catch (e) {
        AppLogger.warning('[UploadProfilePhotoUseCase] فشل الضغط، سيتم استخدام الصورة الأصلية', e);
      }
    }

    // التحقق من الحجم النهائي
    final finalSize = fileToUpload.lengthSync();
    if (finalSize > 5 * 1024 * 1024) {
      AppLogger.warning('[UploadProfilePhotoUseCase] حجم الملف كبير جداً: $finalSize bytes');
      return const Left(ValidationFailure('حجم الصورة يجب أن يكون أقل من 5 ميجا'));
    }

    // استدعاء المستودع
    AppLogger.info('[UploadProfilePhotoUseCase] جاري رفع الصورة...');
    final result = await repository.uploadProfilePhoto(fileToUpload);

    result.fold(
      (failure) => AppLogger.error('[UploadProfilePhotoUseCase] فشل رفع الصورة', failure.message),
      (user) => AppLogger.success('[UploadProfilePhotoUseCase] تم رفع الصورة بنجاح'),
    );

    return result;
  }

  /// ضغط الصورة لتقليل الحجم
  Future<File?> _compressImage(File file) async {
    try {
      // الحصول على مجلد temporary
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // ضغط الصورة
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // جودة 70% - توازن جيد بين الحجم والجودة
        minWidth: 800, // عرض أقصى 800 بكسل
        minHeight: 800, // ارتفاع أقصى 800 بكسل
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        return null;
      }

      return File(compressedFile.path);
    } catch (e) {
      AppLogger.error('[UploadProfilePhotoUseCase] خطأ في ضغط الصورة', e);
      return null;
    }
  }
}
