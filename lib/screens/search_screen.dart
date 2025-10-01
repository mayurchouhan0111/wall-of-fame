// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:velocity_x/velocity_x.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/photo_provider.dart';
import '../models/photo_model.dart';
import 'image_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String query;
  const SearchScreen({Key? key, required this.query}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late AnimationController _fabController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _setupScrollListener();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _initializeSearch();
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Show/hide FAB
      if (_scrollController.offset > 800) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }

      // Load more photos
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

  Future<void> _initializeSearch() async {
    try {
      await Provider.of<PhotoProvider>(context, listen: false).searchPhotos(widget.query);
      _fadeController.forward();
    } catch (e) {
      print('Search error: $e');
    }
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
    _fadeController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF09090b),
      appBar: _buildModernAppBar(),
      body: Consumer<PhotoProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.allContent.isEmpty) {
            return _buildLoadingState();
          }
          if (provider.error != null && provider.allContent.isEmpty) {
            return _buildErrorState(provider.error!);
          }
          if (provider.allContent.isEmpty) {
            return _buildEmptyState();
          }
          return _buildSearchResults(provider);
        },
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabController,
        child: FloatingActionButton(
          onPressed: _scrollToTop,
          backgroundColor: const Color(0xFF4f46e5),
          child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF09090b),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF18181b),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272a), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Consumer<PhotoProvider>(
                builder: (context, provider, _) {
                  return Icon(
                    provider.currentMode == 'videos'
                        ? Icons.video_library_rounded
                        : Icons.search_rounded,
                    color: provider.currentMode == 'videos'
                        ? const Color(0xFF8b5cf6)
                        : const Color(0xFF4f46e5),
                    size: 20,
                  );
                },
              ),
              8.widthBox,
              "Search Results"
                  .text
                  .white
                  .size(18)
                  .fontWeight(FontWeight.w600)
                  .make(),
            ],
          ),
          4.heightBox,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF18181b),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF27272a), width: 1),
            ),
            child: '"${widget.query}"'
                .text
                .color(const Color(0xFF71717a))
                .size(12)
                .fontWeight(FontWeight.w500)
                .make(),
          ),
        ],
      ),
      actions: [
        // Mode toggle button
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF18181b),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF27272a), width: 1),
          ),
          child: Consumer<PhotoProvider>(
            builder: (context, provider, _) {
              return IconButton(
                iconSize: 20,
                icon: Icon(
                  provider.currentMode == 'videos'
                      ? Icons.photo_outlined
                      : Icons.video_library_outlined,
                  color: Colors.white,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final newMode = provider.currentMode == 'videos' ? 'photos' : 'videos';
                  provider.switchMode(newMode);
                  provider.searchPhotos(widget.query);
                },
              );
            },
          ),
        ),
        // Refresh button
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF18181b),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF27272a), width: 1),
          ),
          child: IconButton(
            iconSize: 20,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              _initializeSearch();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
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
            child: Column(
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4f46e5)),
                ),
                20.heightBox,
                Consumer<PhotoProvider>(
                  builder: (context, provider, _) {
                    return 'Searching for ${provider.currentMode == "videos" ? "live wallpapers" : "wallpapers"} about "${widget.query}"...'
                        .text
                        .white
                        .size(18)
                        .fontWeight(FontWeight.w600)
                        .center
                        .make();
                  },
                ),
                8.heightBox,
                "Finding the best content for you"
                    .text
                    .color(const Color(0xFFa1a1aa))
                    .size(14)
                    .center
                    .make(),
              ],
            ),
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
                Icons.search_off_rounded,
                color: Color(0xFFef4444),
                size: 48,
              ),
            ),
            24.heightBox,
            "Search Failed"
                .text
                .white
                .size(20)
                .fontWeight(FontWeight.w700)
                .center
                .make(),
            12.heightBox,
            error
                .text
                .color(const Color(0xFFd4d4d8))
                .size(16)
                .center
                .lineHeight(1.5)
                .make(),
            24.heightBox,
            GestureDetector(
              onTap: _initializeSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
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
                    .make(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF18181b),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF27272a), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer<PhotoProvider>(
              builder: (context, provider, _) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF71717a).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    provider.currentMode == 'videos'
                        ? Icons.video_library_outlined
                        : Icons.image_search_rounded,
                    color: const Color(0xFF71717a),
                    size: 64,
                  ),
                );
              },
            ),
            24.heightBox,
            "No Results Found"
                .text
                .white
                .size(22)
                .fontWeight(FontWeight.w700)
                .center
                .make(),
            16.heightBox,
            Consumer<PhotoProvider>(
              builder: (context, provider, _) {
                final contentType = provider.currentMode == 'videos' ? 'live wallpapers' : 'wallpapers';
                return 'We couldn\'t find any $contentType for "${widget.query}".\nTry searching with different keywords.'
                    .text
                    .color(const Color(0xFFa1a1aa))
                    .size(16)
                    .center
                    .lineHeight(1.5)
                    .make();
              },
            ),
            32.heightBox,
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF27272a),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  "Try searching for:"
                      .text
                      .color(const Color(0xFFa1a1aa))
                      .size(14)
                      .fontWeight(FontWeight.w600)
                      .make(),
                  12.heightBox,
                  Consumer<PhotoProvider>(
                    builder: (context, provider, _) {
                      final suggestions = provider.currentMode == 'videos'
                          ? ["Particles", "Ocean Waves", "Fire", "Abstract", "Rain"]
                          : ["Nature", "Abstract", "City", "Minimal", "Dark"];

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: suggestions
                            .map((suggestion) => GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchScreen(query: suggestion),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4f46e5).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF4f46e5).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: suggestion
                                .text
                                .color(const Color(0xFF4f46e5))
                                .size(12)
                                .fontWeight(FontWeight.w500)
                                .make(),
                          ),
                        ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(PhotoProvider provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 1000,
        slivers: [
          // Results header
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    provider.currentMode == 'videos'
                        ? const Color(0xFF8b5cf6)
                        : const Color(0xFF4f46e5),
                    provider.currentMode == 'videos'
                        ? const Color(0xFFa855f7)
                        : const Color(0xFF6366f1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (provider.currentMode == 'videos'
                        ? const Color(0xFF8b5cf6)
                        : const Color(0xFF4f46e5)).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      provider.currentMode == 'videos'
                          ? Icons.video_library_outlined
                          : Icons.check_circle_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  12.widthBox,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        "${provider.allContent.length} ${provider.currentMode == 'videos' ? 'live wallpapers' : 'wallpapers'} found"
                            .text
                            .white
                            .size(16)
                            .fontWeight(FontWeight.w600)
                            .make(),
                        "Swipe up to see more results"
                            .text
                            .color(Colors.white.withOpacity(0.8))
                            .size(12)
                            .make(),
                      ],
                    ),
                  ),
                  // Mode indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      provider.currentMode.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Photo grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childCount: provider.allContent.length,
              itemBuilder: (context, index) {
                final photo = provider.allContent[index];
                return SearchPhotoCard(
                  key: ValueKey('search_photo_${photo.id}_${photo.type}'),
                  photo: photo,
                  index: index,
                );
              },
            ),
          ),
          // Loading more indicator
          if (provider.isLoading && provider.allContent.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
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
                    Consumer<PhotoProvider>(
                      builder: (context, provider, _) {
                        return "Loading more ${provider.currentMode}..."
                            .text
                            .color(const Color(0xFFa1a1aa))
                            .size(14)
                            .make();
                      },
                    ),
                  ],
                ),
              ),
            ),
          // Bottom padding
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
}

// Separate PhotoCard widget for better performance
class SearchPhotoCard extends StatefulWidget {
  final Photo photo;
  final int index;

  const SearchPhotoCard({
    Key? key,
    required this.photo,
    required this.index,
  }) : super(key: key);

  @override
  _SearchPhotoCardState createState() => _SearchPhotoCardState();
}

class _SearchPhotoCardState extends State<SearchPhotoCard>
    with AutomaticKeepAliveClientMixin {
  bool _isHovering = false;

  @override
  bool get wantKeepAlive => true;

  double get _imageHeight {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    final cardWidth = (screenWidth - 32 - (8 * (crossAxisCount - 1))) / crossAxisCount;

    if (widget.photo.width != null && widget.photo.height != null) {
      final aspectRatio = widget.photo.width! / widget.photo.height!;
      final calculatedHeight = cardWidth / aspectRatio;
      return calculatedHeight.clamp(180.0, 400.0);
    }

    final heights = [220.0, 280.0, 240.0, 320.0, 200.0, 360.0, 260.0];
    return heights[widget.index % heights.length];
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) return 5;
    if (screenWidth > 900) return 4;
    if (screenWidth > 600) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: Hero(
        tag: 'search_photo_${widget.photo.id}_${widget.photo.type}',
        child: GestureDetector(
          onTap: _navigateToDetail,
          onLongPressStart: (_) => _setHovering(true),
          onLongPressEnd: (_) => _setHovering(false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _imageHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF18181b),
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isHovering ? [
                BoxShadow(
                  color: widget.photo.type == 'video'
                      ? const Color(0xFF8b5cf6).withOpacity(0.4)
                      : const Color(0xFF4f46e5).withOpacity(0.3),
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
            widget.photo.type == 'video'
                ? widget.photo.src.small
                : widget.photo.src.large,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Shimmer.fromColors(
                baseColor: const Color(0xFF18181b),
                highlightColor: const Color(0xFF27272a),
                child: Container(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
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
            ),
          ),
          // Video indicator
          if (widget.photo.type == 'video')
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
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8b5cf6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.video_library, color: Colors.white, size: 10),
                          SizedBox(width: 3),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
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
          padding: const EdgeInsets.all(12),
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
                  _buildActionButton(Icons.favorite_border, () {}),
                  6.widthBox,
                  _buildActionButton(
                      widget.photo.type == 'video' ? Icons.video_settings : Icons.download_outlined,
                          () {}
                  ),
                  6.widthBox,
                  _buildActionButton(Icons.share_outlined, () {}),
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
}
