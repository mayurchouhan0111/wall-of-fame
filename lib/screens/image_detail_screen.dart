// lib/screens/image_detail_screen.dart
import 'package:flutter/foundation.dart';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:velocity_x/velocity_x.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/photo_model.dart';

class ImageDetailScreen extends StatefulWidget {
  final Photo photo;
  const ImageDetailScreen({Key? key, required this.photo}) : super(key: key);

  @override
  _ImageDetailScreenState createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen>
    with TickerProviderStateMixin {

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  // Video player controller
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _videoLoadFailed = false;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  // Helper method to safely get photo type
  String get _photoType {
    try {
      return widget.photo.type ?? 'photo';
    } catch (e) {
      return 'photo';
    }
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeMedia();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  void _initializeMedia() {
    if (_photoType == 'video') {
      _initializeVideoPlayer();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _initializeVideoPlayer() {
    setState(() {
      _isVideoLoading = true;
      _videoLoadFailed = false;
    });
    final videoUrls = _getCompatibleVideoUrls();
    _tryVideoUrls(videoUrls, 0);
  }

  List<String> _getCompatibleVideoUrls() {
    if (_photoType == 'video') {
      try {
        final videoUrl = widget.photo.src.original;
        if (videoUrl.isNotEmpty && (videoUrl.contains('.mp4') || videoUrl.contains('video'))) {
          return [videoUrl];
        }

        final possibleUrls = [
          widget.photo.src.large2x,
          widget.photo.src.portrait,
          widget.photo.src.landscape,
        ].where((url) => url.isNotEmpty && (url.contains('.mp4') || url.contains('video'))).toList();

        if (possibleUrls.isNotEmpty) {
          return possibleUrls;
        }
      } catch (e) {
        print('Error getting video URL: $e');
      }
    }

    // Fallback to sample videos for demo
    return [
      'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
      'https://www.learningcontainer.com/wp-content/uploads/2020/05/sample-mp4-file.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ];
  }

  void _tryVideoUrls(List<String> urls, int index) {
    if (index >= urls.length) {
      setState(() {
        _isVideoLoading = false;
        _videoLoadFailed = true;
        _isLoading = false;
      });
      return;
    }

    final url = urls[index];
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _isVideoLoading = false;
            _isLoading = false;
            _videoLoadFailed = false;
          });
          _videoController?.setLooping(true);
          _startAutoPlay();
        }
      }).catchError((error) {
        _tryVideoUrls(urls, index + 1);
      });
  }

  void _startAutoPlay() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _videoController != null && _isVideoInitialized) {
        _playPauseVideo();
      }
    });
  }

  void _playPauseVideo() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
          _isPlaying = false;
        } else {
          _videoController!.play();
          _isPlaying = true;
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _showControls && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  // Enhanced download functionality with progress tracking
  Future<void> _downloadFile() async {
    if (kIsWeb) {
      _showErrorSnackBar('Downloads not available on web');
      return;
    }

    if (_isDownloading) return;

    HapticFeedback.mediumImpact();
    final hasPermission = await _checkStoragePermission();

    if (!hasPermission) {
      _showErrorSnackBar('Storage permission required');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final downloadUrl = _getDownloadUrl();
      final fileName = _getFileName();

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        throw Exception('Download failed: ${streamedResponse.statusCode}');
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      final bytes = <int>[];
      int downloadedBytes = 0;

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;

        if (contentLength > 0) {
          setState(() {
            _downloadProgress = downloadedBytes / contentLength;
          });
        }
      }

      final uint8List = Uint8List.fromList(bytes);

      final result = await ImageGallerySaver.saveImage(
        uint8List,
        name: fileName,
        isReturnImagePathOfIOS: true,
      );

      if (result['isSuccess'] == true) {
        await _saveToAppDirectory(uint8List, fileName);
        _showSuccessSnackBar(
            _photoType == 'video'
                ? '🎬 Live wallpaper saved!'
                : '🖼️ Wallpaper saved!',
            result['filePath']
        );
      } else {
        final filePath = await _saveToAppDirectory(uint8List, fileName);
        _showSuccessSnackBar('Downloaded successfully', filePath);
      }
    } catch (e) {
      _showErrorSnackBar('Download failed: ${e.toString()}');
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 29;
    }
    return true;
  }

  String _getDownloadUrl() {
    if (_photoType == 'video') {
      if (_isVideoInitialized && _videoController != null) {
        final videoUrls = _getCompatibleVideoUrls();
        return videoUrls.isNotEmpty ? videoUrls.first : widget.photo.src.original;
      }
      return widget.photo.src.original;
    } else {
      return widget.photo.src.original.isNotEmpty
          ? widget.photo.src.original
          : widget.photo.src.large2x.isNotEmpty
          ? widget.photo.src.large2x
          : widget.photo.src.large;
    }
  }

  String _getFileName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final photographer = widget.photo.photographer.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    if (_photoType == 'video') {
      return 'WallHub_${photographer}_${widget.photo.id}_$timestamp.mp4';
    } else {
      return 'WallHub_${photographer}_${widget.photo.id}_$timestamp.jpg';
    }
  }

  Future<String> _saveToAppDirectory(Uint8List bytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final wallhubDir = Directory(path.join(directory.path, 'WallHub'));

    if (!await wallhubDir.exists()) {
      await wallhubDir.create(recursive: true);
    }

    final filePath = path.join(wallhubDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  void _showSuccessSnackBar(String message, String? filePath) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done, color: Colors.white, size: 20),
            12.widthBox,
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Open',
          textColor: Colors.white,
          onPressed: () => _openFile(filePath),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            12.widthBox,
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFef4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _openFile(String? filePath) async {
    if (filePath == null) return;
    try {
      if (Platform.isAndroid) {
        await OpenFilex.open(filePath);
      } else {
        _openGallery();
      }
    } catch (e) {
      _openGallery();
    }
  }

  Future<void> _openGallery() async {
    try {
      if (Platform.isAndroid) {
        const url = 'content://media/internal/images/media';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        }
      } else {
        const url = 'photos-redirect://';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        }
      }
    } catch (e) {
      print('Could not open gallery: $e');
    }
  }

  Future<void> _shareContent() async {
    try {
      HapticFeedback.lightImpact();
      final downloadUrl = _getDownloadUrl();
      final photographer = widget.photo.photographer;

      String shareText;
      if (_photoType == 'video') {
        shareText = '🎬 Check out this amazing live wallpaper by $photographer!\n\n'
            'Download from WallHub: https://wallhub.app/photo/${widget.photo.id}\n\n'
            'Direct link: $downloadUrl\n\n#LiveWallpaper #WallHub';
      } else {
        shareText = '🖼️ Beautiful wallpaper by $photographer!\n\n'
            'Download from WallHub: https://wallhub.app/photo/${widget.photo.id}\n\n'
            'Direct link: $downloadUrl\n\n#Wallpaper #WallHub';
      }

      await Share.share(
        shareText,
        subject: _photoType == 'video'
            ? 'Amazing Live Wallpaper by $photographer'
            : 'Beautiful Wallpaper by $photographer',
      );
    } catch (e) {
      Clipboard.setData(ClipboardData(text: 'https://wallhub.app/photo/${widget.photo.id}'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.link, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Link copied to clipboard')),
            ],
          ),
          backgroundColor: const Color(0xFF7c3aed),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              const Color(0xFF0a0a0f),
              const Color(0xFF000000),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Main media content
            Hero(
              tag: 'photo_${widget.photo.id}_${_photoType}',
              child: GestureDetector(
                onTap: _photoType == 'video' ? _toggleControls : null,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildResponsiveMediaContent(size),
                      _buildGradientOverlay(),
                      if (_photoType == 'video') _buildVideoOverlay(size),
                    ],
                  ),
                ),
              ),
            ),

            // Top controls
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildResponsiveTopControls(size),
                ),
              ),
            ),

            // Bottom content and actions
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _buildResponsiveBottomContent(size),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveMediaContent(Size size) {
    if (_photoType == 'video') {
      if (_isVideoLoading) {
        return _buildVideoLoadingState(size);
      }

      if (_videoLoadFailed) {
        return _buildVideoErrorState(size);
      }

      if (_isVideoInitialized && _videoController != null) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      }

      return _buildImageFallback(size);
    }

    return _buildResponsiveImageContent(size);
  }

  Widget _buildResponsiveImageContent(Size size) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Image.network(
        _getImageUrl(),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isLoading = false);
            });
            return child;
          }
          return _buildImageLoadingState(size);
        },
        errorBuilder: (context, error, stackTrace) => _buildImageErrorState(size),
      ),
    );
  }

  Widget _buildVideoLoadingState(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      color: const Color(0xFF0a0a0f),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 80 : isTablet ? 70 : 60,
              height: isDesktop ? 80 : isTablet ? 70 : 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF8b5cf6), const Color(0xFFa855f7)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: isDesktop ? 40 : isTablet ? 35 : 30,
                  height: isDesktop ? 40 : isTablet ? 35 : 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            ),
            SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
            Text(
              'Loading live wallpaper...',
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
            Text(
              'Preparing your animated experience',
              style: TextStyle(
                color: const Color(0xFF71717a),
                fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageLoadingState(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      color: const Color(0xFF0a0a0f),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 80 : isTablet ? 70 : 60,
              height: isDesktop ? 80 : isTablet ? 70 : 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF4f46e5), const Color(0xFF6366f1)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: isDesktop ? 40 : isTablet ? 35 : 30,
                  height: isDesktop ? 40 : isTablet ? 35 : 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            ),
            SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
            Text(
              'Loading wallpaper...',
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoErrorState(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      color: const Color(0xFF0a0a0f),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImageFallback(size),
          Container(
            color: Colors.black.withOpacity(0.8),
            child: Center(
              child: Container(
                margin: EdgeInsets.all(isDesktop ? 40 : isTablet ? 32 : 24),
                padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 28 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1a1a2e).withOpacity(0.9),
                      const Color(0xFF16213e).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 20 : 16),
                  border: Border.all(
                    color: const Color(0xFF8b5cf6).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 20 : isTablet ? 18 : 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8b5cf6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.videocam_off_rounded,
                        color: const Color(0xFF8b5cf6),
                        size: isDesktop ? 40 : isTablet ? 36 : 32,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),
                    Text(
                      'Live Wallpaper Unavailable',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 22 : isTablet ? 20 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
                    Text(
                      'Unable to load animated content.\nShowing preview image instead.',
                      style: TextStyle(
                        color: const Color(0xFFa1a1aa),
                        fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isDesktop ? 28 : isTablet ? 24 : 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(
                          'Retry',
                          Icons.refresh_rounded,
                          const Color(0xFF8b5cf6),
                              () => _initializeVideoPlayer(),
                          size,
                          isPrimary: true,
                        ),
                        SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),
                        _buildActionButton(
                          'Continue',
                          Icons.arrow_forward_rounded,
                          const Color(0xFF71717a),
                              () {
                            setState(() {
                              _videoLoadFailed = false;
                              _showControls = true;
                            });
                          },
                          size,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageErrorState(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      color: const Color(0xFF0a0a0f),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: const Color(0xFF71717a),
              size: isDesktop ? 80 : isTablet ? 70 : 64,
            ),
            SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),
            Text(
              'Failed to load image',
              style: TextStyle(
                color: const Color(0xFF71717a),
                fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFallback(Size size) {
    return Image.network(
      _getImageUrl(),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildImageErrorState(size),
    );
  }

  Widget _buildVideoOverlay(Size size) {
    if (_videoLoadFailed) return const SizedBox.shrink();

    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return AnimatedOpacity(
      opacity: _showControls && !_isVideoLoading ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 18),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.black.withOpacity(0.4),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF8b5cf6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8b5cf6).withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: _isVideoInitialized ? _playPauseVideo : null,
            child: Icon(
              _isVideoInitialized
                  ? (_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)
                  : Icons.video_library_outlined,
              color: Colors.white,
              size: isDesktop ? 48 : isTablet ? 44 : 40,
            ),
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
            Colors.black.withOpacity(_showControls ? 0.7 : 0.3),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(_showControls ? 0.9 : 0.4),
          ],
          stops: const [0.0, 0.25, 0.75, 1.0],
        ),
      ),
    );
  }

  Widget _buildResponsiveTopControls(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
      child: Row(
        children: [
          _buildControlButton(
            Icons.arrow_back_rounded,
                () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            size,
          ),
          const Spacer(),
          if (_photoType == 'video') ...[
            _buildStatusBadge(size),
            SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),
          ],
          _buildControlButton(
            Icons.more_vert_rounded,
                () {
              HapticFeedback.lightImpact();
              _showOptionsBottomSheet(size);
            },
            size,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed, Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: Colors.white,
          size: isDesktop ? 26 : isTablet ? 24 : 22,
        ),
        onPressed: onPressed,
        iconSize: isDesktop ? 26 : isTablet ? 24 : 22,
      ),
    );
  }

  Widget _buildStatusBadge(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16 : isTablet ? 14 : 12,
        vertical: isDesktop ? 8 : isTablet ? 7 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(),
            _getStatusColor().withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 20 : isTablet ? 18 : 16),
        border: Border.all(
          color: _getStatusColor().withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            color: Colors.white,
            size: isDesktop ? 18 : isTablet ? 16 : 14,
          ),
          SizedBox(width: isDesktop ? 8 : isTablet ? 7 : 6),
          Text(
            _getStatusText(),
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 14 : isTablet ? 12 : 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveBottomContent(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : isTablet ? 28 : 24,
        isDesktop ? 40 : isTablet ? 36 : 32,
        isDesktop ? 32 : isTablet ? 28 : 24,
        MediaQuery.of(context).padding.bottom + (isDesktop ? 32 : isTablet ? 28 : 24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResponsivePhotoInfo(size),
          SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
          _buildResponsiveDimensionsInfo(size),
          SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
          _buildResponsiveActionButtons(size),
        ],
      ),
    );
  }

  Widget _buildResponsivePhotoInfo(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Row(
      children: [
        Container(
          width: isDesktop ? 60 : isTablet ? 54 : 48,
          height: isDesktop ? 60 : isTablet ? 54 : 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _photoType == 'video'
                  ? [const Color(0xFF8b5cf6), const Color(0xFFa855f7)]
                  : [const Color(0xFF4f46e5), const Color(0xFF6366f1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isDesktop ? 30 : isTablet ? 27 : 24),
            boxShadow: [
              BoxShadow(
                color: (_photoType == 'video'
                    ? const Color(0xFF8b5cf6)
                    : const Color(0xFF4f46e5)).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            _photoType == 'video'
                ? Icons.video_library_rounded
                : Icons.photo_rounded,
            color: Colors.white,
            size: isDesktop ? 30 : isTablet ? 27 : 24,
          ),
        ),
        SizedBox(width: isDesktop ? 20 : isTablet ? 18 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.photo.photographer,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 22 : isTablet ? 20 : 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              SizedBox(height: isDesktop ? 6 : isTablet ? 5 : 4),
              Text(
                _photoType == 'video'
                    ? 'Live Wallpaper Creator'
                    : 'Photographer',
                style: TextStyle(
                  color: const Color(0xFFa1a1aa),
                  fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (_photoType == 'video')
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 12 : isTablet ? 10 : 8,
              vertical: isDesktop ? 6 : isTablet ? 5 : 4,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(),
              borderRadius: BorderRadius.circular(isDesktop ? 12 : isTablet ? 10 : 8),
            ),
            child: Text(
              _getStatusText(),
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResponsiveDimensionsInfo(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 20 : isTablet ? 18 : 16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoColumn(
              _photoType == 'video'
                  ? Icons.aspect_ratio_rounded
                  : Icons.photo_size_select_large_rounded,
              _getResolutionText(),
              'Resolution',
              size,
            ),
          ),
          Container(
            width: 1,
            height: isDesktop ? 50 : isTablet ? 45 : 40,
            color: Colors.white.withOpacity(0.2),
          ),
          Expanded(
            child: _buildInfoColumn(
              _photoType == 'video'
                  ? Icons.play_circle_outline_rounded
                  : Icons.image_aspect_ratio_rounded,
              _photoType == 'video' ? 'MP4' : _getAspectRatio(),
              _photoType == 'video' ? 'Format' : 'Ratio',
              size,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String value, String label, Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Column(
      children: [
        Icon(
          icon,
          color: _photoType == 'video'
              ? const Color(0xFF8b5cf6)
              : const Color(0xFF4f46e5),
          size: isDesktop ? 24 : isTablet ? 22 : 20,
        ),
        SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isDesktop ? 6 : isTablet ? 5 : 4),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFFa1a1aa),
            fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveActionButtons(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return Row(
      children: [
        // Primary action button
        Expanded(
          flex: isDesktop ? 3 : 2,
          child: GestureDetector(
            onTap: () => _handleSetWallpaper(size),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: isDesktop ? 20 : isTablet ? 18 : 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _photoType == 'video'
                      ? [const Color(0xFF8b5cf6), const Color(0xFFa855f7)]
                      : [const Color(0xFF4f46e5), const Color(0xFF6366f1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isDesktop ? 20 : isTablet ? 18 : 16),
                boxShadow: [
                  BoxShadow(
                    color: (_photoType == 'video'
                        ? const Color(0xFF8b5cf6)
                        : const Color(0xFF4f46e5)).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _photoType == 'video'
                        ? Icons.video_settings_rounded
                        : Icons.wallpaper_rounded,
                    color: Colors.white,
                    size: isDesktop ? 24 : isTablet ? 22 : 20,
                  ),
                  SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),
                  Text(
                    _photoType == 'video'
                        ? 'Set Live Wallpaper'
                        : 'Set Wallpaper',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(width: isDesktop ? 20 : isTablet ? 18 : 16),

        // Download button
        GestureDetector(
          onTap: _isDownloading ? null : _downloadFile,
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 20 : isTablet ? 18 : 16),
            decoration: BoxDecoration(
              gradient: _isDownloading
                  ? LinearGradient(
                colors: [
                  const Color(0xFF059669),
                  const Color(0xFF10b981),
                ],
              )
                  : LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(isDesktop ? 20 : isTablet ? 18 : 16),
              border: Border.all(
                color: _isDownloading
                    ? const Color(0xFF059669)
                    : Colors.white.withOpacity(0.2),
                width: _isDownloading ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isDownloading
                      ? const Color(0xFF059669)
                      : Colors.black).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _isDownloading
                ? SizedBox(
              width: isDesktop ? 24 : isTablet ? 22 : 20,
              height: isDesktop ? 24 : isTablet ? 22 : 20,
              child: Stack(
                children: [
                  CircularProgressIndicator(
                    value: _downloadProgress,
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    backgroundColor: Colors.white.withOpacity(0.3),
                  ),
                  Center(
                    child: Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: isDesktop ? 14 : isTablet ? 13 : 12,
                    ),
                  ),
                ],
              ),
            )
                : Icon(
              Icons.download_rounded,
              color: Colors.white,
              size: isDesktop ? 24 : isTablet ? 22 : 20,
            ),
          ),
        ),

        SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),

        // Share button
        GestureDetector(
          onTap: _shareContent,
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 20 : isTablet ? 18 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(isDesktop ? 20 : isTablet ? 18 : 16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.share_rounded,
              color: Colors.white,
              size: isDesktop ? 24 : isTablet ? 22 : 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      Size size, {
        bool isPrimary = false,
      }) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 20 : isTablet ? 18 : 16,
          vertical: isDesktop ? 12 : isTablet ? 10 : 8,
        ),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(colors: [color, color.withOpacity(0.8)])
              : null,
          color: isPrimary ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(isDesktop ? 12 : isTablet ? 10 : 8),
          border: Border.all(
            color: color,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : color,
              size: isDesktop ? 18 : isTablet ? 16 : 14,
            ),
            SizedBox(width: isDesktop ? 8 : isTablet ? 7 : 6),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : color,
                fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  String _getImageUrl() {
    try {
      if (_photoType == 'video') {
        return widget.photo.src.large.isNotEmpty
            ? widget.photo.src.large
            : widget.photo.src.medium;
      } else {
        return widget.photo.src.large2x.isNotEmpty
            ? widget.photo.src.large2x
            : widget.photo.src.large;
      }
    } catch (e) {
      return widget.photo.src.large;
    }
  }

  String _getResolutionText() {
    try {
      if (widget.photo.width != null &&
          widget.photo.height != null &&
          widget.photo.width! > 0 &&
          widget.photo.height! > 0) {
        return '${widget.photo.width} × ${widget.photo.height}';
      }
    } catch (e) {
      print('Error getting resolution: $e');
    }
    return 'HD Quality';
  }

  String _getAspectRatio() {
    try {
      if (widget.photo.width == null ||
          widget.photo.height == null ||
          widget.photo.width! <= 0 ||
          widget.photo.height! <= 0) {
        return 'Standard';
      }

      final ratio = widget.photo.width! / widget.photo.height!;
      if ((ratio - 16/9).abs() < 0.1) return '16:9';
      if ((ratio - 4/3).abs() < 0.1) return '4:3';
      if ((ratio - 3/2).abs() < 0.1) return '3:2';
      if ((ratio - 1).abs() < 0.1) return '1:1';
      return 'Custom';
    } catch (e) {
      return 'Standard';
    }
  }

  Color _getStatusColor() {
    if (_videoLoadFailed) return const Color(0xFFef4444);
    if (_isVideoLoading) return const Color(0xFFf59e0b);
    if (_isPlaying) return const Color(0xFF22c55e);
    return const Color(0xFF8b5cf6);
  }

  IconData _getStatusIcon() {
    if (_videoLoadFailed) return Icons.error_outline_rounded;
    if (_isVideoLoading) return Icons.hourglass_empty_rounded;
    if (_isPlaying) return Icons.play_arrow_rounded;
    return Icons.video_library_rounded;
  }

  String _getStatusText() {
    if (_videoLoadFailed) return 'ERROR';
    if (_isVideoLoading) return 'LOADING';
    if (_isPlaying) return 'PLAYING';
    return 'LIVE';
  }

  void _handleSetWallpaper(Size size) {
    if (kIsWeb) {
      _showErrorSnackBar('Wallpaper setting not available on web');
      return;
    }

    HapticFeedback.mediumImpact();
    _showWallpaperOptionsBottomSheet(size);
  }

  void _showWallpaperOptionsBottomSheet(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 28 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1a1a2e),
              const Color(0xFF16213e),
              const Color(0xFF0f0f0f),
            ],
          ),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isDesktop ? 50 : isTablet ? 45 : 40,
              height: isDesktop ? 6 : isTablet ? 5 : 4,
              decoration: BoxDecoration(
                color: const Color(0xFF71717a),
                borderRadius: BorderRadius.circular(isDesktop ? 3 : 2),
              ),
            ),
            SizedBox(height: isDesktop ? 28 : isTablet ? 24 : 20),
            Text(
              _photoType == 'video' ? 'Set Live Wallpaper' : 'Set Wallpaper',
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: isDesktop ? 28 : isTablet ? 24 : 20),
            _buildWallpaperOption(
              Icons.home_rounded,
              'Home Screen',
              'Set as home screen wallpaper',
                  () => _setWallpaper(AsyncWallpaper.HOME_SCREEN),
              size,
            ),
            _buildWallpaperOption(
              Icons.lock_rounded,
              'Lock Screen',
              'Set as lock screen wallpaper',
                  () => _setWallpaper(AsyncWallpaper.LOCK_SCREEN),
              size,
            ),
            _buildWallpaperOption(
              Icons.phone_android_rounded,
              'Both Screens',
              'Set as both home and lock screen',
                  () => _setWallpaper(AsyncWallpaper.BOTH_SCREENS),
              size,
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildWallpaperOption(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
      Size size,
      ) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
        margin: EdgeInsets.only(bottom: isDesktop ? 16 : isTablet ? 14 : 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF27272a).withOpacity(0.8),
              const Color(0xFF1a1a1e).withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(isDesktop ? 20 : isTablet ? 18 : 16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 16 : isTablet ? 14 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _photoType == 'video'
                      ? [const Color(0xFF8b5cf6), const Color(0xFFa855f7)]
                      : [const Color(0xFF4f46e5), const Color(0xFF6366f1)],
                ),
                borderRadius: BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isDesktop ? 28 : isTablet ? 26 : 24,
              ),
            ),
            SizedBox(width: isDesktop ? 20 : isTablet ? 18 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 6 : isTablet ? 5 : 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFFa1a1aa),
                      fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: const Color(0xFF71717a),
              size: isDesktop ? 20 : isTablet ? 18 : 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setWallpaper(int wallpaperLocation) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _photoType == 'video'
              ? '🎬 Setting live wallpaper...'
              : '🖼️ Setting wallpaper...',
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: _photoType == 'video'
            ? const Color(0xFF8b5cf6)
            : const Color(0xFF4f46e5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    try {
      var file = await DefaultCacheManager().getSingleFile(_getDownloadUrl());
      await AsyncWallpaper.setWallpaperFromFile(
        filePath: file.path,
        wallpaperLocation: wallpaperLocation,
        goToHome: true,
      );
      _showSuccessSnackBar('Wallpaper set successfully!', null);
    } catch (e) {
      _showErrorSnackBar('Failed to set wallpaper');
    }
  }

  void _showOptionsBottomSheet(Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 28 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1a1a2e),
              const Color(0xFF16213e),
              const Color(0xFF0f0f0f),
            ],
          ),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isDesktop ? 50 : isTablet ? 45 : 40,
              height: isDesktop ? 6 : isTablet ? 5 : 4,
              decoration: BoxDecoration(
                color: const Color(0xFF71717a),
                borderRadius: BorderRadius.circular(isDesktop ? 3 : 2),
              ),
            ),
            SizedBox(height: isDesktop ? 28 : isTablet ? 24 : 20),
            Text(
              _photoType == 'video' ? 'Live Wallpaper Options' : 'Photo Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: isDesktop ? 28 : isTablet ? 24 : 20),
            _buildOptionItem(Icons.favorite_outline_rounded, 'Add to Favorites', size),
            _buildOptionItem(Icons.collections_outlined, 'Add to Collection', size),
            _buildOptionItem(Icons.info_outline_rounded, 'View Details', size),
            if (_photoType == 'video' && _videoLoadFailed)
              _buildOptionItem(Icons.refresh_rounded, 'Retry Video Load', size),
            _buildOptionItem(Icons.report_outlined, 'Report', size),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title, Size size) {
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1024;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (title == 'Retry Video Load') {
          _initializeVideoPlayer();
        }
        // Add other option handlers here
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isDesktop ? 20 : isTablet ? 18 : 16),
        margin: EdgeInsets.only(bottom: isDesktop ? 12 : isTablet ? 10 : 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF27272a).withOpacity(0.8),
              const Color(0xFF1a1a1e).withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: isDesktop ? 26 : isTablet ? 24 : 22,
            ),
            SizedBox(width: isDesktop ? 20 : isTablet ? 18 : 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: const Color(0xFF71717a),
              size: isDesktop ? 18 : isTablet ? 16 : 14,
            ),
          ],
        ),
      ),
    );
  }
}
