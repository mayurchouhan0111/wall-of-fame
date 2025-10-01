// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:velocity_x/velocity_x.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/photo_provider.dart';
import '../models/photo_model.dart';
import 'AI_gen_screen.dart';
import 'image_detail_screen.dart';
import 'search_screen.dart';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late AnimationController _fabAnimationController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _setupScrollListener();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Provider.of<PhotoProvider>(context, listen: false).resetState();
      Provider.of<PhotoProvider>(context, listen: false).fetchTrendingPhotos();
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Show/hide scroll to top button
      if (_scrollController.offset > 1000) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }

      // Load more photos with throttling
      if (_isLoading) return;

      final provider = Provider.of<PhotoProvider>(context, listen: false);
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 600) {
        _loadMoreWithThrottle(provider);
      }
    });
  }

  void _loadMoreWithThrottle(PhotoProvider provider) {
    if (_isLoading) return;
    _isLoading = true;

    HapticFeedback.lightImpact();

    provider.loadMorePhotos().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isLoading = false;
        }
      });
    });
  }

  void _scrollToTop() {
    HapticFeedback.mediumImpact();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await Provider.of<PhotoProvider>(context, listen: false)
        .fetchTrendingPhotos();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF09090b),
      body: Consumer<PhotoProvider>(
        builder: (context, provider, child) {
          // Use null-safe access to allContent
          final contentList = _getContentList(provider);

          if (provider.isLoading && contentList.isEmpty) {
            return _buildLoadingState(provider);
          }
          if (provider.error != null && contentList.isEmpty) {
            return _buildErrorState(provider.error!);
          }
          return _buildPhotoGrid(provider, contentList);
        },
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimationController,
        child: FloatingActionButton(
          onPressed: _scrollToTop,
          backgroundColor: const Color(0xFF4f46e5),
          child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
        ),
      ),
    );
  }

  // Helper method to safely get content list
  List<Photo> _getContentList(PhotoProvider provider) {
    try {
      return provider.allContent;
    } catch (e) {
      // Fallback to photos if allContent is not available
      return provider.photos;
    }
  }

  // Helper method to safely get current mode
  String _getCurrentMode(PhotoProvider provider) {
    try {
      return provider.currentMode;
    } catch (e) {
      return 'photos';
    }
  }

  Widget _buildPhotoGrid(PhotoProvider provider, List<Photo> contentList) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);

    return RefreshIndicator(
      backgroundColor: const Color(0xFF18181b),
      color: Colors.white,
      onRefresh: _onRefresh,
      displacement: 80,
      strokeWidth: 3,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        cacheExtent: 1000,
        slivers: [
          _buildModernSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childCount: contentList.length,
              itemBuilder: (context, index) {
                final photo = contentList[index];
                return OptimizedPhotoCard(
                  key: ValueKey('photo_${photo.id}_${photo.type ?? "photo"}'),
                  photo: photo,
                  index: index,
                );
              },
            ),
          ),
          if (provider.isLoading && contentList.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181b),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF27272a), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4f46e5)),
                        ),
                      ),
                      12.widthBox,
                      Text(
                        "Loading more ${_getCurrentMode(provider)}...",
                        style: const TextStyle(
                          color: Color(0xFFa1a1aa),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 100,
            ),
          ),
        ],
      ),
    );
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) return 5;
    if (screenWidth > 900) return 4;
    if (screenWidth > 600) return 3;
    return 2;
  }

  SliverAppBar _buildModernSliverAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF09090b),
      surfaceTintColor: Colors.transparent,
      pinned: true,
      floating: false,
      snap: false,
      elevation: 0,
      expandedHeight: 540,
      toolbarHeight: 80,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF09090b),
                Color(0xFF0f0f0f),
                Color(0xFF18181b),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Background pattern/texture
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1557683316-973673baf926?w=1200'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo and brand section
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4f46e5), Color(0xFF6366f1), Color(0xFF8b5cf6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4f46e5).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        16.widthBox,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            "WallHub"
                                .text
                                .white
                                .size(32)
                                .fontWeight(FontWeight.w800)
                                .letterSpacing(0.5)
                                .make(),
                            4.heightBox,
                            "Discover & Create Amazing Wallpapers"
                                .text
                                .color(const Color(0xFFa1a1aa))
                                .size(14)
                                .fontWeight(FontWeight.w500)
                                .letterSpacing(0.3)
                                .make(),
                          ],
                        ),
                      ],
                    ),
                    24.heightBox,
                    // Main heading
                    "The best free wallpapers,\nroyalty free images & stunning\nvisuals shared by creators."
                        .text
                        .white
                        .size(28)
                        .fontWeight(FontWeight.w700)
                        .lineHeight(1.3)
                        .letterSpacing(0.2)
                        .make(),
                    24.heightBox,
                    // Search bar
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181b),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF27272a),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          16.widthBox,
                          const Icon(
                            Icons.photo_outlined,
                            color: Color(0xFF71717a),
                            size: 20,
                          ),
                          12.widthBox,
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                final query = await showSearch(
                                  context: context,
                                  delegate: PhotoSearchDelegate(),
                                );
                                if (query != null && query.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SearchScreen(query: query),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  "Search for free wallpapers...",
                                  style: TextStyle(
                                    color: Color(0xFF71717a),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4f46e5), Color(0xFF6366f1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    16.heightBox,
                    // UPDATED: THREE-TAB TOGGLE (Photos/Live/AI)
                    Consumer<PhotoProvider>(
                      builder: (context, provider, child) {
                        try {
                          final currentMode = _getCurrentMode(provider);
                          return Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181b),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: const Color(0xFF27272a), width: 1),
                            ),
                            child: Row(
                              children: [
                                // Photos Tab
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      try {
                                        provider.switchMode('photos');
                                        provider.fetchTrendingPhotos();
                                      } catch (e) {
                                        provider.fetchTrendingPhotos();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: currentMode == 'photos'
                                            ? const Color(0xFF4f46e5)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.photo_outlined,
                                            color: currentMode == 'photos'
                                                ? Colors.white
                                                : const Color(0xFF71717a),
                                            size: 16,
                                          ),
                                          6.widthBox,
                                          Text(
                                            'Photos',
                                            style: TextStyle(
                                              color: currentMode == 'photos'
                                                  ? Colors.white
                                                  : const Color(0xFF71717a),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Live Videos Tab
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      try {
                                        provider.switchMode('videos');
                                        provider.fetchTrendingPhotos();
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('🚧 Live wallpapers coming soon!'),
                                            backgroundColor: Color(0xFF8b5cf6),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: currentMode == 'videos'
                                            ? const Color(0xFF4f46e5)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.video_library_outlined,
                                            color: currentMode == 'videos'
                                                ? Colors.white
                                                : const Color(0xFF71717a),
                                            size: 16,
                                          ),
                                          6.widthBox,
                                          Text(
                                            'Live',
                                            style: TextStyle(
                                              color: currentMode == 'videos'
                                                  ? Colors.white
                                                  : const Color(0xFF71717a),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // AI Generate Tab (NEW)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      try {
                                        provider.switchMode('generate');
                                        // Navigate to AI Generate Screen
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder: (context, animation, secondaryAnimation) =>
                                            const AIGenerateScreen(),
                                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                              return SlideTransition(
                                                position: animation.drive(
                                                  Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                                      .chain(CurveTween(curve: Curves.easeOut)),
                                                ),
                                                child: child,
                                              );
                                            },
                                            transitionDuration: const Duration(milliseconds: 300),
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('🎨 AI Generation ready!'),
                                            backgroundColor: Color(0xFF8b5cf6),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: currentMode == 'generate'
                                            ? const Color(0xFF8b5cf6)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.auto_awesome,
                                            color: currentMode == 'generate'
                                                ? Colors.white
                                                : const Color(0xFF71717a),
                                            size: 16,
                                          ),
                                          6.widthBox,
                                          Text(
                                            'AI',
                                            style: TextStyle(
                                              color: currentMode == 'generate'
                                                  ? Colors.white
                                                  : const Color(0xFF71717a),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } catch (e) {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        collapseMode: CollapseMode.parallax,
      ),
      // Collapsed toolbar
      title: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, child) {
          final isCollapsed = _scrollController.hasClients &&
              _scrollController.offset > 200;

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isCollapsed ? 1.0 : 0.0,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4f46e5), Color(0xFF6366f1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                12.widthBox,
                Consumer<PhotoProvider>(
                  builder: (context, provider, _) {
                    final currentMode = _getCurrentMode(provider);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        "WallHub"
                            .text
                            .white
                            .size(18)
                            .fontWeight(FontWeight.w700)
                            .make(),
                        Text(
                          currentMode == 'videos'
                              ? 'Live Wallpapers'
                              : currentMode == 'generate'
                              ? 'AI Generator'
                              : 'Static Wallpapers',
                          style: const TextStyle(
                            color: Color(0xFF71717a),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        AnimatedBuilder(
          animation: _scrollController,
          builder: (context, child) {
            final isCollapsed = _scrollController.hasClients &&
                _scrollController.offset > 200;

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181b),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF27272a), width: 1),
                ),
                child: IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final query = await showSearch(
                      context: context,
                      delegate: PhotoSearchDelegate(),
                    );
                    if (query != null && query.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchScreen(query: query),
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingState(PhotoProvider provider) {
    final currentMode = _getCurrentMode(provider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF18181b),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF27272a), width: 1),
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4f46e5)),
            ),
          ),
          32.heightBox,
          "Crafting your visual journey..."
              .text
              .white
              .size(20)
              .fontWeight(FontWeight.w600)
              .center
              .make(),
          12.heightBox,
          Text(
            "Loading amazing ${currentMode == 'videos' ? 'live wallpapers' : currentMode == 'generate' ? 'AI creations' : 'photos'}...",
            style: const TextStyle(
              color: Color(0xFFa1a1aa),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF18181b),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFef4444).withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFef4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFef4444),
                size: 48,
              ),
            ),
            24.heightBox,
            "Connection Error"
                .text
                .white
                .size(22)
                .fontWeight(FontWeight.w700)
                .center
                .make(),
            16.heightBox,
            error
                .text
                .color(const Color(0xFFd4d4d8))
                .size(16)
                .center
                .lineHeight(1.5)
                .make(),
            32.heightBox,
            GestureDetector(
              onTap: _onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4f46e5), Color(0xFF6366f1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: "Try Again"
                    .text
                    .white
                    .fontWeight(FontWeight.w600)
                    .size(16)
                    .make(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// IMPROVED: OptimizedPhotoCard with video support and null safety
class OptimizedPhotoCard extends StatefulWidget {
  final Photo photo;
  final int index;

  const OptimizedPhotoCard({
    Key? key,
    required this.photo,
    required this.index,
  }) : super(key: key);

  @override
  _OptimizedPhotoCardState createState() => _OptimizedPhotoCardState();
}

class _OptimizedPhotoCardState extends State<OptimizedPhotoCard>
    with AutomaticKeepAliveClientMixin {
  bool _isHovering = false;
  bool _isImageLoaded = false;

  @override
  bool get wantKeepAlive => true;

  // Calculate aspect ratio from photo dimensions or use random heights for masonry effect
  double get _imageHeight {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    final cardWidth = (screenWidth - 32 - (8 * (crossAxisCount - 1))) / crossAxisCount;

    // If photo has dimensions, use them
    if (widget.photo.width != null &&
        widget.photo.height != null &&
        widget.photo.width! > 0 &&
        widget.photo.height! > 0) {
      final aspectRatio = widget.photo.width! / widget.photo.height!;
      final calculatedHeight = cardWidth / aspectRatio;
      // Clamp height between 150-400 for better UX
      return calculatedHeight.clamp(150.0, 400.0);
    }

    // Otherwise, create varied heights for masonry effect
    final heights = [200.0, 250.0, 300.0, 180.0, 280.0, 220.0, 260.0, 240.0];
    return heights[widget.index % heights.length];
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) return 5;
    if (screenWidth > 900) return 4;
    if (screenWidth > 600) return 3;
    return 2;
  }

  // Helper method to safely get photo type
  String get _photoType {
    try {
      return widget.photo.type ?? 'photo';
    } catch (e) {
      return 'photo';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: Hero(
        tag: 'photo_${widget.photo.id}_${_photoType}',
        child: GestureDetector(
          onTap: () => _navigateToDetail(),
          onLongPressStart: (_) => _setHovering(true),
          onLongPressEnd: (_) => _setHovering(false),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _imageHeight,
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: const Color(0xFF18181b),
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isHovering ? [
                BoxShadow(
                  color: _photoType == 'video'
                      ? const Color(0xFF8b5cf6).withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ] : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  _buildOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      scale: _isHovering ? 1.02 : 1.0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            // Use appropriate image URL based on type
            _photoType == 'video'
                ? (widget.photo.src.small.isNotEmpty ? widget.photo.src.small : widget.photo.src.large)
                : widget.photo.src.large,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.medium,
            isAntiAlias: true,
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                if (!_isImageLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _isImageLoaded = true);
                    }
                  });
                  // Pre-cache higher resolution image only for photos
                  if (_photoType == 'photo') {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted && widget.photo.src.large2x.isNotEmpty) {
                        precacheImage(NetworkImage(widget.photo.src.large2x), context);
                      }
                    });
                  }
                }
                return child;
              }
              return _buildShimmer();
            },
            errorBuilder: (context, error, stackTrace) {
              print('Image load error for ${_photoType}: $error');
              return _buildErrorWidget();
            },
          ),
          // Video indicator
          if (_photoType == 'video')
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                children: [
                  // Top right indicator
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  // Bottom left badge
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8b5cf6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.video_library, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF18181b),
      highlightColor: const Color(0xFF27272a),
      period: const Duration(milliseconds: 800),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF18181b),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF71717a),
            size: 28,
          ),
          SizedBox(height: 8),
          Text(
            'Failed to load',
            style: TextStyle(
              color: Color(0xFF71717a),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _isHovering ? 1.0 : 0.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.3),
              Colors.transparent,
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.center,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.photo.photographer,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              8.heightBox,
              Row(
                children: [
                  _buildActionButton(Icons.favorite_border, () => _handleFavorite()),
                  6.widthBox,
                  _buildActionButton(
                      _photoType == 'video' ? Icons.video_settings : Icons.download_outlined,
                          () => _handleDownload()
                  ),
                  6.widthBox,
                  _buildActionButton(Icons.share_outlined, () => _handleShare()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 12),
      ),
    );
  }

  void _setHovering(bool hovering) {
    if (mounted) {
      HapticFeedback.selectionClick();
      setState(() => _isHovering = hovering);
    }
  }

  void _navigateToDetail() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ImageDetailScreen(photo: widget.photo),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  void _handleFavorite() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            _photoType == 'video'
                ? '❤️ Added live wallpaper by ${widget.photo.photographer} to favorites'
                : '❤️ Added ${widget.photo.photographer} to favorites'
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF4f46e5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void _handleDownload() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            _photoType == 'video'
                ? '🎬 Setting live wallpaper by ${widget.photo.photographer}...'
                : '⬇️ Downloading ${widget.photo.photographer}'
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: _photoType == 'video'
            ? const Color(0xFF8b5cf6)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void _handleShare() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            _photoType == 'video'
                ? '🔗 Sharing live wallpaper by ${widget.photo.photographer}'
                : '🔗 Sharing ${widget.photo.photographer}'
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF7c3aed),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }
}

class PhotoSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: const Color(0xFF09090b),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF09090b),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF71717a), fontSize: 18),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    close(context, query);
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = [
      "Nature", "Architecture", "Animals", "Technology", "Food", "Travel",
      "Portrait", "Landscape", "Abstract", "Vintage", "Urban", "Minimalist",
      "Black & White", "Sunset", "Ocean", "Mountains", "Forest", "City",
      "Animated", "Live", "Motion", "Particles", "Gradient"
    ];

    final filteredSuggestions = query.isEmpty
        ? suggestions
        : suggestions
        .where((s) => s.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return Container(
      color: const Color(0xFF09090b),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: Color(0xFF4f46e5), size: 20),
              8.widthBox,
              "Popular Searches".text.white.size(18).fontWeight(FontWeight.w600).make(),
            ],
          ),
          20.heightBox,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: filteredSuggestions.map((suggestion) {
              return GestureDetector(
                onTap: () {
                  query = suggestion;
                  showResults(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181b),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: const Color(0xFF27272a), width: 1),
                  ),
                  child: Text(
                    suggestion,
                    style: const TextStyle(
                      color: Color(0xFFd4d4d8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
