import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/utils/logger.dart';

/// صفحة قص الصورة
class ImageCropHelper {
  /// قص الصورة
  static Future<File?> cropImage(File imageFile, BuildContext context) async {
    try {
      AppLogger.info('[ImageCrop] بدء قص الصورة');

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // مربع
        compressQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          // إعدادات Android
          AndroidUiSettings(
            toolbarTitle: 'قص الصورة',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: AppColors.primary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true, // قفل النسبة المربعة
            hideBottomControls: false,
            showCropGrid: true,
          ),
          // إعدادات iOS
          IOSUiSettings(
            title: 'قص الصورة',
            cancelButtonTitle: 'إلغاء',
            doneButtonTitle: 'تم',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) {
        AppLogger.info('[ImageCrop] تم إلغاء القص');
        return null;
      }

      final croppedImageFile = File(croppedFile.path);
      AppLogger.success('[ImageCrop] تم قص الصورة بنجاح');
      
      return croppedImageFile;
    } catch (e, stackTrace) {
      AppLogger.error('[ImageCrop] فشل قص الصورة', e, stackTrace);
      return null;
    }
  }

  /// قص الصورة مع خيارات متعددة
  static Future<File?> cropImageWithOptions({
    required File imageFile,
    required BuildContext context,
    bool lockAspectRatio = true,
    CropAspectRatioPreset initialAspectRatio = CropAspectRatioPreset.square,
  }) async {
    try {
      AppLogger.info('[ImageCrop] بدء قص الصورة مع خيارات متعددة');

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        compressQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'قص الصورة',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: AppColors.primary,
            initAspectRatio: initialAspectRatio,
            lockAspectRatio: lockAspectRatio,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'قص الصورة',
            cancelButtonTitle: 'إلغاء',
            doneButtonTitle: 'تم',
            aspectRatioLockEnabled: lockAspectRatio,
          ),
        ],
      );

      if (croppedFile == null) {
        AppLogger.info('[ImageCrop] تم إلغاء القص');
        return null;
      }

      final croppedImageFile = File(croppedFile.path);
      AppLogger.success('[ImageCrop] تم قص الصورة بنجاح');
      
      return croppedImageFile;
    } catch (e, stackTrace) {
      AppLogger.error('[ImageCrop] فشل قص الصورة', e, stackTrace);
      return null;
    }
  }
}
