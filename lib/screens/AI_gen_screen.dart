// lib/screens/ai_generate_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:velocity_x/velocity_x.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/photo_provider.dart';
import '../models/photo_model.dart';
import 'image_detail_screen.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AIGenerateScreen extends StatefulWidget {
  const AIGenerateScreen({Key? key}) : super(key: key);

  @override
  _AIGenerateScreenState createState() => _AIGenerateScreenState();
}

class _AIGenerateScreenState extends State<AIGenerateScreen>
    with TickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Animation controllers for stars and UI
  late AnimationController _starsController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  late Animation<double> _starsAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  String _selectedStyle = 'flux';
  String _selectedSize = '1024x1024';

  // Star animation data
  List<StarData> _stars = [];

  // Cache for failed image URLs
  final Set<String> _failedUrls = <String>{};
  final Map<String, Uint8List> _imageCache = <String, Uint8List>{};

  final List<Map<String, dynamic>> _aiStyles = [
    {
      'id': 'flux',
      'name': 'Realistic',
      'icon': '🎯',
      'color': const Color(0xFF6366f1),
    },
    {
      'id': 'flux-realism',
      'name': 'Enhanced',
      'icon': '✨',
      'color': const Color(0xFF10b981),
    },
    {
      'id': 'flux-anime',
      'name': 'Anime',
      'icon': '🎨',
      'color': const Color(0xFFf59e0b),
    },
    {
      'id': 'flux-3d',
      'name': '3D Art',
      'icon': '🎭',
      'color': const Color(0xFF8b5cf6),
    },
  ];

  final List<String> _quickPrompts = [
    "Ethereal mountain landscape",
    "Neon cyberpunk cityscape",
    "Minimal geometric patterns",
    "Cosmic galaxy nebula",
    "Serene ocean sunset",
    "Abstract fluid art",
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateStars();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoProvider>().switchMode('generate');
    });
  }

  void _initializeAnimations() {
    _starsController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _starsAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _starsController, curve: Curves.linear),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  void _generateStars() {
    _stars = List.generate(50, (index) {
      return StarData(
        x: Random().nextDouble(),
        y: Random().nextDouble(),
        size: Random().nextDouble() * 3 + 1,
        speed: Random().nextDouble() * 0.5 + 0.1,
        opacity: Random().nextDouble() * 0.8 + 0.2,
        twinkle: Random().nextDouble() * 2 + 1,
      );
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _starsController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated stars background
          _buildStarsBackground(),

          // Main content
          Consumer<PhotoProvider>(
            builder: (context, provider, child) {
              return CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildMinimalHeader(),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        40.heightBox,
                        _buildPromptSection(provider),
                        32.heightBox,
                        _buildStyleGrid(),
                        32.heightBox,
                        _buildQuickPrompts(),
                        40.heightBox,
                        _buildGeneratedGrid(provider),
                        100.heightBox, // Bottom padding
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStarsBackground() {
    return AnimatedBuilder(
      animation: _starsAnimation,
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 2.0,
              colors: [
                Color(0xFF0a0a0f),
                Color(0xFF000000),
              ],
            ),
          ),
          child: CustomPaint(
            painter: StarsPainter(_stars, _starsAnimation.value),
            child: Container(),
          ),
        );
      },
    );
  }

  Widget _buildMinimalHeader() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 160,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6366f1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF6366f1),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    16.widthBox,
                    "AI Creator"
                        .text
                        .white
                        .size(28)
                        .fontWeight(FontWeight.w300)
                        .letterSpacing(0.5)
                        .make(),
                  ],
                ),
                8.heightBox,
                "Create anything you can imagine"
                    .text
                    .color(Colors.white54)
                    .size(16)
                    .fontWeight(FontWeight.w300)
                    .make(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptSection(PhotoProvider provider) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _promptController,
                maxLines: 3,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: "Describe your vision...",
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _buildGenerateButton(provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(PhotoProvider provider) {
    return GestureDetector(
      onTap: () => _generateImage(provider),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: provider.isGenerating
              ? const LinearGradient(
            colors: [Color(0xFF4f46e5), Color(0xFF6366f1)],
          )
              : const LinearGradient(
            colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366f1).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (provider.isGenerating) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              12.widthBox,
              "Creating..."
                  .text
                  .white
                  .fontWeight(FontWeight.w400)
                  .size(16)
                  .make(),
            ] else ...[
              "✨".text.size(20).make(),
              12.widthBox,
              "Generate"
                  .text
                  .white
                  .fontWeight(FontWeight.w400)
                  .size(16)
                  .make(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStyleGrid() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          "Style"
              .text
              .white
              .size(18)
              .fontWeight(FontWeight.w300)
              .make(),
          20.heightBox,
          Row(
            children: _aiStyles.asMap().entries.map((entry) {
              final index = entry.key;
              final style = entry.value;
              final isSelected = _selectedStyle == style['id'];

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedStyle = style['id']);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.only(
                      right: index < _aiStyles.length - 1 ? 12 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? style['color'].withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? style['color']
                            : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          style['icon'],
                          style: const TextStyle(fontSize: 24),
                        ),
                        8.heightBox,
                        Text(
                          style['name'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

  Widget _buildQuickPrompts() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          "Quick Ideas"
              .text
              .white
              .size(18)
              .fontWeight(FontWeight.w300)
              .make(),
          16.heightBox,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _quickPrompts.map((prompt) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _promptController.text = prompt;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    prompt,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
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

  Widget _buildGeneratedGrid(PhotoProvider provider) {
    if (provider.generatedPhotos.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              "Your Creations"
                  .text
                  .white
                  .size(18)
                  .fontWeight(FontWeight.w300)
                  .make(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  provider.clearGeneratedImages();
                  _failedUrls.clear();
                  _imageCache.clear();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: "Clear All"
                      .text
                      .white
                      .size(12)
                      .fontWeight(FontWeight.w300)
                      .make(),
                ),
              ),
            ],
          ),
          24.heightBox,
          MasonryGridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            itemCount: provider.generatedPhotos.length,
            itemBuilder: (context, index) {
              final photo = provider.generatedPhotos[index];
              return _buildImageCard(photo, provider);
            },
          ),
        ],
      ),
    );
  }

  // FIXED: Updated image card builder with proper provider access
  Widget _buildImageCard(Photo photo, PhotoProvider provider) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ImageDetailScreen(photo: photo),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: Hero(
        tag: 'generated_${photo.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // FIXED: Use the proper image display method
                _buildImageDisplay(photo.src.original, provider),

                // AI Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: "AI"
                        .text
                        .white
                        .size(10)
                        .fontWeight(FontWeight.w400)
                        .make(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // FIXED: Proper image display method that handles both data URLs and network URLs
  Widget _buildImageDisplay(String imageUrl, PhotoProvider provider) {
    // Check if it's a data URL (base64 encoded image)
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',')[1];
        final imageBytes = base64Decode(base64String);
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200 + (Random().nextInt(100)).toDouble(),
          errorBuilder: (context, error, stackTrace) {
            print('Error displaying base64 image: $error');
            return _buildErrorPlaceholder();
          },
        );
      } catch (e) {
        print('Error decoding base64 image: $e');
        return _buildErrorPlaceholder();
      }
    }

    // Check if provider has cached image data
    final cachedData = provider.getCachedImageData(imageUrl);
    if (cachedData != null) {
      return Image.memory(
        cachedData,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200 + (Random().nextInt(100)).toDouble(),
      );
    }

    // For network URLs, use FutureBuilder with retry logic
    return FutureBuilder<Uint8List?>(
      future: _loadImageWithRetry(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200 + (Random().nextInt(100)).toDouble(),
            color: Colors.white.withOpacity(0.05),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: const Color(0xFF6366f1),
                      strokeWidth: 2,
                    ),
                  ),
                  8.heightBox,
                  "Loading..."
                      .text
                      .color(Colors.white54)
                      .size(10)
                      .make(),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200 + (Random().nextInt(100)).toDouble(),
          );
        }

        return _buildErrorPlaceholder();
      },
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      height: 200,
      color: Colors.white.withOpacity(0.05),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white54,
              size: 32,
            ),
            8.heightBox,
            "Failed to load"
                .text
                .color(Colors.white54)
                .size(10)
                .make(),
          ],
        ),
      ),
    );
  }

  // FIXED: Improved image loading with better error handling
  Future<Uint8List?> _loadImageWithRetry(String imageUrl) async {
    // Skip if it's already a data URL
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',')[1];
        return base64Decode(base64String);
      } catch (e) {
        print('Error decoding data URL: $e');
        return null;
      }
    }

    const maxRetries = 3;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        print('Loading image attempt ${attempt + 1}: $imageUrl');

        final response = await http.get(
          Uri.parse(imageUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; WallpaperApp/1.0)',
            'Accept': 'image/webp,image/png,image/jpeg,image/*,*/*;q=0.8',
            'Cache-Control': 'no-cache',
          },
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final contentType = response.headers['content-type'] ?? '';
          if (contentType.startsWith('image/') || response.bodyBytes.length > 1000) {
            print('Successfully loaded image: ${response.bodyBytes.length} bytes');
            return response.bodyBytes;
          } else {
            print('Invalid content type: $contentType');
          }
        } else {
          print('HTTP error: ${response.statusCode}');
        }

        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        }
      } catch (e) {
        print('Error loading image attempt ${attempt + 1}: $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        }
      }
    }

    return null;
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366f1).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6366f1),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF6366f1),
                  size: 28,
                ),
              ),
            ),
            24.heightBox,
            "Ready to Create?"
                .text
                .white
                .size(20)
                .fontWeight(FontWeight.w300)
                .make(),
            12.heightBox,
            "Describe your vision and watch\nAI bring it to life"
                .text
                .color(Colors.white54)
                .size(14)
                .fontWeight(FontWeight.w300)
                .center
                .lineHeight(1.5)
                .make(),
          ],
        ),
      ),
    );
  }

  void _generateImage(PhotoProvider provider) {
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a prompt'),
          backgroundColor: Colors.red.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    provider.setGenerationModel(_selectedStyle);
    provider.setGenerationSize(_selectedSize);
    provider.generateImageVariations(_promptController.text.trim(), count: 4);
  }
}

// Star data class for animation
class StarData {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;
  final double twinkle;

  StarData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.twinkle,
  });
}

// Custom painter for falling stars
class StarsPainter extends CustomPainter {
  final List<StarData> stars;
  final double animationValue;

  StarsPainter(this.stars, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final star in stars) {
      // Update star position for falling effect
      final newY = (star.y + (animationValue * star.speed)) % 1.2;

      // Create twinkling effect
      final twinkleOffset = sin(animationValue * star.twinkle * 2 * pi) * 0.3;
      final currentOpacity = (star.opacity + twinkleOffset).clamp(0.0, 1.0);

      paint.color = Colors.white.withOpacity(currentOpacity);

      // Draw star
      canvas.drawCircle(
        Offset(star.x * size.width, newY * size.height),
        star.size,
        paint,
      );

      // Draw star trails for larger stars
      if (star.size > 2) {
        for (int i = 1; i <= 3; i++) {
          final trailY = newY - (i * 0.01);
          if (trailY > 0) {
            paint.color = Colors.white.withOpacity(currentOpacity * (0.5 / i));
            canvas.drawCircle(
              Offset(star.x * size.width, trailY * size.height),
              star.size * (0.7 / i),
              paint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
