import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/core/utils/validators.dart';
import 'package:psga_app/features/auth/domain/entities/user_entity.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/shared/widgets/custom_button.dart';
import 'package:psga_app/shared/widgets/custom_text_field.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';
import 'package:psga_app/shared/helpers/image_crop_helper.dart';


/// صفحة الملف الشخصي
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isEditing = false;
  final ImagePicker _imagePicker = ImagePicker();
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// رفع صورة الملف الشخصي مع crop و progress
  Future<void> _uploadProfilePhoto() async {
    try {
      // عرض خيارات الكاميرا أو المعرض
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      // اختيار الصورة
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      // قص الصورة
      File imageFile = File(image.path);
      if (mounted) {
        final croppedFile = await ImageCropHelper.cropImage(imageFile, context);
        if (croppedFile == null) {
          // تم إلغاء القص
          return;
        }
        imageFile = croppedFile;
      }

      // تفعيل حالة الرفع
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      // رفع الصورة
      if (mounted) {
        context.read<AuthBloc>().add(
          UploadProfilePhotoRequested(imageFile: imageFile),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      if (mounted) {
        context.showErrorSnackBar(AppLocalizations.of(context)!.profilePhotoPickFailed);
      }
    }
  }

  /// عرض dialog لاختيار المصدر (الكاميرا أو المعرض)
  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.chooseImageSource),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
                title: Text(AppLocalizations.of(context)!.gallery),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
                title: Text(AppLocalizations.of(context)!.camera),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.profile),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            setState(() {
              _isUploading = false;
              _uploadProgress = 0.0;
            });
            context.showErrorSnackBar(state.message);
          } else if (state is ProfileUpdated) {
            // تحديث الحقول بالبيانات الجديدة
            _nameController.text = state.user.name;
            _phoneController.text = state.user.phoneNumber ?? '';
            
            setState(() {
              _isUploading = false;
              _uploadProgress = 0.0;
              _isEditing = false;
            });
            context.showSuccessSnackBar(AppLocalizations.of(context)!.profileUpdateSuccess);
          } else if (state is UploadingPhoto) {
            setState(() {
              _isUploading = true;
              _uploadProgress = state.progress;
            });
          }
        },
        buildWhen: (previous, current) {
          // إعادة بناء الواجهة عند:
          // 1. تسجيل الدخول/الخروج
          // 2. تحديث الملف الشخصي (لتحديث البيانات المعروضة)
          // تجاهل UploadingPhoto لأننا نعالجه في listener فقط
          if (current is UploadingPhoto) return false;
          
          return current is Authenticated || 
                 current is ProfileUpdated ||
                 current is AuthLoading || 
                 current is Unauthenticated;
        },
        builder: (context, state) {
          if (state is Unauthenticated) {
            // إعادة توجيه لصفحة تسجيل الدخول
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/login');
            });
            return const Center(child: CircularProgressIndicator());
          }
          
          // دعم كل من Authenticated و ProfileUpdated
          final UserEntity user;
          if (state is Authenticated) {
            user = state.user;
          } else if (state is ProfileUpdated) {
            user = state.user;
          } else {
            return const Center(child: CircularProgressIndicator());
          }

          // تهيئة القيم - فقط إذا كانت الحقول فارغة
          if (_nameController.text.isEmpty && _phoneController.text.isEmpty) {
            _nameController.text = user.name;
            _phoneController.text = user.phoneNumber ?? '';
          }

          return LoadingOverlay(
            isLoading: state is AuthLoading,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingLG),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // صورة الملف الشخصي
                    _buildProfileImage(user.photoUrl),

                    const SizedBox(height: AppDimensions.spacingXL),

                    // البريد الإلكتروني (غير قابل للتعديل)
                    _buildInfoCard(
                      icon: Icons.email,
                      title: AppLocalizations.of(context)!.profileEmailLabel,
                      value: user.email,
                      verified: user.emailVerified,
                    ),

                    const SizedBox(height: AppDimensions.spacingMD),

                    // الاسم
                    CustomTextField(
                      controller: _nameController,
                      label: AppLocalizations.of(context)!.profileNameLabel,
                      hint: AppLocalizations.of(context)!.profileNameHint,
                      prefixIcon:const Icon(Icons.person),
                      enabled: _isEditing,
                      validator: Validators.required,
                    ),

                    const SizedBox(height: AppDimensions.spacingMD),

                    // رقم الهاتف
                    CustomTextField(
                      controller: _phoneController,
                      label: AppLocalizations.of(context)!.profilePhoneLabel,
                      hint: AppLocalizations.of(context)!.profilePhoneHint,
                      prefixIcon:const Icon(Icons.phone),
                      keyboardType: TextInputType.phone,
                      enabled: _isEditing,
                      validator: Validators.phoneNumber,
                    ),

                    const SizedBox(height: AppDimensions.spacingMD),

                    // تاريخ الإنشاء
                    _buildInfoCard(
                      icon: Icons.calendar_today,
                      title: AppLocalizations.of(context)!.profileCreatedAt,
                      value: _formatDate(user.createdAt),
                    ),

                    const SizedBox(height: AppDimensions.spacingMD),

                    // آخر تسجيل دخول
                    if (user.lastLoginAt != null)
                      _buildInfoCard(
                        icon: Icons.access_time,
                        title: AppLocalizations.of(context)!.profileLastLogin,
                        value: _formatDate(user.lastLoginAt!),
                      ),

                    const SizedBox(height: AppDimensions.spacingXL),

                    // أزرار الحفظ والإلغاء
                    if (_isEditing) ...[
                      CustomButton(
                        onPressed: _saveProfile,
                        text: AppLocalizations.of(context)!.profileSaveChanges,
                      ),
                      const SizedBox(height: AppDimensions.spacingSM),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _nameController.text = user.name;
                            _phoneController.text = user.phoneNumber ?? '';
                          });
                        },
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileImage(String? photoUrl) {
    return Stack(
      children: [
        // الصورة مع placeholder وcaching
        CircleAvatar(
          radius: 60,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: photoUrl != null && photoUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    photoUrl,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      // عرض مؤشر تحميل أثناء تحميل الصورة
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // عرض أيقونة في حالة فشل التحميل
                      return Icon(
                        Icons.person,
                        size: 60,
                        color: Theme.of(context).colorScheme.primary,
                      );
                    },
                    // تمكين الcaching
                    cacheWidth: 240,
                    cacheHeight: 240,
                  ),
                )
              : Icon(
                  Icons.person,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
        ),
        
        // Progress Indicator أثناء الرفع
        if (_isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: _uploadProgress,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // زر تحرير الصورة
        if (_isEditing && !_isUploading)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: _uploadProfilePhoto,
                tooltip: AppLocalizations.of(context)!.changePhotoTooltip,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    bool verified = false,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: AppDimensions.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (verified)
                        const Icon(
                          Icons.verified,
                          color: AppColors.green,
                          size: 20,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            UpdateProfileRequested(
              name: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim().isNotEmpty
                  ? _phoneController.text.trim()
                  : null,
            ),
          );
    }
  }
}
