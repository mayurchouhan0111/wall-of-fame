// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
  late AnimationController _headerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _headerAnimation;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupScrollListener();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _initializeSearch();
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.offset > 800) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }

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
        if (mounted) _isLoading = false;
      });
    });
  }

  Future<void> _initializeSearch() async {
    try {
      await Provider.of<PhotoProvider>(context, listen: false)
          .searchPhotos(widget.query);
      _fadeController.forward();
      _headerController.forward();
    } catch (e) {
      // ignore: avoid_print
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
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f0f0f),
              Colors.black,
            ],
          ),
        ),
        child: Consumer<PhotoProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.allContent.isEmpty) {
              return _buildLoadingState(size);
            }

            if (provider.error != null && provider.allContent.isEmpty) {
              return _buildErrorState(provider.error!, size);
            }

            if (provider.allContent.isEmpty) {
              return _buildEmptyState(size);
            }

            return _buildSearchResults(provider, size);
          },
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return ScaleTransition(
      scale: _fabController,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366f1).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _scrollToTop,
          backgroundColor: const Color(0xFF6366f1),
          elevation: 0,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child:
          const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildSearchResults(PhotoProvider provider, Size size) {
    final crossAxisCount = _getCrossAxisCount(size.width);

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      cacheExtent: 2000,
      slivers: [
        _buildModernAppBar(size),
        _buildResultsHeader(provider, size),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.02),
          // FIX: Replaced FadeTransition with SliverFadeTransition
          sliver: SliverFadeTransition(
            opacity: _fadeAnimation,
            sliver: SliverMasonryGrid.count(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: size.width * 0.015,
              crossAxisSpacing: size.width * 0.015,
              childCount: provider.allContent.length,
              itemBuilder: (context, index) {
                final photo = provider.allContent[index];
                return EnhancedSearchPhotoCard(
                  key: ValueKey('search_photo_${photo.id}_${photo.type}'),
                  photo: photo,
                  index: index,
                  screenSize: size,
                );
              },
            ),
          ),
        ),
        if (provider.isLoading && provider.allContent.isNotEmpty)
          _buildLoadingMoreIndicator(),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 120),
        ),
      ],
    );
  }

  SliverAppBar _buildModernAppBar(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      expandedHeight: isDesktop ? 200 : isTablet ? 180 : 160,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _headerAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - _headerAnimation.value)),
              child: Opacity(
                opacity: _headerAnimation.value,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    size.width * 0.05,
                    size.height * 0.12,
                    size.width * 0.05,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Consumer<PhotoProvider>(
                            builder: (context, provider, _) {
                              return Container(
                                padding: EdgeInsets.all(
                                    isDesktop ? 16 : isTablet ? 14 : 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: provider.currentMode == 'videos'
                                        ? [
                                      const Color(0xFF8b5cf6),
                                      const Color(0xFFa855f7)
                                    ]
                                        : [
                                      const Color(0xFF6366f1),
                                      const Color(0xFF8b5cf6)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (provider.currentMode == 'videos'
                                          ? const Color(0xFF8b5cf6)
                                          : const Color(0xFF6366f1))
                                          .withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  provider.currentMode == 'videos'
                                      ? Icons.video_library_rounded
                                      : Icons.search_rounded,
                                  color: Colors.white,
                                  size: isDesktop ? 28 : isTablet ? 24 : 20,
                                ),
                              );
                            },
                          ),
                          SizedBox(width: isDesktop ? 20 : isTablet ? 16 : 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Colors.white, Colors.white70],
                                ).createShader(bounds),
                                child: Text(
                                  "Search Results",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize:
                                    isDesktop ? 32 : isTablet ? 28 : 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF1a1a2e).withOpacity(0.8),
                                      const Color(0xFF16213e).withOpacity(0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                    const Color(0xFF6366f1).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '"${widget.query}"',
                                  style: TextStyle(
                                    color: const Color(0xFF6366f1),
                                    fontSize:
                                    isDesktop ? 14 : isTablet ? 13 : 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1a1a2e).withOpacity(0.8),
              const Color(0xFF16213e).withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF374151), width: 1),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1a1a2e).withOpacity(0.8),
                const Color(0xFF16213e).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF374151), width: 1),
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
                  final newMode =
                  provider.currentMode == 'videos' ? 'photos' : 'videos';
                  provider.switchMode(newMode);
                  provider.searchPhotos(widget.query);
                },
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1a1a2e).withOpacity(0.8),
                const Color(0xFF16213e).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF374151), width: 1),
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

  Widget _buildResultsHeader(PhotoProvider provider, Size size) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: EdgeInsets.all(size.width * 0.05),
          padding: EdgeInsets.all(size.width * 0.04),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: provider.currentMode == 'videos'
                  ? [
                const Color(0xFF8b5cf6).withOpacity(0.2),
                const Color(0xFFa855f7).withOpacity(0.1),
              ]
                  : [
                const Color(0xFF6366f1).withOpacity(0.2),
                const Color(0xFF8b5cf6).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (provider.currentMode == 'videos'
                  ? const Color(0xFF8b5cf6)
                  : const Color(0xFF6366f1))
                  .withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  provider.currentMode == 'videos'
                      ? Icons.video_library_outlined
                      : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${provider.allContent.length} ${provider.currentMode == 'videos' ? 'live wallpapers' : 'wallpapers'} found",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size.width > 600 ? 18 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Scroll to explore more results",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: size.width > 600 ? 14 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
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
    );
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1400) return 6;
    if (screenWidth > 1200) return 5;
    if (screenWidth > 900) return 4;
    if (screenWidth > 600) return 3;
    return 2;
  }

  Widget _buildLoadingState(Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0xFF1a1a2e),
            Color(0xFF0f0f0f),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1a1a2e).withOpacity(0.8),
                    const Color(0xFF16213e).withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF374151), width: 1),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Consumer<PhotoProvider>(
                    builder: (context, provider, _) {
                      return Text(
                        'Searching for ${provider.currentMode == "videos" ? "live wallpapers" : "wallpapers"} about "${widget.query}"...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size.width > 600 ? 20 : 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Discovering the perfect content for you",
                    style: TextStyle(
                      color: const Color(0xFFa1a1aa),
                      fontSize: size.width > 600 ? 16 : 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0xFF1a1a2e),
            Color(0xFF0f0f0f),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(size.width * 0.08),
          padding: EdgeInsets.all(size.width * 0.08),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1a1a2e).withOpacity(0.8),
                const Color(0xFF16213e).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFFef4444).withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFef4444).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  color: const Color(0xFFef4444),
                  size: size.width > 600 ? 48 : 40,
                ),
              ),
              SizedBox(height: size.width * 0.06),
              Text(
                "Search Failed",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size.width > 600 ? 24 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: size.width * 0.04),
              Text(
                error,
                style: TextStyle(
                  color: const Color(0xFFd4d4d8),
                  fontSize: size.width > 600 ? 16 : 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: size.width * 0.06),
              GestureDetector(
                onTap: _initializeSearch,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    "Try Again",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: size.width > 600 ? 16 : 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0xFF1a1a2e),
            Color(0xFF0f0f0f),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(size.width * 0.08),
          padding: EdgeInsets.all(size.width * 0.08),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1a1a2e).withOpacity(0.8),
                const Color(0xFF16213e).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF374151), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<PhotoProvider>(
                builder: (context, provider, _) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF71717a).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      provider.currentMode == 'videos'
                          ? Icons.video_library_outlined
                          : Icons.image_search_rounded,
                      color: const Color(0xFF71717a),
                      size: size.width > 600 ? 64 : 48,
                    ),
                  );
                },
              ),
              SizedBox(height: size.width * 0.06),
              Text(
                "No Results Found",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size.width > 600 ? 28 : 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: size.width * 0.04),
              Consumer<PhotoProvider>(
                builder: (context, provider, _) {
                  final contentType = provider.currentMode == 'videos'
                      ? 'live wallpapers'
                      : 'wallpapers';
                  return Text(
                    'We couldn\'t find any $contentType for "${widget.query}".\nTry searching with different keywords.',
                    style: TextStyle(
                      color: const Color(0xFFa1a1aa),
                      fontSize: size.width > 600 ? 16 : 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              SizedBox(height: size.width * 0.08),
              _buildSuggestions(size),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(Size size) {
    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFF27272a).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            "Try searching for:",
            style: TextStyle(
              color: const Color(0xFFa1a1aa),
              fontSize: size.width > 600 ? 16 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: size.width * 0.03),
          Consumer<PhotoProvider>(
            builder: (context, provider, _) {
              final suggestions = provider.currentMode == 'videos'
                  ? ["Particles", "Ocean Waves", "Fire", "Abstract", "Rain", "Galaxy"]
                  : ["Nature", "Abstract", "City", "Minimal", "Dark", "Space"];

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: suggestions.map((suggestion) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, _) =>
                              SearchScreen(query: suggestion),
                          transitionsBuilder:
                              (context, animation, _, child) {
                            return FadeTransition(
                                opacity: animation, child: child);
                          },
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6366f1).withOpacity(0.3),
                            const Color(0xFF8b5cf6).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6366f1).withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          color: const Color(0xFF6366f1),
                          fontSize: size.width > 600 ? 14 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1a1a2e).withOpacity(0.8),
                const Color(0xFF16213e).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF374151), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF6366f1)),
                ),
              ),
              const SizedBox(width: 12),
              Consumer<PhotoProvider>(
                builder: (context, provider, _) {
                  return Text(
                    "Loading more ${provider.currentMode}...",
                    style: const TextStyle(
                      color: Color(0xFFa1a1aa),
                      fontSize: 14,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced Search Photo Card Component
class EnhancedSearchPhotoCard extends StatefulWidget {
  final Photo photo;
  final int index;
  final Size screenSize;

  const EnhancedSearchPhotoCard({
    Key? key,
    required this.photo,
    required this.index,
    required this.screenSize,
  }) : super(key: key);

  @override
  _EnhancedSearchPhotoCardState createState() =>
      _EnhancedSearchPhotoCardState();
}

class _EnhancedSearchPhotoCardState extends State<EnhancedSearchPhotoCard>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  bool _isHovering = false;
  bool _isImageLoaded = false;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _hoverAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  double get _imageHeight {
    final isTablet = widget.screenSize.width > 600;
    final isDesktop = widget.screenSize.width > 1024;
    final crossAxisCount = _getCrossAxisCount(widget.screenSize.width);
    final cardWidth = (widget.screenSize.width - (widget.screenSize.width * 0.04) - (widget.screenSize.width * 0.015 * (crossAxisCount - 1))) / crossAxisCount;

    if (widget.photo.width != null &&
        widget.photo.height != null &&
        widget.photo.width! > 0 &&
        widget.photo.height! > 0) {
      final aspectRatio = widget.photo.width! / widget.photo.height!;
      final calculatedHeight = cardWidth / aspectRatio;
      return calculatedHeight.clamp(
        isDesktop ? 200.0 : isTablet ? 180.0 : 160.0,
        isDesktop ? 450.0 : isTablet ? 400.0 : 350.0,
      );
    }

    final heights = [240.0, 300.0, 260.0, 340.0, 220.0, 380.0, 280.0, 320.0];
    return heights[widget.index % heights.length];
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1400) return 6;
    if (screenWidth > 1200) return 5;
    if (screenWidth > 900) return 4;
    if (screenWidth > 600) return 3;
    return 2;
  }

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
        tag: 'search_photo_${widget.photo.id}_${_photoType}',
        child: GestureDetector(
          onTap: _navigateToDetail,
          onLongPressStart: (_) => _setHovering(true),
          onLongPressEnd: (_) => _setHovering(false),
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _hoverAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _hoverAnimation.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _imageHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      widget.screenSize.width > 1024
                          ? 20
                          : widget.screenSize.width > 600
                          ? 16
                          : 14,
                    ),
                    boxShadow: _isHovering
                        ? [
                      BoxShadow(
                        color: _photoType == 'video'
                            ? const Color(0xFF8b5cf6).withOpacity(0.4)
                            : const Color(0xFF6366f1).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                        : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      widget.screenSize.width > 1024
                          ? 20
                          : widget.screenSize.width > 600
                          ? 16
                          : 14,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImage(),
                        _buildGradientOverlay(),
                        _buildInfoOverlay(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Image.network(
      _photoType == 'video' ? widget.photo.src.small : widget.photo.src.large,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isImageLoaded = true);
          });
          return child;
        }
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1a1a2e),
          highlightColor: const Color(0xFF374151),
          child: Container(color: Colors.white),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFF1a1a2e),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: const Color(0xFF71717a),
              size: widget.screenSize.width > 600 ? 32 : 28,
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load',
              style: TextStyle(
                color: const Color(0xFF71717a),
                fontSize: widget.screenSize.width > 600 ? 12 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoOverlay() {
    final isTablet = widget.screenSize.width > 600;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isImageLoaded ? 1.0 : 0.0,
        child: Container(
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type badge
              if (_photoType == 'video')
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8b5cf6), Color(0xFFa855f7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Photographer name
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  widget.photo.photographer,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 13 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setHovering(bool hovering) {
    if (mounted) {
      HapticFeedback.selectionClick();
      setState(() => _isHovering = hovering);
      if (hovering) {
        _hoverController.forward();
      } else {
        _hoverController.reverse();
      }
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
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}