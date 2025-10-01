import 'package:flutter/foundation.dart';
// lib/screens/image_detail_screen.dart
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
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
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
          print('Using real Pexels video URL: $videoUrl');
          return [videoUrl];
        }

        final possibleUrls = [
          widget.photo.src.large2x,
          widget.photo.src.portrait,
          widget.photo.src.landscape,
        ].where((url) => url.isNotEmpty && (url.contains('.mp4') || url.contains('video'))).toList();

        if (possibleUrls.isNotEmpty) {
          print('Found video URLs: $possibleUrls');
          return possibleUrls;
        }
      } catch (e) {
        print('Error getting video URL: $e');
      }
    }

    // Fallback to sample videos
    print('No real video URL found, using sample videos');
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
    print('Trying video URL: $url');

    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) {
          print('Video initialized successfully: $url');
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
        print('Video initialization failed for $url: $error');
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
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _showControls && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  // IMPROVED DOWNLOAD FUNCTIONALITY
  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      print('Android SDK: $sdkInt');

      if (sdkInt >= 29) {
        return true;
      }
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

  Future<void> _downloadFile() async {
    if (kIsWeb) {
      _showErrorSnackBar('This feature is not available on the web.');
      return;
    }
    if (_isDownloading) return;

    print('Download button tapped');

    HapticFeedback.mediumImpact();

    final hasPermission = await _checkStoragePermission();
    print('Storage permission: $hasPermission');
    if (!hasPermission) {
      _showErrorSnackBar('Storage access not available');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final downloadUrl = _getDownloadUrl();
      final fileName = _getFileName();

      print('Downloading from: $downloadUrl');
      print('File name: $fileName');

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await request.send();

      print('HTTP status code: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode != 200) {
        throw Exception('Failed to download: ${streamedResponse.statusCode}');
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

      Map<String, dynamic> result;

      if (_photoType == 'video') {
        result = await ImageGallerySaver.saveImage(
          uint8List,
          name: fileName,
          isReturnImagePathOfIOS: true,
        );
      } else {
        result = await ImageGallerySaver.saveImage(
          uint8List,
          name: fileName,
          isReturnImagePathOfIOS: true,
        );
      }

      print('Save result: $result');

      if (result['isSuccess'] == true) {
        await _saveToAppDirectory(uint8List, fileName);

        _showSuccessSnackBar(
            _photoType == 'video'
                ? '🎬 Live wallpaper saved successfully!'
                : '🖼️ Wallpaper saved successfully!',
            result['filePath']
        );
      } else {
        final filePath = await _saveToAppDirectory(uint8List, fileName);
        _showSuccessSnackBar(
            'Downloaded to app folder',
            filePath
        );
      }

    } catch (e) {
      print('Download error: $e');
      _showErrorSnackBar('Download failed: ${e.toString()}');
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
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
        final result = await OpenFilex.open(filePath);
        print('OpenFilex result: ${result.message}');
      } else {
        _openGallery();
      }
    } catch (e) {
      print('Error opening file: $e');
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
      print('Share error: $e');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090b),
      body: Stack(
        children: [
          // Main content (image or video)
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
                    _buildMediaContent(),
                    _buildGradientOverlay(),
                    if (_photoType == 'video') _buildVideoOverlay(),
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
                child: _buildTopControls(),
              ),
            ),
          ),

          // Bottom info and actions
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
                  child: _buildBottomContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MISSING BUILD METHODS - ADDED HERE
  Widget _buildMediaContent() {
    if (_photoType == 'video') {
      if (_isVideoLoading) {
        return Container(
          color: const Color(0xFF18181b),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8b5cf6)),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Loading live wallpaper...',
                  style: TextStyle(
                    color: Color(0xFFa1a1aa),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Preparing your animated experience',
                  style: TextStyle(
                    color: Color(0xFF71717a),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (_videoLoadFailed) {
        return _buildVideoErrorState();
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

      return _buildImageFallback();
    }

    return _buildImageContent();
  }

  Widget _buildVideoErrorState() {
    return Container(
      color: const Color(0xFF18181b),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImageFallback(),
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272a),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF8b5cf6).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8b5cf6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.videocam_off,
                        color: Color(0xFF8b5cf6),
                        size: 32,
                      ),
                    ),
                    16.heightBox,
                    const Text(
                      'Live Wallpaper Unavailable',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    8.heightBox,
                    const Text(
                      'Unable to load animated content.\nShowing preview image instead.',
                      style: TextStyle(
                        color: Color(0xFFa1a1aa),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    20.heightBox,
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _initializeVideoPlayer(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8b5cf6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        12.widthBox,
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _videoLoadFailed = false;
                              _showControls = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF71717a),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                color: Color(0xFF71717a),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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

  Widget _buildImageContent() {
    return Image.network(
      _getImageUrl(),
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          });
          return child;
        }
        return Container(
          color: const Color(0xFF18181b),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4f46e5)),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildImageErrorState(),
    );
  }

  Widget _buildImageFallback() {
    return Image.network(
      _getImageUrl(),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildImageErrorState(),
    );
  }

  Widget _buildImageErrorState() {
    return Container(
      color: const Color(0xFF18181b),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Color(0xFF71717a),
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Failed to load image',
              style: TextStyle(
                color: Color(0xFF71717a),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoOverlay() {
    if (_videoLoadFailed) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _showControls && !_isVideoLoading ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF8b5cf6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8b5cf6).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: _isVideoInitialized ? _playPauseVideo : null,
            child: Icon(
              _isVideoInitialized
                  ? (_isPlaying ? Icons.pause : Icons.play_arrow)
                  : Icons.video_library_outlined,
              color: Colors.white,
              size: 40,
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
            Colors.black.withOpacity(_showControls ? 0.6 : 0.2),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(_showControls ? 0.8 : 0.3),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
          ),
          const Spacer(),
          if (_photoType == 'video')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getStatusColor().withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor().withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          12.widthBox,
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                _showOptionsBottomSheet();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContent() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        32,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhotoInfo(),
          24.heightBox,
          _buildDimensionsInfo(),
          24.heightBox,
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildPhotoInfo() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _photoType == 'video'
                  ? [const Color(0xFF8b5cf6), const Color(0xFFa855f7)]
                  : [const Color(0xFF4f46e5), const Color(0xFF6366f1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            _photoType == 'video'
                ? Icons.video_library_outlined
                : Icons.photo_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        16.widthBox,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.photo.photographer,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              4.heightBox,
              Text(
                _photoType == 'video'
                    ? 'Live Wallpaper Creator'
                    : 'Photographer',
                style: const TextStyle(
                  color: Color(0xFFa1a1aa),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (_photoType == 'video')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getStatusText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDimensionsInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Icon(
                  _photoType == 'video'
                      ? Icons.aspect_ratio
                      : Icons.photo_size_select_large,
                  color: _photoType == 'video'
                      ? const Color(0xFF8b5cf6)
                      : const Color(0xFF4f46e5),
                  size: 20,
                ),
                8.heightBox,
                Text(
                  _getResolutionText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                4.heightBox,
                const Text(
                  'Resolution',
                  style: TextStyle(
                    color: Color(0xFFa1a1aa),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.1),
          ),
          Expanded(
            child: Column(
              children: [
                Icon(
                  _photoType == 'video'
                      ? Icons.play_circle_outline
                      : Icons.image_aspect_ratio,
                  color: _photoType == 'video'
                      ? const Color(0xFF8b5cf6)
                      : const Color(0xFF4f46e5),
                  size: 20,
                ),
                8.heightBox,
                Text(
                  _photoType == 'video' ? 'MP4' : _getAspectRatio(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                4.heightBox,
                Text(
                  _photoType == 'video' ? 'Format' : 'Ratio',
                  style: const TextStyle(
                    color: Color(0xFFa1a1aa),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => _handleSetWallpaper(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _photoType == 'video'
                      ? [const Color(0xFF8b5cf6), const Color(0xFFa855f7)]
                      : [const Color(0xFF4f46e5), const Color(0xFF6366f1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (_photoType == 'video'
                        ? const Color(0xFF8b5cf6)
                        : const Color(0xFF4f46e5)).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _photoType == 'video'
                        ? Icons.video_settings
                        : Icons.wallpaper,
                    color: Colors.white,
                    size: 20,
                  ),
                  12.widthBox,
                  Text(
                    _photoType == 'video'
                        ? 'Set Live Wallpaper'
                        : 'Set Wallpaper',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        16.widthBox,
        GestureDetector(
          onTap: _isDownloading ? null : _downloadFile,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDownloading
                  ? const Color(0xFF059669).withOpacity(0.8)
                  : Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDownloading
                    ? const Color(0xFF059669)
                    : Colors.white.withOpacity(0.2),
                width: _isDownloading ? 2 : 1,
              ),
            ),
            child: _isDownloading
                ? SizedBox(
              width: 20,
              height: 20,
              child: Stack(
                children: [
                  CircularProgressIndicator(
                    value: _downloadProgress,
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white.withOpacity(0.3),
                  ),
                  const Center(
                    child: Icon(
                      Icons.download,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ],
              ),
            )
                : const Icon(
              Icons.download_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        12.widthBox,
        GestureDetector(
          onTap: _shareContent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.share_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // HELPER METHODS
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
    if (_videoLoadFailed) return Icons.error_outline;
    if (_isVideoLoading) return Icons.hourglass_empty;
    if (_isPlaying) return Icons.play_arrow;
    return Icons.video_library;
  }

  String _getStatusText() {
    if (_videoLoadFailed) return 'ERROR';
    if (_isVideoLoading) return 'LOADING';
    if (_isPlaying) return 'PLAYING';
    return 'LIVE WALLPAPER';
  }



// ... (rest of the imports)

// ... (inside _ImageDetailScreenState)

  void _handleSetWallpaper() {
    if (kIsWeb) {
      _showErrorSnackBar('This feature is not available on the web.');
      return;
    }
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF18181b),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF71717a),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            20.heightBox,
            Text(
              'Set Wallpaper',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            20.heightBox,
            _buildOptionItem(Icons.home_outlined, 'Home Screen'),
            _buildOptionItem(Icons.lock_outline, 'Lock Screen'),
            _buildOptionItem(Icons.phone_android_outlined, 'Both'),
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
      _showErrorSnackBar('Failed to set wallpaper.');
    }
  }

  void _showOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF18181b),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF71717a),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            20.heightBox,
            Text(
              _photoType == 'video' ? 'Live Wallpaper Options' : 'Photo Options',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            20.heightBox,
            _buildOptionItem(Icons.favorite_outline, 'Add to Favorites'),
            _buildOptionItem(Icons.collections_outlined, 'Add to Collection'),
            _buildOptionItem(Icons.info_outline, 'View Details'),
            if (_photoType == 'video' && _videoLoadFailed)
              _buildOptionItem(Icons.refresh, 'Retry Video Load'),
            _buildOptionItem(Icons.report_outlined, 'Report'),
            16.heightBox,
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (title == 'Retry Video Load') {
          _initializeVideoPlayer();
        } else if (title == 'Home Screen') {
          _setWallpaper(AsyncWallpaper.HOME_SCREEN);
        } else if (title == 'Lock Screen') {
          _setWallpaper(AsyncWallpaper.LOCK_SCREEN);
        } else if (title == 'Both') {
          _setWallpaper(AsyncWallpaper.BOTH_SCREENS);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF27272a),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            16.widthBox,
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
