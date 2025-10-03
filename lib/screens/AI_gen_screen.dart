// lib/screens/ai_generate_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

  // Enhanced Animation controllers
  late AnimationController _starsController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _breathingController;
  late AnimationController _rotateController;

  late Animation<double> _starsAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _rotateAnimation;

  String _selectedStyle = 'flux';
  final String _selectedSize = '1024x1024';

  // Enhanced star animation data
  List<StarData> _stars = [];
  List<FloatingOrb> _orbs = [];

  // Cache for failed image URLs
  final Set<String> _failedUrls = {};
  final Map<String, Uint8List> _imageCache = {};

  final List<Map<String, dynamic>> _aiStyles = [
    {
      'id': 'flux',
      'name': 'Realistic',
      'icon': '🎯',
      'gradient': [const Color(0xFF6366f1), const Color(0xFF8b5cf6)],
      'description': 'Photorealistic images',
    },
    {
      'id': 'flux-realism',
      'name': 'Enhanced',
      'icon': '✨',
      'gradient': [const Color(0xFF10b981), const Color(0xFF06d6a0)],
      'description': 'Ultra-realistic visuals',
    },
    {
      'id': 'flux-anime',
      'name': 'Anime',
      'icon': '🎨',
      'gradient': [const Color(0xFFf59e0b), const Color(0xFFfbbf24)],
      'description': 'Anime-style artwork',
    },
    {
      'id': 'flux-3d',
      'name': '3D Art',
      'icon': '🎭',
      'gradient': [const Color(0xFF8b5cf6), const Color(0xFFa855f7)],
      'description': '3D rendered images',
    },
  ];

  final List<String> _quickPrompts = [
    "Ethereal mountain landscape at sunrise",
    "Neon cyberpunk cityscape with rain",
    "Minimal geometric patterns in gold",
    "Cosmic galaxy nebula with stars",
    "Serene ocean sunset with waves",
    "Abstract fluid art in purple tones",
    "Futuristic architecture with lights",
    "Mystical forest with glowing plants",
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateStars();
    _generateOrbs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoProvider>().switchMode('generate');
    });
  }

  void _initializeAnimations() {
    _starsController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _starsAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _starsController, curve: Curves.linear),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _breathingAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    _fadeController.forward();
  }

  void _generateStars() {
    _stars = List.generate(80, (index) {
      return StarData(
        x: Random().nextDouble(),
        y: Random().nextDouble(),
        size: Random().nextDouble() * 3 + 1,
        speed: Random().nextDouble() * 0.6 + 0.1,
        opacity: Random().nextDouble() * 0.8 + 0.2,
        twinkle: Random().nextDouble() * 3 + 1,
        color: [
          Colors.white,
          const Color(0xFF6366f1),
          const Color(0xFF8b5cf6),
          const Color(0xFFa855f7)
        ][Random().nextInt(4)],
      );
    });
  }

  void _generateOrbs() {
    _orbs = List.generate(6, (index) {
      return FloatingOrb(
        x: Random().nextDouble(),
        y: Random().nextDouble(),
        size: Random().nextDouble() * 150 + 100,
        speed: Random().nextDouble() * 0.3 + 0.1,
        opacity: Random().nextDouble() * 0.3 + 0.1,
        color: [
          const Color(0xFF6366f1),
          const Color(0xFF8b5cf6),
          const Color(0xFFa855f7),
          const Color(0xFF10b981),
          const Color(0xFFf59e0b),
        ][Random().nextInt(5)],
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
    _breathingController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 2.0,
            colors: [
              Color(0xFF0a0a0f),
              Color(0xFF05050a),
              Color(0xFF000000),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Enhanced animated background
            _buildEnhancedStarsBackground(),

            // Main content
            Consumer<PhotoProvider>(
              builder: (context, provider, child) {
                return CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildResponsiveHeader(size),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 40 : isTablet ? 32 : 24,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          SizedBox(height: isDesktop ? 50 : isTablet ? 45 : 40),
                          _buildResponsivePromptSection(provider, size),
                          SizedBox(height: isDesktop ? 40 : isTablet ? 36 : 32),
                          _buildResponsiveStyleGrid(size),
                          SizedBox(height: isDesktop ? 40 : isTablet ? 36 : 32),
                          _buildResponsiveQuickPrompts(size),
                          SizedBox(height: isDesktop ? 50 : isTablet ? 45 : 40),
                          _buildResponsiveGeneratedGrid(provider, size),
                          const SizedBox(height: 120), // Bottom padding
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedStarsBackground() {
    return AnimatedBuilder(
      animation:
      Listenable.merge([_starsAnimation, _breathingAnimation, _rotateAnimation]),
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 2.5,
              colors: [
                Color(0xFF0a0a0f),
                Color(0xFF05050a),
                Color(0xFF000000),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Floating orbs
              CustomPaint(
                painter: OrbsPainter(_orbs, _breathingAnimation.value),
                child: Container(),
              ),
              // Animated stars
              CustomPaint(
                painter: EnhancedStarsPainter(_stars, _starsAnimation.value),
                child: Container(),
              ),
              // Rotating gradient overlay
              Transform.rotate(
                angle: _rotateAnimation.value * 2 * pi,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF6366f1).withOpacity(0.1),
                        Colors.transparent,
                        const Color(0xFF8b5cf6).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  SliverAppBar _buildResponsiveHeader(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      expandedHeight: isDesktop ? 220 : isTablet ? 200 : 180,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: EdgeInsets.only(
            top: isDesktop ? 100 : isTablet ? 90 : 80,
            left: isDesktop ? 40 : isTablet ? 32 : 24,
            right: isDesktop ? 40 : isTablet ? 32 : 24,
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced brand section
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: isDesktop ? 16 : isTablet ? 14 : 12,
                            height: isDesktop ? 16 : isTablet ? 14 : 12,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6366f1),
                                  Color(0xFF8b5cf6),
                                  Color(0xFFa855f7),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                  const Color(0xFF6366f1).withOpacity(0.6),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: isDesktop ? 20 : isTablet ? 18 : 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Colors.white,
                              Color(0xFFe5e5e5),
                              Color(0xFFa1a1aa),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            "AI Creator",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 36 : isTablet ? 32 : 28,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: isDesktop ? 8 : isTablet ? 7 : 6),
                        Text(
                          "Create anything you can imagine",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
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
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
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
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              // Add AI settings or help
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResponsivePromptSection(PhotoProvider provider, Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.04),
            ],
          ),
          borderRadius:
          BorderRadius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366f1).withOpacity(0.1),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 28 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: const Color(0xFF6366f1),
                        size: isDesktop ? 24 : isTablet ? 22 : 20,
                      ),
                      SizedBox(width: isDesktop ? 12 : isTablet ? 10 : 8),
                      Text(
                        "Describe Your Vision",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isDesktop ? 20 : isTablet ? 18 : 16),
                  TextField(
                    controller: _promptController,
                    maxLines: isDesktop ? 4 : isTablet ? 3 : 3,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                      fontWeight: FontWeight.w300,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText:
                      "A futuristic cityscape at sunset with neon lights reflecting off wet streets...",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                        fontWeight: FontWeight.w300,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _generateImage(provider);
                      }
                    },
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(
                isDesktop ? 32 : isTablet ? 28 : 24,
                0,
                isDesktop ? 32 : isTablet ? 28 : 24,
                isDesktop ? 32 : isTablet ? 28 : 24,
              ),
              child: _buildResponsiveGenerateButton(provider, size),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveGenerateButton(PhotoProvider provider, Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return GestureDetector(
      onTap: provider.isGenerating ? null : () => _generateImage(provider),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 20 : isTablet ? 18 : 16,
        ),
        decoration: BoxDecoration(
          gradient: provider.isGenerating
              ? LinearGradient(
            colors: [
              const Color(0xFF4f46e5).withOpacity(0.7),
              const Color(0xFF6366f1).withOpacity(0.7),
            ],
          )
              : const LinearGradient(
            colors: [
              Color(0xFF6366f1),
              Color(0xFF8b5cf6),
              Color(0xFFa855f7),
            ],
          ),
          borderRadius:
          BorderRadius.circular(isDesktop ? 20 : isTablet ? 18 : 16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366f1).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (provider.isGenerating) ...[
              SizedBox(
                width: isDesktop ? 24 : isTablet ? 22 : 20,
                height: isDesktop ? 24 : isTablet ? 22 : 20,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),
              Text(
                "Creating Magic...",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                ),
              ),
            ] else ...[
              Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: isDesktop ? 24 : isTablet ? 22 : 20,
              ),
              SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),
              Text(
                "Generate Wallpaper",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveStyleGrid(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                color: const Color(0xFF6366f1),
                size: isDesktop ? 24 : isTablet ? 22 : 20,
              ),
              SizedBox(width: isDesktop ? 12 : isTablet ? 10 : 8),
              Text(
                "Art Style",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 22 : isTablet ? 20 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : isTablet ? 3 : 2,
              crossAxisSpacing: isDesktop ? 20 : isTablet ? 16 : 12,
              mainAxisSpacing: isDesktop ? 20 : isTablet ? 16 : 12,
              childAspectRatio: isDesktop ? 1.1 : isTablet ? 1.0 : 0.9,
            ),
            itemCount: _aiStyles.length,
            itemBuilder: (context, index) {
              final style = _aiStyles[index];
              final isSelected = _selectedStyle == style['id'];

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedStyle = style['id']);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.all(isDesktop ? 20 : isTablet ? 16 : 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: style['gradient'])
                        : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
                    borderRadius:
                    BorderRadius.circular(isDesktop ? 20 : isTablet ? 16 : 12),
                    border: Border.all(
                      color: isSelected
                          ? style['gradient'][0].withOpacity(0.8)
                          : Colors.white.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: style['gradient'][0].withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        style['icon'],
                        style: TextStyle(
                          fontSize: isDesktop ? 32 : isTablet ? 28 : 24,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
                      Text(
                        style['name'],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.8),
                          fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isDesktop ? 6 : isTablet ? 5 : 4),
                      Text(
                        style['description'],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white.withOpacity(0.8)
                              : Colors.white.withOpacity(0.5),
                          fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveQuickPrompts(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: const Color(0xFF6366f1),
                size: isDesktop ? 24 : isTablet ? 22 : 20,
              ),
              SizedBox(width: isDesktop ? 12 : isTablet ? 10 : 8),
              Text(
                "Quick Ideas",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 22 : isTablet ? 20 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 20 : isTablet ? 16 : 12),
          Wrap(
            spacing: isDesktop ? 16 : isTablet ? 14 : 12,
            runSpacing: isDesktop ? 16 : isTablet ? 14 : 12,
            children: _quickPrompts.map((prompt) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _promptController.text = prompt;
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 20 : isTablet ? 16 : 12,
                    vertical: isDesktop ? 12 : isTablet ? 10 : 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
                    borderRadius:
                    BorderRadius.circular(isDesktop ? 25 : isTablet ? 22 : 20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    prompt,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                      fontWeight: FontWeight.w400,
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

  Widget _buildResponsiveGeneratedGrid(PhotoProvider provider, Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    if (provider.generatedPhotos.isEmpty && !provider.isGenerating) {
      return _buildResponsiveEmptyState(size);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: const Color(0xFF6366f1),
                    size: isDesktop ? 24 : isTablet ? 22 : 20,
                  ),
                  SizedBox(width: isDesktop ? 12 : isTablet ? 10 : 8),
                  Text(
                    "Your Creations",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 22 : isTablet ? 20 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (provider.generatedPhotos.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    provider.clearGeneratedImages();
                    _failedUrls.clear();
                    _imageCache.clear();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 16 : isTablet ? 14 : 12,
                      vertical: isDesktop ? 8 : isTablet ? 7 : 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius:
                      BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.clear_all_rounded,
                          color: Colors.white.withOpacity(0.8),
                          size: isDesktop ? 18 : isTablet ? 16 : 14,
                        ),
                        SizedBox(width: isDesktop ? 8 : isTablet ? 7 : 6),
                        Text(
                          "Clear All",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),

          // Loading indicator during generation
          if (provider.isGenerating && provider.generatedPhotos.isEmpty)
            _buildGenerationLoadingState(size),

          // Generated images grid
          if (provider.generatedPhotos.isNotEmpty)
            MasonryGridView.count(
              crossAxisCount: isDesktop ? 3 : isTablet ? 2 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: isDesktop ? 20 : isTablet ? 16 : 12,
              crossAxisSpacing: isDesktop ? 20 : isTablet ? 16 : 12,
              itemCount: provider.generatedPhotos.length,
              itemBuilder: (context, index) {
                final photo = provider.generatedPhotos[index];
                return _buildResponsiveImageCard(photo, provider, size, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGenerationLoadingState(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 60 : isTablet ? 50 : 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius:
        BorderRadius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: isDesktop ? 80 : isTablet ? 70 : 60,
                  height: isDesktop ? 80 : isTablet ? 70 : 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6366f1),
                        Color(0xFF8b5cf6),
                        Color(0xFFa855f7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366f1).withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SizedBox(
                      width: isDesktop ? 40 : isTablet ? 35 : 30,
                      height: isDesktop ? 40 : isTablet ? 35 : 30,
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
          Text(
            "Creating Your Masterpiece",
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
          Text(
            "AI is working its magic to bring your vision to life",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveImageCard(
      Photo photo, PhotoProvider provider, Size size, int index) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ImageDetailScreen(photo: photo),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      },
      child: Hero(
        tag: 'generated_${photo.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(isDesktop ? 24 : isTablet ? 20 : 16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius:
            BorderRadius.circular(isDesktop ? 24 : isTablet ? 20 : 16),
            child: Stack(
              children: [
                _buildResponsiveImageDisplay(photo.src.original, provider, size),

                // Gradient overlay
                Container(
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
                ),

                // AI Badge
                Positioned(
                  top: isDesktop ? 16 : isTablet ? 14 : 12,
                  right: isDesktop ? 16 : isTablet ? 14 : 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 12 : isTablet ? 10 : 8,
                      vertical: isDesktop ? 6 : isTablet ? 5 : 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF6366f1),
                          Color(0xFF8b5cf6),
                        ],
                      ),
                      borderRadius:
                      BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366f1).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: isDesktop ? 14 : isTablet ? 13 : 12,
                        ),
                        SizedBox(width: isDesktop ? 6 : isTablet ? 5 : 4),
                        Text(
                          "AI",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom info
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(isDesktop ? 20 : isTablet ? 16 : 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedStyle.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 8 : isTablet ? 7 : 6,
                            vertical: isDesktop ? 4 : isTablet ? 3 : 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius:
                            BorderRadius.circular(isDesktop ? 8 : isTablet ? 7 : 6),
                          ),
                          child: Text(
                            "#${index + 1}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 10 : isTablet ? 9 : 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveImageDisplay(
      String imageUrl, PhotoProvider provider, Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    // Check if it's a data URL (base64 encoded image)
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',')[1];
        final imageBytes = base64Decode(base64String);
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: _getRandomHeight(size),
        );
      } catch (e) {
        return _buildErrorPlaceholder(size);
      }
    }

    // Check if provider has cached image data
    final cachedData = provider.getCachedImageData(imageUrl);
    if (cachedData != null) {
      return Image.memory(
        cachedData,
        fit: BoxFit.cover,
        width: double.infinity,
        height: _getRandomHeight(size),
      );
    }

    // For network URLs, use FutureBuilder with retry logic
    return FutureBuilder<Uint8List?>(
      future: _loadImageWithRetry(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: _getRandomHeight(size),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: isDesktop ? 32 : isTablet ? 28 : 24,
                    height: isDesktop ? 32 : isTablet ? 28 : 24,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF6366f1)),
                    ),
                  ),
                  SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: isDesktop ? 14 : isTablet ? 12 : 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _buildErrorPlaceholder(size);
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: _getRandomHeight(size),
        );
      },
    );
  }

  Widget _buildErrorPlaceholder(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      height: _getRandomHeight(size),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1a1a2e).withOpacity(0.8),
            const Color(0xFF16213e).withOpacity(0.6),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: const Color(0xFF71717a),
            size: isDesktop ? 32 : isTablet ? 28 : 24,
          ),
          SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
          Text(
            'Failed to load',
            style: TextStyle(
              color: const Color(0xFF71717a),
              fontSize: isDesktop ? 14 : isTablet ? 12 : 10,
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _loadImageWithRetry(String url, [int retries = 3]) async {
    if (_failedUrls.contains(url)) return null;
    if (_imageCache.containsKey(url)) return _imageCache[url];

    for (int i = 0; i < retries; i++) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 15),
        );

        if (response.statusCode == 200) {
          final imageData = response.bodyBytes;
          _imageCache[url] = imageData;
          return imageData;
        }
      } catch (e) {
        if (i == retries - 1) {
          _failedUrls.add(url);
          return null;
        }
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
    return null;
  }

  double _getRandomHeight(Size size) {
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 600;

    final heights = [
      isDesktop ? 280.0 : isTablet ? 240.0 : 200.0,
      isDesktop ? 350.0 : isTablet ? 300.0 : 250.0,
      isDesktop ? 320.0 : isTablet ? 270.0 : 220.0,
      isDesktop ? 400.0 : isTablet ? 340.0 : 280.0,
      isDesktop ? 260.0 : isTablet ? 220.0 : 180.0,
    ];
    return heights[Random().nextInt(heights.length)];
  }

  Widget _buildResponsiveEmptyState(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 60 : isTablet ? 50 : 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius:
        BorderRadius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _breathingAnimation.value,
                child: Container(
                  width: isDesktop ? 120 : isTablet ? 100 : 80,
                  height: isDesktop ? 120 : isTablet ? 100 : 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366f1).withOpacity(0.3),
                        const Color(0xFF8b5cf6).withOpacity(0.2),
                        const Color(0xFFa855f7).withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: const Color(0xFF6366f1),
                    size: isDesktop ? 48 : isTablet ? 40 : 32,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
          Text(
            "Your Canvas Awaits",
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
          Text(
            "Enter a creative prompt above to generate\nstunning AI wallpapers instantly",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
          _buildFeatureHighlights(size),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlights(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    final features = [
      {
        'icon': Icons.flash_on_rounded,
        'title': 'Lightning Fast',
        'description': 'Generate in seconds',
      },
      {
        'icon': Icons.high_quality_rounded,
        'title': 'HD Quality',
        'description': 'Crystal clear images',
      },
      {
        'icon': Icons.palette_rounded,
        'title': 'Multiple Styles',
        'description': 'Realistic to anime',
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: features.map((feature) {
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 16 : isTablet ? 14 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366f1).withOpacity(0.2),
                    const Color(0xFF8b5cf6).withOpacity(0.1),
                  ],
                ),
                borderRadius:
                BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
              ),
              child: Icon(
                feature['icon'] as IconData,
                color: const Color(0xFF6366f1),
                size: isDesktop ? 24 : isTablet ? 22 : 20,
              ),
            ),
            SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
            Text(
              feature['title'] as String,
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isDesktop ? 6 : isTablet ? 5 : 4),
            Text(
              feature['description'] as String,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _generateImage(PhotoProvider provider) async {
    final prompt = _promptController.text.trim();

    if (prompt.isEmpty) {
      _showErrorMessage("Please enter a creative prompt first!");
      return;
    }

    HapticFeedback.mediumImpact();

    // Show generation started message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('🎨 AI is creating your masterpiece...'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6366f1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );

    try {
      // Call the enhanced generation method
      await _performEnhancedGeneration(provider, prompt);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('✨ Your AI wallpaper is ready!')),
              ],
            ),
            backgroundColor: const Color(0xFF10b981),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage("Generation failed. Please try again!");
      }
    }
  }

  Future<void> _performEnhancedGeneration(
      PhotoProvider provider, String prompt) async {
    // Enhanced prompt with style and quality modifiers
    final enhancedPrompt = _buildEnhancedPrompt(prompt);

    // Multiple API endpoints for better reliability
    final apiEndpoints = [
      'https://api.pollinations.ai/prompt/$enhancedPrompt?width=1024&height=1024&seed=${Random().nextInt(1000000)}',
      'https://image.pollinations.ai/prompt/$enhancedPrompt?width=1024&height=1024&seed=${Random().nextInt(1000000)}',
    ];

    try {
      await provider.generateImage(enhancedPrompt, apiEndpoints);
    } catch (e) {
      // Fallback to basic generation
      await provider.generateBasicImage(prompt);
    }
  }

  String _buildEnhancedPrompt(String basePrompt) {
    final styleModifiers = {
      'flux': 'photorealistic, high quality, detailed, 8K resolution',
      'flux-realism':
      'ultra realistic, hyperdetailed, professional photography, cinematic lighting',
      'flux-anime':
      'anime style, vibrant colors, manga artwork, Japanese animation',
      'flux-3d':
      '3D rendered, volumetric lighting, octane render, unreal engine',
    };

    final qualityTerms = [
      'masterpiece',
      'best quality',
      'highly detailed',
      'beautiful composition',
      'perfect lighting',
    ];

    final styleModifier =
        styleModifiers[_selectedStyle] ?? styleModifiers['flux']!;
    final randomQuality = qualityTerms[Random().nextInt(qualityTerms.length)];

    return '$basePrompt, $styleModifier, $randomQuality, wallpaper, digital art';
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFef4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// Enhanced Star and Orb Animation Classes
class StarData {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;
  final double twinkle;
  final Color color;

  StarData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.twinkle,
    required this.color,
  });
}

class FloatingOrb {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;
  final Color color;

  FloatingOrb({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
  });
}

class EnhancedStarsPainter extends CustomPainter {
  final List<StarData> stars;
  final double animationValue;

  EnhancedStarsPainter(this.stars, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < stars.length; i++) {
      final star = stars[i];

      // Update star position
      final newY = (star.y + (animationValue * star.speed)) % 1.2;
      if (newY > 1.0) {
        star.y = -0.2;
        star.x = Random().nextDouble();
      } else {
        star.y = newY;
      }

      // Twinkling effect
      final twinkleOffset = sin(animationValue * pi * star.twinkle) * 0.5 + 0.5;
      final currentOpacity = (star.opacity * twinkleOffset).clamp(0.0, 1.0);

      // Create gradient paint for each star
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            star.color.withOpacity(currentOpacity),
            star.color.withOpacity(currentOpacity * 0.5),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(star.x * size.width, star.y * size.height),
            radius: star.size * 2,
          ),
        );

      // Draw star
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );

      // Add sparkle effect for larger stars
      if (star.size > 2.0 && twinkleOffset > 0.7) {
        final sparklePaint = Paint()
          ..color = Colors.white.withOpacity(currentOpacity * 0.8)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

        final center = Offset(star.x * size.width, star.y * size.height);
        final sparkleSize = star.size * 1.5;

        // Draw cross sparkle
        canvas.drawLine(
          Offset(center.dx - sparkleSize, center.dy),
          Offset(center.dx + sparkleSize, center.dy),
          sparklePaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - sparkleSize),
          Offset(center.dx, center.dy + sparkleSize),
          sparklePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class OrbsPainter extends CustomPainter {
  final List<FloatingOrb> orbs;
  final double animationValue;

  OrbsPainter(this.orbs, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in orbs) {
      // Update orb position with gentle floating motion
      final newY = (orb.y + (animationValue * orb.speed * 0.1)) % 1.3;
      final newX = orb.x + sin(animationValue * pi * 0.5) * 0.02;

      if (newY > 1.1) {
        orb.y = -0.3;
        orb.x = Random().nextDouble();
      } else {
        orb.y = newY;
        orb.x = newX.clamp(0.0, 1.0);
      }

      // Breathing effect
      final breathingScale = 0.8 + (sin(animationValue * pi * 2) * 0.2);
      final currentSize = orb.size * breathingScale;

      // Create gradient paint
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withOpacity(orb.opacity),
            orb.color.withOpacity(orb.opacity * 0.5),
            orb.color.withOpacity(orb.opacity * 0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(
          Rect.fromCircle(
            center: Offset(orb.x * size.width, orb.y * size.height),
            radius: currentSize,
          ),
        );

      // Draw orb
      canvas.drawCircle(
        Offset(orb.x * size.width, orb.y * size.height),
        currentSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// Extension for PhotoProvider to handle AI generation
extension AIGeneration on PhotoProvider {
  Future<void> generateImage(String prompt, List<String> apiEndpoints) async {
    setGenerating(true);

    try {
      String? successfulUrl;

      // Try each endpoint
      for (final endpoint in apiEndpoints) {
        try {
          final response = await http.head(Uri.parse(endpoint)).timeout(
            const Duration(seconds: 10),
          );

          if (response.statusCode == 200) {
            successfulUrl = endpoint;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      if (successfulUrl != null) {
        // Create Photo object for the generated image
        final generatedPhoto = Photo(
          id: DateTime.now().millisecondsSinceEpoch,
          photographer: 'AI Generated',
          src: PhotoSrc(
            original: successfulUrl,
            large2x: successfulUrl,
            large: successfulUrl,
            medium: successfulUrl,
            small: successfulUrl,
            portrait: successfulUrl,
            landscape: successfulUrl,
            tiny: successfulUrl,
          ),
          width: 1024,
          height: 1024,
          alt: prompt,
          avgColor: '#6366f1',
          photographerUrl: 'https://wallhub.app',
          photographerId: 1,
          url: 'https://wallhub.app',
          liked: false,
        );

        addGeneratedPhoto(generatedPhoto);
      } else {
        throw Exception('All API endpoints failed');
      }
    } finally {
      setGenerating(false);
    }
  }

  Future<void> generateBasicImage(String prompt) async {
    // Fallback method with simpler generation
    final basicUrl =
        'https://api.pollinations.ai/prompt/${Uri.encodeComponent(prompt)}?width=1024&height=1024';

    final generatedPhoto = Photo(
      id: DateTime.now().millisecondsSinceEpoch,
      photographer: 'AI Generated',
      src: PhotoSrc(
        original: basicUrl,
        large2x: basicUrl,
        large: basicUrl,
        medium: basicUrl,
        small: basicUrl,
        portrait: basicUrl,
        landscape: basicUrl,
        tiny: basicUrl,
      ),
      width: 1024,
      height: 1024,
      alt: prompt,
      avgColor: '#6366f1',
      photographerUrl: 'https://wallhub.app',
      photographerId: 1,
      url: 'https://wallhub.app',
      liked: false,
    );

    addGeneratedPhoto(generatedPhoto);
  }
}