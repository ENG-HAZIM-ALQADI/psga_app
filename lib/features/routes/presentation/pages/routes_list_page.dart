import 'package:flutter/material.dart';
import 'package:psga_app/app.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/presentation/bloc/bloc.dart';
import 'package:psga_app/features/routes/presentation/pages/create_route_page.dart';
import 'package:psga_app/features/routes/presentation/pages/route_detail_page.dart';
import 'package:psga_app/features/routes/presentation/widgets/route_card.dart';
import 'package:psga_app/shared/widgets/empty_state_widget.dart';
import 'package:psga_app/shared/widgets/error_widget.dart' as custom;
import 'package:psga_app/shared/widgets/loading_widget.dart';
import 'package:psga_app/shared/widgets/sync_indicator.dart';

/// صفحة قائمة المسارات
class RoutesListPage extends StatefulWidget {
  /// عند تقديم هذه الدالة، يظهر زر الرجوع في AppBar ويستدعيها عند الضغط
  final VoidCallback? onBack;
  
  const RoutesListPage({super.key, this.onBack});

  @override
  State<RoutesListPage> createState() => _RoutesListPageState();
}

class _RoutesListPageState extends State<RoutesListPage> with RouteAware {
  bool _hasLoaded = false;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ subscribe للـ RouteObserver بعد اكتمال البناء
    if (!_hasLoaded) {
      _hasLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final route = ModalRoute.of(context);
          if (route != null) {
            appRouteObserver.subscribe(this, route);
          }
          _reloadRoutes();
        }
      });
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _reloadRoutes() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<RoutesBloc>().add(LoadRoutesEvent(userId: authState.user.id));
    }
  }
  
  /// ✅ يُستدعى تلقائياً عند العودة من صفحة أخرى (مثل active_trip_page)
  @override
  void didPopNext() {
    super.didPopNext();
    AppLogger.info('[RoutesList] العودة من صفحة أخرى - تحديث قائمة المسارات');
    _reloadRoutes();
  }

  @override
  Widget build(BuildContext context) {
    // استخدام RoutesBloc الموجود بدلاً من إنشاء واحد جديد
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.routes),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: AppLocalizations.of(context)!.backTooltip,
              )
            : null,
        automaticallyImplyLeading: widget.onBack == null,
        actions: const [
          SyncIndicator(),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const _SearchBar(),
          const _FilterChips(),
          Expanded(
            child: BlocConsumer<RoutesBloc, RoutesState>(
              // ✅ إعادة البناء عند RoutesLoaded و RouteCreated لضمان التحديث الفوري
              buildWhen: (previous, current) {
                return current is RoutesLoaded ||
                    current is RoutesLoading ||
                    current is RoutesError ||
                    current is RouteCreated ||
                    current is RouteDeleted ||
                    current is RouteUpdated;
              },
              listener: (context, state) {
                // ✅ إعادة التحميل الفوري عند إنشاء مسار جديد
                if (state is RouteCreated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.routeCreated),
                      backgroundColor: AppColors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  // ✅ إعادة تحميل فورية لضمان ظهور المسار الجديد
                  _reloadRoutes();
                } else if (state is RouteDeleted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.routeDeleted),
                      backgroundColor: AppColors.green,
                    ),
                  );
                } else if (state is RoutesOperationError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is RoutesLoading) {
                  return LoadingWidget(
                    message: AppLocalizations.of(context)!.loadingRoutes,
                  );
                }

                if (state is RoutesError) {
                  return custom.ErrorDisplayWidget(
                    message: state.message,
                    onRetry: () {
                      final authState = context.read<AuthBloc>().state;
                      final userId = authState is Authenticated ? authState.user.id : '';
                      context.read<RoutesBloc>().add(LoadRoutesEvent(userId: userId));
                    },
                  );
                }

                if (state is RoutesLoaded) {
                  if (state.filteredRoutes.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.route,
                        message: state.searchQuery != null
                            ? AppLocalizations.of(context)!.noSearchRouteMsg
                            : AppLocalizations.of(context)!.noRoutesYetMsg,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        final authState = context.read<AuthBloc>().state;
                        final userId = authState is Authenticated ? authState.user.id : '';
                        context.read<RoutesBloc>().add(RefreshRoutesEvent(userId: userId));
                        await Future.delayed(const Duration(seconds: 1));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.filteredRoutes.length,
                        itemBuilder: (context, index) {
                          final route = state.filteredRoutes[index];
                          return RouteCard(
                            route: route,
                            onTap: () => _navigateToDetail(context, route.id),
                            onFavoriteToggle: () {
                              context.read<RoutesBloc>().add(
                                    ToggleFavoriteEvent(routeId: route.id),
                                  );
                            },
                          );
                        },
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'routes_list_fab',
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context)!.createRoute),
          onPressed: () => _navigateToCreateRoute(context),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
    );
  }

  void _navigateToCreateRoute(BuildContext context) async {
    final bloc = context.read<RoutesBloc>();
    if (!mounted) return;
    
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: const CreateRoutePage(),
        ),
      ),
    );
    // ✅ لا نُعيد التحميل هنا - الـ listener يتكفل بذلك عند RouteCreated
  }

  void _navigateToDetail(BuildContext context, String routeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<RoutesBloc>(),
          child: RouteDetailPage(routeId: routeId),
        ),
      ),
    );
  }
}

/// شريط البحث
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchRoutesHint,
          hintStyle: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          prefixIcon: Icon(Icons.search, color: Theme.of(context).textTheme.bodyMedium?.color),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).cardTheme.color
              : Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        onChanged: (query) {
          context.read<RoutesBloc>().add(SearchRoutesEvent(query: query));
        },
      ),
    );
  }
}

/// شرائح الفلترة
class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutesBloc, RoutesState>(
      builder: (context, state) {
        if (state is! RoutesLoaded) return const SizedBox.shrink();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: Text(AppLocalizations.of(context)!.allFilterLabel(state.totalCount.toString())),
                selected: state.statusFilter == null && state.favoriteFilter == null,
                onSelected: (_) {
                  context.read<RoutesBloc>().add(
                        const FilterRoutesEvent(),
                      );
                },
                selectedColor: AppColors.primary.withOpacity(0.2),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 16, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context)!.favoritesFilterLabel(state.favoriteCount.toString())),
                  ],
                ),
                selected: state.favoriteFilter == true,
                onSelected: (_) {
                  context.read<RoutesBloc>().add(
                        const FilterRoutesEvent(isFavorite: true),
                      );
                },
                selectedColor: AppColors.gold.withOpacity(0.2),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: AppColors.green),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context)!.activeFilterLabel(state.activeCount.toString())),
                  ],
                ),
                selected: state.statusFilter == RouteStatus.active,
                onSelected: (_) {
                  context.read<RoutesBloc>().add(
                        const FilterRoutesEvent(status: RouteStatus.active),
                      );
                },
                selectedColor: AppColors.green.withOpacity(0.2),
              ),
            ],
          ),
        );
      },
    );
  }
}
