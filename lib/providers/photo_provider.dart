// lib/providers/photo_provider.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/photo_model.dart';
import '../utils/constants.dart';

class PhotoProvider with ChangeNotifier {
  // State properties
  List<Photo> _photos = [];
  List<Video> _videos = [];
  List<Photo> _generatedPhotos = [];
  List<String> _favoritePhotoIds = [];
  final Map<String, Photo> _photoCache = {};
  final Map<String, Uint8List> _imageDataCache = {};
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _error;
  int _page = 1;
  int _totalResults = 0;
  String? _currentQuery;
  String _currentMode = 'photos';

  // Base URLs for Pexels API
  static const String _baseUrl = 'https://api.pexels.com/v1';
  static const String _videoBaseUrl = 'https://api.pexels.com/videos';

  // Multiple AI Image Generation APIs with fallbacks
  final Map<String, Map<String, dynamic>> _aiProviders = {
    'pollinations_v1': {
      'name': 'Pollinations AI',
      'baseUrl': 'https://image.pollinations.ai/prompt',
      'active': true,
    },
    'pollinations_v2': {
      'name': 'Pollinations Alt',
      'baseUrl': 'https://pollinations.ai/p',
      'active': true,
    },
    'deepai': {
      'name': 'DeepAI',
      'baseUrl': 'https://api.deepai.org/api/text2img',
      'active': true,
    },
    'huggingface': {
      'name': 'HuggingFace',
      'baseUrl': 'https://api-inference.huggingface.co/models/runwayml/stable-diffusion-v1-5',
      'active': true,
    },
  };

  String _selectedProvider = 'pollinations_v1';
  String _selectedModel = 'flux';
  String _selectedSize = '1024x1024';

  // Public getters
  List<Photo> get photos => _photos;
  List<Video> get videos => _videos;
  List<Photo> get generatedPhotos => _generatedPhotos;
  List<String> get favoritePhotoIds => _favoritePhotoIds;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  bool get hasFavorites => _favoritePhotoIds.isNotEmpty;
  String? get error => _error;
  int get perPage => 30;
  int get totalResults => _totalResults;
  String get currentMode => _currentMode;
  String get selectedProvider => _selectedProvider;
  String get selectedModel => _selectedModel;
  String get selectedSize => _selectedSize;

  // Combined getter for unified display
  List<Photo> get allContent {
    switch (_currentMode) {
      case 'videos':
        return _videos.map((video) => Photo.fromVideo(video)).toList();
      case 'generate':
        return _generatedPhotos;
      default:
        return _photos;
    }
  }

  /// Initialize favorites from SharedPreferences
  Future<void> initializeFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _favoritePhotoIds = prefs.getStringList('favorite_photos') ?? [];
      notifyListeners();
    } catch (e) {
      print('Error initializing favorites: $e');
    }
  }

  /// Set AI generation parameters
  void setGenerationModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  void setGenerationSize(String size) {
    _selectedSize = size;
    notifyListeners();
  }

  /// Get cached image data for a URL
  Uint8List? getCachedImageData(String url) {
    return _imageDataCache[url];
  }

  /// FIXED: Robust Pollinations API with multiple endpoints
  Future<void> _generateWithPollinations(String prompt, {int attempt = 1}) async {
    try {
      final dimensions = _selectedSize.split('x');
      final seed = Random().nextInt(1000000);

      // Clean prompt to avoid URL encoding issues
      final cleanPrompt = prompt
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // Try multiple Pollinations endpoints
      final endpoints = [
        'https://image.pollinations.ai/prompt/${Uri.encodeComponent(cleanPrompt)}?width=${dimensions[0]}&height=${dimensions[1]}&model=$_selectedModel&seed=$seed&nologo=true&enhance=true',
        'https://pollinations.ai/p/${Uri.encodeComponent(cleanPrompt)}?width=${dimensions[0]}&height=${dimensions[1]}&model=$_selectedModel&seed=$seed',
        'https://image.pollinations.ai/prompt/${Uri.encodeComponent(cleanPrompt)}?model=$_selectedModel&seed=$seed',
      ];

      for (final url in endpoints) {
        try {
          print('Trying Pollinations endpoint: $url');

          final client = http.Client();
          final request = http.Request('GET', Uri.parse(url));
          request.headers.addAll({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'image/webp,image/apng,image/png,image/jpeg,image/*,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          });

          final streamedResponse = await client.send(request).timeout(
            const Duration(seconds: 45),
          );

          if (streamedResponse.statusCode == 200) {
            final response = await http.Response.fromStream(streamedResponse);

            if (response.bodyBytes.isNotEmpty && response.bodyBytes.length > 1000) {
              // Create data URL
              final base64String = base64Encode(response.bodyBytes);
              final dataUrl = 'data:image/png;base64,$base64String';

              // Cache the data
              _imageDataCache[dataUrl] = response.bodyBytes;

              final generatedPhoto = Photo(
                id: DateTime.now().millisecondsSinceEpoch + Random().nextInt(1000),
                width: int.parse(dimensions[0]),
                height: int.parse(dimensions[1]),
                url: dataUrl,
                photographer: 'Pollinations AI',
                photographerUrl: 'https://pollinations.ai',
                photographerId: 0,
                avgColor: '#000000',
                src: PhotoSrc(
                  original: dataUrl,
                  large2x: dataUrl,
                  large: dataUrl,
                  medium: dataUrl,
                  small: dataUrl,
                  portrait: dataUrl,
                  landscape: dataUrl,
                  tiny: dataUrl,
                ),
                liked: false,
                alt: '$prompt (Pollinations)',
              );

              _generatedPhotos.insert(0, generatedPhoto);
              client.close();
              print('Successfully generated with Pollinations');
              return; // Success!
            }
          }

          client.close();

        } catch (e) {
          print('Pollinations endpoint failed: $url, error: $e');
          continue; // Try next endpoint
        }
      }

      throw Exception('All Pollinations endpoints failed');

    } catch (e) {
      print('Pollinations generation failed: $e');
      // Don't rethrow - let other providers try
    }
  }

  /// FIXED: Enhanced DeepAI with better error handling
  Future<void> _generateWithDeepAI(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.deepai.org/api/text2img'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'WallpaperApp/1.0',
        },
        body: 'text=${Uri.encodeComponent(prompt)}',
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = data['output_url'];

        if (imageUrl != null && imageUrl.toString().isNotEmpty) {
          // Fetch the actual image
          final imageResponse = await http.get(
            Uri.parse(imageUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; WallpaperApp/1.0)',
              'Accept': 'image/*',
            },
          ).timeout(const Duration(seconds: 30));

          if (imageResponse.statusCode == 200 && imageResponse.bodyBytes.isNotEmpty) {
            final base64String = base64Encode(imageResponse.bodyBytes);
            final dataUrl = 'data:image/jpeg;base64,$base64String';

            _imageDataCache[dataUrl] = imageResponse.bodyBytes;

            final generatedPhoto = Photo(
              id: DateTime.now().millisecondsSinceEpoch + Random().nextInt(1000),
              width: 512,
              height: 512,
              url: dataUrl,
              photographer: 'DeepAI',
              photographerUrl: 'https://deepai.org',
              photographerId: 0,
              avgColor: '#000000',
              src: PhotoSrc(
                original: dataUrl,
                large2x: dataUrl,
                large: dataUrl,
                medium: dataUrl,
                small: dataUrl,
                portrait: dataUrl,
                landscape: dataUrl,
                tiny: dataUrl,
              ),
              liked: false,
              alt: '$prompt (DeepAI)',
            );

            _generatedPhotos.insert(0, generatedPhoto);
            print('Successfully generated with DeepAI');
          }
        }
      }
    } catch (e) {
      print('DeepAI generation failed: $e');
    }
  }

  /// FIXED: Enhanced HuggingFace generation
  Future<void> _generateWithHuggingFace(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('https://api-inference.huggingface.co/models/runwayml/stable-diffusion-v1-5'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'WallpaperApp/1.0',
        },
        body: json.encode({
          'inputs': prompt,
          'options': {'wait_for_model': true}
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty && response.bodyBytes.length > 1000) {
        final base64String = base64Encode(response.bodyBytes);
        final dataUrl = 'data:image/png;base64,$base64String';

        _imageDataCache[dataUrl] = response.bodyBytes;

        final generatedPhoto = Photo(
          id: DateTime.now().millisecondsSinceEpoch + Random().nextInt(1000),
          width: 512,
          height: 512,
          url: dataUrl,
          photographer: 'HuggingFace',
          photographerUrl: 'https://huggingface.co',
          photographerId: 0,
          avgColor: '#000000',
          src: PhotoSrc(
            original: dataUrl,
            large2x: dataUrl,
            large: dataUrl,
            medium: dataUrl,
            small: dataUrl,
            portrait: dataUrl,
            landscape: dataUrl,
            tiny: dataUrl,
          ),
          liked: false,
          alt: '$prompt (HuggingFace)',
        );

        _generatedPhotos.insert(0, generatedPhoto);
        print('Successfully generated with HuggingFace');
      }
    } catch (e) {
      print('HuggingFace generation failed: $e');
    }
  }

  /// Main generation method with improved reliability
  Future<void> generateImageVariations(String prompt, {int count = 4}) async {
    if (prompt.trim().isEmpty) {
      _error = 'Please enter a prompt for image generation';
      notifyListeners();
      return;
    }

    _isGenerating = true;
    _error = null;
    notifyListeners();

    int successfulGenerations = 0;
    const maxRetries = 2;

    try {
      // Try generating with multiple providers
      for (int i = 0; i < count; i++) {
        final enhancedPrompt = '$prompt, high quality wallpaper, detailed';

        // Rotate between providers for variety
        if (i % 3 == 0) {
          // Try Pollinations with retry
          for (int retry = 0; retry < maxRetries; retry++) {
            try {
              await _generateWithPollinations(enhancedPrompt, attempt: retry + 1);
              successfulGenerations++;
              break;
            } catch (e) {
              if (retry == maxRetries - 1) {
                print('Pollinations failed after $maxRetries attempts');
              }
              await Future.delayed(Duration(seconds: retry + 2));
            }
          }
        } else if (i % 3 == 1) {
          // Try DeepAI
          try {
            await _generateWithDeepAI(enhancedPrompt);
            successfulGenerations++;
          } catch (e) {
            print('DeepAI failed: $e');
          }
        } else {
          // Try HuggingFace
          try {
            await _generateWithHuggingFace(enhancedPrompt);
            successfulGenerations++;
          } catch (e) {
            print('HuggingFace failed: $e');
          }
        }

        // Delay between generations to avoid rate limits
        if (i < count - 1) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      _totalResults = _generatedPhotos.length;

      if (successfulGenerations == 0) {
        _error = 'Failed to generate images. Please check your internet connection and try again.';
      } else {
        print('Successfully generated $successfulGenerations/$count images');
      }

    } on SocketException {
      _error = 'No Internet connection. Please check your network.';
    } catch (e) {
      _error = 'Generation failed: ${e.toString()}';
      print('Generation exception: $e');
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Get appropriate download URL for a photo
  String getDownloadUrl(Photo photo) {
    if (photo.type == 'video') {
      return photo.src.original.isNotEmpty
          ? photo.src.original
          : photo.src.large2x.isNotEmpty
          ? photo.src.large2x
          : photo.src.large;
    } else {
      return photo.src.original.isNotEmpty
          ? photo.src.original
          : photo.src.large2x.isNotEmpty
          ? photo.src.large2x
          : photo.src.large;
    }
  }

  /// Toggle favorite status for a photo
  Future<void> toggleFavorite(Photo photo) async {
    try {
      final photoId = photo.id.toString();
      final isFavorited = _favoritePhotoIds.contains(photoId);

      if (isFavorited) {
        _favoritePhotoIds.remove(photoId);
        _photoCache.remove(photoId);
      } else {
        _favoritePhotoIds.add(photoId);
        _photoCache[photoId] = photo;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_photos', _favoritePhotoIds);

      photo.liked = !isFavorited;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update favorites: $e';
      notifyListeners();
    }
  }

  /// Check if a photo is favorited
  bool isPhotoFavorited(Photo photo) {
    return _favoritePhotoIds.contains(photo.id.toString());
  }

  /// Switch between photos, videos, and generate mode
  void switchMode(String mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      resetState();
      notifyListeners();
    }
  }

  /// Resets the provider to its initial state
  void resetState() {
    _photos.clear();
    _videos.clear();
    if (_currentMode != 'generate') {
      _generatedPhotos.clear();
    }
    _page = 1;
    _totalResults = 0;
    _currentQuery = null;
    _error = null;
    notifyListeners();
  }

  /// Clear generated images and cache
  void clearGeneratedImages() {
    _generatedPhotos.clear();
    _imageDataCache.clear();
    _totalResults = 0;
    notifyListeners();
  }

  // ... [Include all other existing methods like _fetchPhotos, _fetchVideos, etc.]

  /// Generic method to fetch photos from a given URL
  Future<void> _fetchPhotos(Uri url, {required bool isNewSearch}) async {
    if (isNewSearch) {
      _photos.clear();
      _page = 1;
      _totalResults = 0;
    }

    _isLoading = true;
    _error = null;
    if (!isNewSearch) notifyListeners();

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': pexelsApiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newPhotos = (data['photos'] as List)
            .map((json) => Photo.fromJson(json))
            .toList();

        _photos.addAll(newPhotos);
        _totalResults = data['total_results'] ?? 0;
        _page = data['page'] ?? _page;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Failed to load photos: Status ${response.statusCode}';
      }
    } on SocketException {
      _error = 'No Internet connection. Please check your network.';
    } catch (e) {
      _error = 'An unexpected error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Generic method to fetch videos from Pexels Video API
  Future<void> _fetchVideos(Uri url, {required bool isNewSearch}) async {
    if (isNewSearch) {
      _videos.clear();
      _page = 1;
      _totalResults = 0;
    }

    _isLoading = true;
    _error = null;
    if (!isNewSearch) notifyListeners();

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': pexelsApiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newVideos = (data['videos'] as List)
            .map((json) => Video.fromJson(json))
            .toList();

        _videos.addAll(newVideos);
        _totalResults = data['total_results'] ?? 0;
        _page = data['page'] ?? _page;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Failed to load videos: Status ${response.statusCode}';
      }
    } on SocketException {
      _error = 'No Internet connection. Please check your network.';
    } catch (e) {
      _error = 'An unexpected error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches trending content based on current mode
  Future<void> fetchTrendingPhotos() async {
    _currentQuery = null;

    switch (_currentMode) {
      case 'videos':
        final url = Uri.parse('$_videoBaseUrl/popular?page=1&per_page=$perPage');
        await _fetchVideos(url, isNewSearch: true);
        break;
      case 'generate':
      // Show some sample generations or keep current
        break;
      default:
        final url = Uri.parse('$_baseUrl/curated?page=1&per_page=$perPage');
        await _fetchPhotos(url, isNewSearch: true);
    }
  }

  /// Searches content based on current mode
  Future<void> searchPhotos(String query) async {
    _currentQuery = query;

    switch (_currentMode) {
      case 'videos':
        final url = Uri.parse('$_videoBaseUrl/search?query=$query&page=1&per_page=$perPage');
        await _fetchVideos(url, isNewSearch: true);
        break;
      case 'generate':
        await generateImageVariations(query, count: 4);
        break;
      default:
        final url = Uri.parse('$_baseUrl/search?query=$query&page=1&per_page=$perPage');
        await _fetchPhotos(url, isNewSearch: true);
    }
  }

  /// Loads more content for infinite scrolling
  Future<void> loadMorePhotos() async {
    if (_isLoading || (_currentMode == 'generate') ||
        (_totalResults > 0 && (_currentMode == 'videos' ? _videos.length : _photos.length) >= _totalResults)) {
      return;
    }

    final nextPage = _page + 1;
    late final Uri url;

    if (_currentMode == 'videos') {
      if (_currentQuery != null && _currentQuery!.isNotEmpty) {
        url = Uri.parse('$_videoBaseUrl/search?query=$_currentQuery&page=$nextPage&per_page=$perPage');
      } else {
        url = Uri.parse('$_videoBaseUrl/popular?page=$nextPage&per_page=$perPage');
      }
      await _fetchVideos(url, isNewSearch: false);
    } else {
      if (_currentQuery != null && _currentQuery!.isNotEmpty) {
        url = Uri.parse('$_baseUrl/search?query=$_currentQuery&page=$nextPage&per_page=$perPage');
      } else {
        url = Uri.parse('$_baseUrl/curated?page=$nextPage&per_page=$perPage');
      }
      await _fetchPhotos(url, isNewSearch: false);
    }
  }


  // Add these methods to your PhotoProvider class

  /// MISSING METHOD 1: Set generating state
  void setGenerating(bool isGenerating) {
    _isGenerating = isGenerating;
    notifyListeners();
  }

  /// MISSING METHOD 2: Add generated photo to the list
  void addGeneratedPhoto(Photo photo) {
    _generatedPhotos.insert(0, photo);
    _totalResults = _generatedPhotos.length;
    notifyListeners();
  }

  /// MISSING METHOD 3: Cache image data for future use
  void cacheImageData(String url, Uint8List data) {
    _imageDataCache[url] = data;
  }

  /// MISSING METHOD 4: Simple single image generation for AI screen
  Future<void> generateSingleImage(String prompt) async {
    if (prompt.trim().isEmpty) {
      _error = 'Please enter a prompt for image generation';
      notifyListeners();
      return;
    }

    setGenerating(true);
    _error = null;

    try {
      final enhancedPrompt = '$prompt, high quality wallpaper, detailed, masterpiece';

      // Try Pollinations first (most reliable)
      try {
        await _generateWithPollinations(enhancedPrompt);
        print('Successfully generated single image with Pollinations');
      } catch (e) {
        print('Pollinations failed, trying DeepAI: $e');
        try {
          await _generateWithDeepAI(enhancedPrompt);
          print('Successfully generated single image with DeepAI');
        } catch (e2) {
          print('DeepAI failed, trying HuggingFace: $e2');
          await _generateWithHuggingFace(enhancedPrompt);
          print('Successfully generated single image with HuggingFace');
        }
      }

      if (_generatedPhotos.isEmpty) {
        _error = 'Failed to generate image. Please try again.';
      }

    } on SocketException {
      _error = 'No Internet connection. Please check your network.';
    } catch (e) {
      _error = 'Generation failed: ${e.toString()}';
      print('Single generation exception: $e');
    } finally {
      setGenerating(false);
    }
  }

  /// MISSING METHOD 5: Enhanced batch generation (improved version)
  Future<void> generateImageBatch(String prompt, {int count = 4}) async {
    if (prompt.trim().isEmpty) {
      _error = 'Please enter a prompt for image generation';
      notifyListeners();
      return;
    }

    setGenerating(true);
    _error = null;

    int successfulGenerations = 0;
    const maxRetries = 2;

    try {
      // Generate multiple variations with different approaches
      for (int i = 0; i < count; i++) {
        // Add variety to prompts
        final variations = [
          '$prompt, masterpiece, best quality',
          '$prompt, high resolution, detailed',
          '$prompt, artistic, beautiful',
          '$prompt, professional, stunning',
        ];

        final enhancedPrompt = variations[i % variations.length];

        // Rotate between providers for variety
        if (i % 3 == 0) {
          // Try Pollinations with retry
          for (int retry = 0; retry < maxRetries; retry++) {
            try {
              await _generateWithPollinations(enhancedPrompt, attempt: retry + 1);
              successfulGenerations++;
              break;
            } catch (e) {
              if (retry == maxRetries - 1) {
                print('Pollinations failed after $maxRetries attempts');
              }
              await Future.delayed(Duration(seconds: retry + 2));
            }
          }
        } else if (i % 3 == 1) {
          // Try DeepAI
          try {
            await _generateWithDeepAI(enhancedPrompt);
            successfulGenerations++;
          } catch (e) {
            print('DeepAI failed: $e');
          }
        } else {
          // Try HuggingFace
          try {
            await _generateWithHuggingFace(enhancedPrompt);
            successfulGenerations++;
          } catch (e) {
            print('HuggingFace failed: $e');
          }
        }

        // Delay between generations to avoid rate limits
        if (i < count - 1) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      _totalResults = _generatedPhotos.length;

      if (successfulGenerations == 0) {
        _error = 'Failed to generate images. Please check your internet connection and try again.';
      } else {
        print('Successfully generated $successfulGenerations/$count images');
      }

    } on SocketException {
      _error = 'No Internet connection. Please check your network.';
    } catch (e) {
      _error = 'Generation failed: ${e.toString()}';
      print('Batch generation exception: $e');
    } finally {
      setGenerating(false);
    }
  }

  /// MISSING METHOD 6: Get generation statistics
  Map<String, dynamic> getGenerationStats() {
    return {
      'total_generated': _generatedPhotos.length,
      'cache_size': _imageDataCache.length,
      'selected_model': _selectedModel,
      'selected_size': _selectedSize,
      'is_generating': _isGenerating,
      'last_error': _error,
    };
  }

  /// MISSING METHOD 7: Clean up old generated images (memory management)
  void cleanupOldGenerations({int maxKeep = 50}) {
    if (_generatedPhotos.length > maxKeep) {
      final toRemove = _generatedPhotos.length - maxKeep;
      final removedPhotos = _generatedPhotos.sublist(_generatedPhotos.length - toRemove);

      // Remove from cache
      for (final photo in removedPhotos) {
        _imageDataCache.remove(photo.src.original);
      }

      // Keep only the most recent ones
      _generatedPhotos = _generatedPhotos.take(maxKeep).toList();
      _totalResults = _generatedPhotos.length;

      notifyListeners();
      print('Cleaned up $toRemove old generated images');
    }
  }

  /// MISSING METHOD 8: Retry failed generation
  Future<void> retryGeneration(String prompt) async {
    // Clear any previous errors
    _error = null;

    // Try single image generation with retry logic
    await generateSingleImage(prompt);
  }

  /// MISSING METHOD 9: Get available AI providers
  List<Map<String, dynamic>> getAvailableProviders() {
    return _aiProviders.entries
        .where((entry) => entry.value['active'] == true)
        .map((entry) => {
      'id': entry.key,
      'name': entry.value['name'],
      'active': entry.value['active'],
    })
        .toList();
  }

  /// MISSING METHOD 10: Set active AI provider
  void setActiveProvider(String providerId) {
    if (_aiProviders.containsKey(providerId)) {
      _selectedProvider = providerId;
      notifyListeners();
      print('Switched to AI provider: ${_aiProviders[providerId]!['name']}');
    }
  }

  /// MISSING METHOD 11: Validate and sanitize prompt
  String sanitizePrompt(String prompt) {
    return prompt
        .trim()
        .replaceAll(RegExp(r'[^\w\s\-\.,!?]'), '') // Remove special chars except basic punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single space
        .toLowerCase()
        .split(' ')
        .take(50) // Limit to 50 words
        .join(' ');
  }

  /// MISSING METHOD 12: Get generation history
  List<Map<String, dynamic>> getGenerationHistory() {
    return _generatedPhotos.map((photo) => {
      'id': photo.id,
      'prompt': photo.alt ?? 'Unknown prompt',
      'photographer': photo.photographer,
      'timestamp': photo.id, // Using ID as timestamp
      'width': photo.width,
      'height': photo.height,
    }).toList();
  }

  /// MISSING METHOD 13: Export generated image data
  Future<Map<String, dynamic>> exportGeneratedImage(Photo photo) async {
    final imageData = _imageDataCache[photo.src.original];

    return {
      'id': photo.id,
      'prompt': photo.alt ?? 'Unknown',
      'photographer': photo.photographer,
      'width': photo.width,
      'height': photo.height,
      'has_data': imageData != null,
      'data_size': imageData?.length ?? 0,
      'created_at': DateTime.fromMillisecondsSinceEpoch(photo.id).toIso8601String(),
    };
  }

  /// MISSING METHOD 14: Clear specific generated image
  void removeGeneratedImage(int photoId) {
    final index = _generatedPhotos.indexWhere((photo) => photo.id == photoId);

    if (index != -1) {
      final photo = _generatedPhotos[index];

      // Remove from cache
      _imageDataCache.remove(photo.src.original);

      // Remove from list
      _generatedPhotos.removeAt(index);
      _totalResults = _generatedPhotos.length;

      notifyListeners();
      print('Removed generated image: $photoId');
    }
  }

  /// MISSING METHOD 15: Enhanced error handling for generation
  void handleGenerationError(String error, {String? provider}) {
    final timestamp = DateTime.now().toIso8601String();
    final errorMessage = provider != null
        ? '$provider generation failed: $error'
        : 'Generation failed: $error';

    _error = errorMessage;

    // Log detailed error for debugging
    print('[$timestamp] $errorMessage');

    notifyListeners();
  }

}
