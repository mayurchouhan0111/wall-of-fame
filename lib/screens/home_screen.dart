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
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Enhanced Animation Controllers
  late AnimationController _fabAnimationController;
  late AnimationController _headerAnimationController;
  late AnimationController _particleController;
  late AnimationController _breathingController;

  late Animation<double> _headerAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _breathingAnimation;

  // Floating particles for background
  List<Particle> particles = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateParticles();
    _setupScrollListener();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      Provider.of<PhotoProvider>(context, listen: false).resetState();
      Provider.of<PhotoProvider>(context, listen: false).fetchTrendingPhotos();
    });
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerAnimationController, curve: Curves.easeOutBack),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_particleController);
    _breathingAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _headerAnimationController.forward();
  }

  void _generateParticles() {
    particles = List.generate(20, (index) {
      return Particle(
        x: math.Random().nextDouble(),
        y: math.Random().nextDouble(),
        size: math.Random().nextDouble() * 4 + 2,
        speed: math.Random().nextDouble() * 0.5 + 0.2,
        opacity: math.Random().nextDouble() * 0.6 + 0.2,
      );
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Enhanced scroll-based animations
      if (_scrollController.offset > 1000) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
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
    _headerAnimationController.dispose();
    _particleController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await Provider.of<PhotoProvider>(context, listen: false).fetchTrendingPhotos();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(),

          // Main content
          Consumer<PhotoProvider>(
            builder: (context, provider, child) {
              final contentList = _getContentList(provider);

              if (provider.isLoading && contentList.isEmpty) {
                return _buildLoadingState(provider);
              }

              if (provider.error != null && contentList.isEmpty) {
                return _buildErrorState(provider.error!);
              }

              return _buildPhotoGrid(provider, contentList, size);
            },
          ),
        ],
      ),
      floatingActionButton: _buildEnhancedFAB(),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [
                const Color(0xFF1a1a2e),
                const Color(0xFF16213e),
                const Color(0xFF0f0f0f),
                Colors.black,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: ParticlePainter(particles, _particleAnimation.value),
            child: Container(),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedFAB() {
    return ScaleTransition(
      scale: _fabAnimationController,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  List<Photo> _getContentList(PhotoProvider provider) {
    try {
      return provider.allContent;
    } catch (e) {
      return provider.photos;
    }
  }

  String _getCurrentMode(PhotoProvider provider) {
    try {
      return provider.currentMode;
    } catch (e) {
      return 'photos';
    }
  }

  Widget _buildPhotoGrid(PhotoProvider provider, List<Photo> contentList, Size size) {
    final crossAxisCount = _getResponsiveCrossAxisCount(size.width);

    return RefreshIndicator(
      backgroundColor: const Color(0xFF1a1a2e),
      color: const Color(0xFF6366f1),
      onRefresh: _onRefresh,
      displacement: 80,
      strokeWidth: 3,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        cacheExtent: 2000,
        slivers: [
          _buildSpectacularSliverAppBar(size),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              size.width * 0.02,
              12,
              size.width * 0.02,
              0,
            ),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: size.width * 0.015,
              crossAxisSpacing: size.width * 0.015,
              childCount: contentList.length,
              itemBuilder: (context, index) {
                final photo = contentList[index];
                return EnhancedPhotoCard(
                  key: ValueKey('photo_${photo.id}_${photo.type ?? "photo"}'),
                  photo: photo,
                  index: index,
                  screenSize: size,
                );
              },
            ),
          ),
          if (provider.isLoading && contentList.isNotEmpty)
            _buildLoadingMoreIndicator(provider),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 120),
          ),
        ],
      ),
    );
  }

  int _getResponsiveCrossAxisCount(double screenWidth) {
    if (screenWidth > 1400) return 6;
    if (screenWidth > 1200) return 5;
    if (screenWidth > 900) return 4;
    if (screenWidth > 600) return 3;
    return 2;
  }

  SliverAppBar _buildSpectacularSliverAppBar(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      floating: false,
      snap: false,
      elevation: 0,
      expandedHeight: isDesktop ? 700 : isTablet ? 650 : 600,
      toolbarHeight: 90,
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _headerAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black,
                    const Color(0xFF0f0f23),
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Floating orbs background
                  _buildFloatingOrbs(size),

                  // Main content
                  Transform.translate(
                    offset: Offset(0, 100 * (1 - _headerAnimation.value)),
                    child: Opacity(
                      opacity: _headerAnimation.value,
                      child: _buildHeaderContent(size),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        collapseMode: CollapseMode.parallax,
      ),
      title: _buildCollapsedTitle(size),
      actions: [_buildSearchAction(size)],
    );
  }

  Widget _buildFloatingOrbs(Size size) {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: size.height * 0.15,
              right: size.width * 0.1,
              child: Transform.scale(
                scale: _breathingAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366f1).withOpacity(0.3),
                        const Color(0xFF8b5cf6).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.25,
              left: size.width * 0.05,
              child: Transform.scale(
                scale: _breathingAnimation.value * 0.8,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFf59e0b).withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderContent(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        size.width * 0.05,
        size.height * 0.12,
        size.width * 0.05,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand section
          _buildEnhancedBrand(size),

          SizedBox(height: isDesktop ? 40 : isTablet ? 35 : 30),

          // Main heading
          _buildMainHeading(size),

          SizedBox(height: isDesktop ? 35 : isTablet ? 30 : 25),

          // Search bar
          _buildEnhancedSearchBar(size),

          SizedBox(height: isDesktop ? 25 : isTablet ? 20 : 18),

          // Mode toggle
          _buildEnhancedModeToggle(size),
        ],
      ),
    );
  }

  Widget _buildEnhancedBrand(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Row(
          children: [
            Transform.scale(
              scale: _breathingAnimation.value,
              child: Container(
                padding: EdgeInsets.all(isDesktop ? 20 : isTablet ? 18 : 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366f1),
                      const Color(0xFF8b5cf6),
                      const Color(0xFFa855f7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 20 : 18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366f1).withOpacity(0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: isDesktop ? 36 : isTablet ? 32 : 28,
                ),
              ),
            ),
            SizedBox(width: isDesktop ? 20 : isTablet ? 18 : 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.white, Colors.white70],
                  ).createShader(bounds),
                  child: Text(
                    "WallHub",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 38 : isTablet ? 34 : 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Infinite Visual Universe",
                  style: TextStyle(
                    color: const Color(0xFFa1a1aa),
                    fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainHeading(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          Colors.white,
          const Color(0xFFe5e5e5),
          const Color(0xFFa1a1aa),
        ],
      ).createShader(bounds),
      child: Text(
        "Discover breathtaking\nwallpapers & create\namazing visuals with AI",
        style: TextStyle(
          color: Colors.white,
          fontSize: isDesktop ? 36 : isTablet ? 30 : 26,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEnhancedSearchBar(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      height: isDesktop ? 65 : isTablet ? 60 : 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1a1a2e).withOpacity(0.8),
            const Color(0xFF16213e).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 35 : isTablet ? 32 : 28),
        border: Border.all(
          color: const Color(0xFF6366f1).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366f1).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: isDesktop ? 24 : isTablet ? 20 : 18),
          Icon(
            Icons.search_rounded,
            color: const Color(0xFF6366f1),
            size: isDesktop ? 26 : isTablet ? 24 : 22,
          ),
          SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),
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
                    PageRouteBuilder(
                      pageBuilder: (context, animation, _) => SearchScreen(query: query),
                      transitionsBuilder: (context, animation, _, child) {
                        return SlideTransition(
                          position: animation.drive(
                            Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
                          ),
                          child: child,
                        );
                      },
                    ),
                  );
                }
              },
              child: Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Search infinite possibilities...",
                  style: TextStyle(
                    color: const Color(0xFF71717a),
                    fontSize: isDesktop ? 18 : isTablet ? 16 : 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.all(isDesktop ? 10 : isTablet ? 8 : 6),
            padding: EdgeInsets.all(isDesktop ? 14 : isTablet ? 12 : 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF6366f1), const Color(0xFF8b5cf6)],
              ),
              borderRadius: BorderRadius.circular(isDesktop ? 25 : isTablet ? 22 : 20),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: isDesktop ? 22 : isTablet ? 20 : 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedModeToggle(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Consumer<PhotoProvider>(
      builder: (context, provider, child) {
        final currentMode = _getCurrentMode(provider);

        return Container(
          height: isDesktop ? 60 : isTablet ? 55 : 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1a1a2e).withOpacity(0.8),
                const Color(0xFF16213e).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(isDesktop ? 32 : isTablet ? 28 : 25),
            border: Border.all(color: const Color(0xFF374151), width: 1),
          ),
          child: Row(
            children: [
              _buildModeButton(
                'Photos',
                Icons.photo_camera_outlined,
                currentMode == 'photos',
                    () => _switchMode(provider, 'photos'),
                size,
              ),
              _buildModeButton(
                'Live',
                Icons.video_library_outlined,
                currentMode == 'videos',
                    () => _switchMode(provider, 'videos'),
                size,
              ),
              _buildModeButton(
                'AI Create',
                Icons.auto_awesome_rounded,
                currentMode == 'generate',
                    () => _navigateToAI(provider),
                size,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeButton(String label, IconData icon, bool isSelected, VoidCallback onTap, Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.all(4),
          padding: EdgeInsets.symmetric(
            vertical: isDesktop ? 14 : isTablet ? 12 : 10,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
              colors: [const Color(0xFF6366f1), const Color(0xFF8b5cf6)],
            )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(isDesktop ? 28 : isTablet ? 24 : 22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF71717a),
                size: isDesktop ? 20 : isTablet ? 18 : 16,
              ),
              if (isTablet) SizedBox(width: 8),
              if (isTablet)
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF71717a),
                    fontSize: isDesktop ? 15 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _switchMode(PhotoProvider provider, String mode) {
    HapticFeedback.lightImpact();
    try {
      provider.switchMode(mode);
      provider.fetchTrendingPhotos();
    } catch (e) {
      provider.fetchTrendingPhotos();
    }
  }

  void _navigateToAI(PhotoProvider provider) {
    HapticFeedback.lightImpact();
    try {
      provider.switchMode('generate');
    } catch (e) {
      // Handle error
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => const AIGenerateScreen(),
        transitionsBuilder: (context, animation, _, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOut)),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Widget _buildCollapsedTitle(Size size) {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        final isCollapsed = _scrollController.hasClients && _scrollController.offset > 200;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isCollapsed ? 1.0 : 0.0,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF6366f1), const Color(0xFF8b5cf6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "WallHub",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size.width > 600 ? 20 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Consumer<PhotoProvider>(
                    builder: (context, provider, _) {
                      final currentMode = _getCurrentMode(provider);
                      return Text(
                        currentMode == 'videos'
                            ? 'Live Wallpapers'
                            : currentMode == 'generate'
                            ? 'AI Generator'
                            : 'Wallpaper Gallery',
                        style: const TextStyle(color: Color(0xFF71717a), fontSize: 10),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAction(Size size) {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        final isCollapsed = _scrollController.hasClients && _scrollController.offset > 200;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isCollapsed ? 1.0 : 0.0,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1a1a2e).withOpacity(0.8),
                  const Color(0xFF16213e).withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF374151), width: 1),
            ),
            child: IconButton(
              iconSize: 22,
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
                    MaterialPageRoute(builder: (context) => SearchScreen(query: query)),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(PhotoProvider provider) {
    final currentMode = _getCurrentMode(provider);
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            const Color(0xFF1a1a2e),
            const Color(0xFF0f0f0f),
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF6366f1), const Color(0xFF8b5cf6)],
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
                  Text(
                    "Crafting Visual Magic...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Loading stunning ${currentMode == 'videos' ? 'live wallpapers' : currentMode == 'generate' ? 'AI creations' : 'wallpapers'}",
                    style: const TextStyle(color: Color(0xFFa1a1aa), fontSize: 16),
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

  Widget _buildErrorState(String error) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            const Color(0xFF1a1a2e),
            const Color(0xFF0f0f0f),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1a1a2e).withOpacity(0.8),
                const Color(0xFF16213e).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFef4444).withOpacity(0.3), width: 1),
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
                child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFef4444), size: 48),
              ),
              const SizedBox(height: 32),
              Text(
                "Connection Lost",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: TextStyle(
                  color: const Color(0xFFd4d4d8),
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _onRefresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF6366f1), const Color(0xFF8b5cf6)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    "Reconnect",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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

  Widget _buildLoadingMoreIndicator(PhotoProvider provider) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
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
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF6366f1)),
                ),
              ),
              const SizedBox(width: 12),
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
    );
  }
}

// Enhanced Photo Card Component
class EnhancedPhotoCard extends StatefulWidget {
  final Photo photo;
  final int index;
  final Size screenSize;

  const EnhancedPhotoCard({
    Key? key,
    required this.photo,
    required this.index,
    required this.screenSize,
  }) : super(key: key);

  @override
  _EnhancedPhotoCardState createState() => _EnhancedPhotoCardState();
}

class _EnhancedPhotoCardState extends State<EnhancedPhotoCard>
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
    final cardWidth = (widget.screenSize.width - 32 - (16 * (crossAxisCount - 1))) / crossAxisCount;

    if (widget.photo.width != null &&
        widget.photo.height != null &&
        widget.photo.width! > 0 &&
        widget.photo.height! > 0) {
      final aspectRatio = widget.photo.width! / widget.photo.height!;
      final calculatedHeight = cardWidth / aspectRatio;
      return calculatedHeight.clamp(
        isDesktop ? 200.0 : isTablet ? 180.0 : 150.0,
        isDesktop ? 450.0 : isTablet ? 400.0 : 350.0,
      );
    }

    final heights = [
      220.0, 280.0, 240.0, 320.0, 200.0, 360.0, 260.0, 300.0, 180.0, 340.0
    ];
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
        tag: 'photo_${widget.photo.id}_${_photoType}',
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
                      widget.screenSize.width > 1024 ? 20 :
                      widget.screenSize.width > 600 ? 16 : 14,
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
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      widget.screenSize.width > 1024 ? 20 :
                      widget.screenSize.width > 600 ? 16 : 14,
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
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: _isHovering ? 1.03 : 1.0,
      child: Image.network(
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
            Colors.black.withOpacity(0.7),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF8b5cf6), const Color(0xFFa855f7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  widget.photo.photographer,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 12 : 11,
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

// Particle system for animated background
class Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      // Update particle position
      final newY = (particle.y + (animationValue * particle.speed)) % 1.2;

      // Create gradient effect
      final gradient = RadialGradient(
        colors: [
          const Color(0xFF6366f1).withOpacity(particle.opacity),
          const Color(0xFF8b5cf6).withOpacity(particle.opacity * 0.5),
          Colors.transparent,
        ],
      );

      paint.shader = gradient.createShader(
        Rect.fromCircle(
          center: Offset(particle.x * size.width, newY * size.height),
          radius: particle.size,
        ),
      );

      canvas.drawCircle(
        Offset(particle.x * size.width, newY * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// Photo Search Delegate
class PhotoSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'Search wallpapers...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF71717a)),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
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
      'Nature', 'Abstract', 'City', 'Minimal', 'Dark', 'Landscape',
      'Ocean', 'Mountains', 'Space', 'Technology', 'Animals', 'Flowers'
    ];

    final filteredSuggestions = suggestions
        .where((suggestion) => suggestion.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return Container(
      color: Colors.black,
      child: ListView.builder(
        itemCount: filteredSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = filteredSuggestions[index];
          return ListTile(
            title: Text(
              suggestion,
              style: const TextStyle(color: Colors.white),
            ),
            leading: const Icon(Icons.search, color: Color(0xFF6366f1)),
            onTap: () {
              query = suggestion;
              close(context, suggestion);
            },
          );
        },
      ),
    );
  }
}
