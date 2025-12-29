// ============================================================================
// 📄 ملف: routes_list_page.dart
// 🏗️ الطبقة: Presentation (قائمة المسارات)
// 🎯 الوظيفة: صفحة تعرض قائمة بجميع المسارات المحفوظة مع خيارات البحث والحذف والتعديل
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/routes.dart';
import '../../../../core/utils/logger.dart';
import '../bloc/route_bloc.dart';
import '../bloc/route_event.dart';
import '../bloc/route_state.dart';
import '../widgets/route_card.dart';
import '../../../../shared/widgets/loading_widget.dart';

/// 📌 صفحة قائمة المسارات
class RoutesListPage extends StatefulWidget {
  final String userId;

  const RoutesListPage({super.key, required this.userId});

  @override
  State<RoutesListPage> createState() => _RoutesListPageState();
}

class _RoutesListPageState extends State<RoutesListPage> {
  @override
  void initState() {
    super.initState();
    context.read<RouteBloc>().add(LoadRoutes(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المسارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
        ],
      ),
      body: BlocConsumer<RouteBloc, RouteState>(
        listener: (context, state) {
          if (state is RouteOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is RoutesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is RoutesLoading) {
            return const LoadingWidget();
          }

          if (state is RoutesLoaded) {
            if (state.filteredRoutes.isEmpty) {
              return _buildEmptyState(theme);
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<RouteBloc>().add(LoadRoutes(widget.userId));
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.filteredRoutes.length,
                itemBuilder: (context, index) {
                  final route = state.filteredRoutes[index];
                  return Dismissible(
                    key: Key(route.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await _showDeleteConfirmation(context);
                    },
                    onDismissed: (direction) {
                      context.read<RouteBloc>().add(DeleteRoute(
                            routeId: route.id,
                            userId: widget.userId,
                          ));
                    },
                    child: RouteCard(
                      route: route,
                      onTap: () => _navigateToDetails(context, route.id),
                      onLongPress: () => _showOptionsDialog(context, route),
                      onFavoriteToggle: () {
                        context.read<RouteBloc>().add(ToggleFavorite(route.id));
                      },
                    ),
                  );
                },
              ),
            );
          }

          return _buildEmptyState(theme);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreateRoute(context),
        icon: const Icon(Icons.add),
        label: const Text('مسار جديد'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route_outlined,
            size: 80,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مسارات',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف مسارك الأول للبدء',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String query = '';
        return AlertDialog(
          title: const Text('بحث في المسارات'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'ابحث باسم المسار...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => query = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                context.read<RouteBloc>().add(SearchRoutes(query));
                Navigator.pop(context);
              },
              child: const Text('بحث'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المسار'),
        content: const Text('هل أنت متأكد من حذف هذا المسار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showOptionsDialog(BuildContext context, dynamic route) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل'),
              onTap: () {
                Navigator.pop(context);
                AppLogger.info('[Routes] الانتقال لتعديل المسار: ${route.name}', name: 'Routes');
                context.push(AppRoutes.routeCreate, extra: route);
              },
            ),
            ListTile(
              leading: Icon(
                route.isFavorite ? Icons.star : Icons.star_border,
                color: route.isFavorite ? Colors.amber : null,
              ),
              title: Text(route.isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة'),
              onTap: () {
                context.read<RouteBloc>().add(ToggleFavorite(route.id));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await _showDeleteConfirmation(context);
                if (confirm == true && context.mounted) {
                  context.read<RouteBloc>().add(DeleteRoute(
                        routeId: route.id,
                        userId: widget.userId,
                      ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, String routeId) {
    AppLogger.info('[Routes] الانتقال إلى تفاصيل المسار: $routeId', name: 'Routes');
    final state = context.read<RouteBloc>().state;
    if (state is RoutesLoaded) {
      final route = state.routes.firstWhere(
        (r) => r.id == routeId,
        orElse: () => state.routes.first,
      );
      context.push(
        AppRoutes.routeDetails.replaceFirst(':id', routeId),
        extra: {'route': route},
      );
    }
  }

  void _navigateToCreateRoute(BuildContext context) {
    AppLogger.info('[Routes] الانتقال إلى إنشاء مسار جديد', name: 'Routes');
    context.push(AppRoutes.routeCreate);
  }
}
