// lib/models/photo_model.dart

class Photo {
  final int id;
  final int width;
  final int height;
  final String url; // Main URL for the photo/image
  final String photographer;
  final String photographerUrl;
  final int photographerId; // Add photographer ID
  final String avgColor; // Average color for UI theming
  final PhotoSrc src;
  late final bool liked; // Like/favorite status
  final String alt;
  final String? type; // 'photo', 'video', or 'generated'
  final DateTime? createdAt; // When the photo was created/generated
  final Map<String, dynamic>? metadata; // Additional metadata for AI-generated images

  Photo({
    required this.id,
    required this.width,
    required this.height,
    required this.url,
    required this.photographer,
    required this.photographerUrl,
    required this.photographerId,
    required this.avgColor,
    required this.src,
    required this.liked,
    required this.alt,
    this.type = 'photo', // Default to photo
    this.createdAt,
    this.metadata,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      width: json['width'],
      height: json['height'],
      url: json['url'] ?? '',
      photographer: json['photographer'] ?? 'Unknown',
      photographerUrl: json['photographer_url'] ?? '',
      photographerId: json['photographer_id'] ?? 0,
      avgColor: json['avg_color'] ?? '#000000',
      src: PhotoSrc.fromJson(json['src']),
      liked: json['liked'] ?? false,
      alt: json['alt'] ?? '',
      type: 'photo', // Mark as photo
      createdAt: null, // Pexels doesn't provide creation date
    );
  }

  // Create Photo from Video for unified handling
  factory Photo.fromVideo(Video video) {
    // Get the best quality video URL
    String videoUrl = video.videoFiles.isNotEmpty
        ? video.videoFiles
        .where((file) => file.quality == 'hd')
        .isNotEmpty
        ? video.videoFiles.firstWhere((file) => file.quality == 'hd').link
        : video.videoFiles.first.link
        : '';

    return Photo(
      id: video.id,
      width: video.width,
      height: video.height,
      url: videoUrl,
      photographer: video.user,
      photographerUrl: video.userUrl ?? '',
      photographerId: video.userId,
      avgColor: '#000000', // Default color for videos
      src: PhotoSrc(
        original: videoUrl, // Store video URL here
        large2x: videoUrl,
        large: video.image, // Thumbnail image
        medium: video.image,
        small: video.image,
        portrait: videoUrl,
        landscape: videoUrl,
        tiny: video.image,
      ),
      liked: false,
      alt: 'Live wallpaper video by ${video.user}',
      type: 'video', // Mark as video
      createdAt: null,
      metadata: {
        'duration': video.duration,
        'video_files': video.videoFiles.length,
      },
    );
  }

  // Factory constructor for AI-generated images
  factory Photo.generated({
    required int id,
    required int width,
    required int height,
    required String imageUrl,
    required String prompt,
    required String model,
    int? seed,
    String? style,
  }) {
    return Photo(
      id: id,
      width: width,
      height: height,
      url: imageUrl,
      photographer: 'AI Generated',
      photographerUrl: 'https://pollinations.ai',
      photographerId: 0,
      avgColor: '#000000',
      src: PhotoSrc.generated(imageUrl),
      liked: false,
      alt: prompt,
      type: 'generated',
      createdAt: DateTime.now(),
      metadata: {
        'prompt': prompt,
        'model': model,
        'seed': seed,
        'style': style,
        'generation_source': 'pollinations_ai',
      },
    );
  }

  // Helper methods
  bool get isVideo => type == 'video';
  bool get isGenerated => type == 'generated';
  bool get isPhoto => type == 'photo';

  String get displayPhotographer {
    if (isGenerated) return 'AI Generated';
    return photographer.isNotEmpty ? photographer : 'Unknown';
  }

  String? get generationPrompt => metadata?['prompt'];
  String? get generationModel => metadata?['model'];
  int? get generationSeed => metadata?['seed'];

  // Copy method for updating properties
  Photo copyWith({
    int? id,
    int? width,
    int? height,
    String? url,
    String? photographer,
    String? photographerUrl,
    int? photographerId,
    String? avgColor,
    PhotoSrc? src,
    bool? liked,
    String? alt,
    String? type,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return Photo(
      id: id ?? this.id,
      width: width ?? this.width,
      height: height ?? this.height,
      url: url ?? this.url,
      photographer: photographer ?? this.photographer,
      photographerUrl: photographerUrl ?? this.photographerUrl,
      photographerId: photographerId ?? this.photographerId,
      avgColor: avgColor ?? this.avgColor,
      src: src ?? this.src,
      liked: liked ?? this.liked,
      alt: alt ?? this.alt,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'width': width,
      'height': height,
      'url': url,
      'photographer': photographer,
      'photographer_url': photographerUrl,
      'photographer_id': photographerId,
      'avg_color': avgColor,
      'src': src.toJson(),
      'liked': liked,
      'alt': alt,
      'type': type,
      'created_at': createdAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class PhotoSrc {
  final String original;
  final String large2x;
  final String large;
  final String medium;
  final String small;
  final String portrait;
  final String landscape;
  final String tiny;

  PhotoSrc({
    required this.original,
    required this.large2x,
    required this.large,
    required this.medium,
    required this.small,
    required this.portrait,
    required this.landscape,
    required this.tiny,
  });

  factory PhotoSrc.fromJson(Map<String, dynamic> json) {
    return PhotoSrc(
      original: json['original'] ?? '',
      large2x: json['large2x'] ?? '',
      large: json['large'] ?? '',
      medium: json['medium'] ?? '',
      small: json['small'] ?? '',
      portrait: json['portrait'] ?? '',
      landscape: json['landscape'] ?? '',
      tiny: json['tiny'] ?? '',
    );
  }

  // Factory for generated images (all URLs point to the same generated image)
  factory PhotoSrc.generated(String imageUrl) {
    return PhotoSrc(
      original: imageUrl,
      large2x: imageUrl,
      large: imageUrl,
      medium: imageUrl,
      small: imageUrl,
      portrait: imageUrl,
      landscape: imageUrl,
      tiny: imageUrl,
    );
  }

  // Get best quality URL based on requirement
  String getBestQuality() => original.isNotEmpty ? original : large;
  String getThumbnail() => tiny.isNotEmpty ? tiny : small;
  String getMediumQuality() => medium.isNotEmpty ? medium : large;

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'large2x': large2x,
      'large': large,
      'medium': medium,
      'small': small,
      'portrait': portrait,
      'landscape': landscape,
      'tiny': tiny,
    };
  }
}

// Enhanced Video model
class Video {
  final int id;
  final int width;
  final int height;
  final String url;
  final String image;
  final int duration;
  final String user;
  final String? userUrl; // Add user profile URL
  final int userId; // Add user ID
  final List<VideoFile> videoFiles;
  final List<String> tags; // Video tags

  Video({
    required this.id,
    required this.width,
    required this.height,
    required this.url,
    required this.image,
    required this.duration,
    required this.user,
    this.userUrl,
    required this.userId,
    required this.videoFiles,
    this.tags = const [],
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'],
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      url: json['url'] ?? '',
      image: json['image'] ?? '',
      duration: json['duration'] ?? 0,
      user: json['user']['name'] ?? 'Unknown',
      userUrl: json['user']['url'],
      userId: json['user']['id'] ?? 0,
      videoFiles: (json['video_files'] as List? ?? [])
          .map((file) => VideoFile.fromJson(file))
          .toList(),
      tags: (json['tags'] as List? ?? [])
          .map((tag) => tag.toString())
          .toList(),
    );
  }

  // Get video file by quality preference
  VideoFile? getVideoFile(String preferredQuality) {
    final matchingFiles = videoFiles
        .where((file) => file.quality == preferredQuality)
        .toList();
    return matchingFiles.isNotEmpty ? matchingFiles.first : null;
  }

  // Get best available quality
  VideoFile? getBestQuality() {
    const qualityOrder = ['uhd', 'hd', 'sd'];
    for (final quality in qualityOrder) {
      final file = getVideoFile(quality);
      if (file != null) return file;
    }
    return videoFiles.isNotEmpty ? videoFiles.first : null;
  }

  // Get duration in formatted string
  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class VideoFile {
  final int id;
  final String quality;
  final String fileType;
  final int width;
  final int height;
  final String link;
  final double? fps; // MODIFIED: Changed from int? to double?
  final int? fileSize; // File size in bytes

  VideoFile({
    required this.id,
    required this.quality,
    required this.fileType,
    required this.width,
    required this.height,
    required this.link,
    this.fps,
    this.fileSize,
  });

  factory VideoFile.fromJson(Map<String, dynamic> json) {
    // ADDED: Robust parsing for numeric values
    final fpsValue = json['fps'];
    final sizeValue = json['file_size'];

    return VideoFile(
      id: json['id'] ?? 0,
      quality: json['quality'] ?? 'hd',
      fileType: json['file_type'] ?? 'video/mp4',
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      link: json['link'] ?? '',
      // MODIFIED: Safely parse fps as a double
      fps: fpsValue is num ? fpsValue.toDouble() : null,
      // MODIFIED: Safely parse fileSize as an int
      fileSize: sizeValue is num ? sizeValue.toInt() : null,
    );
  }

  // Get quality level as number for sorting
  int get qualityLevel {
    switch (quality.toLowerCase()) {
      case 'uhd':
        return 4;
      case 'hd':
        return 3;
      case 'sd':
        return 2;
      default:
        return 1;
    }
  }

  // Get readable file size
  String get readableFileSize {
    if (fileSize == null) return 'Unknown';
    final sizeInMB = fileSize! / (1024 * 1024);
    return '${sizeInMB.toStringAsFixed(1)} MB';
  }

  // Get aspect ratio
  double get aspectRatio {
    if (height == 0) return 16 / 9; // Default aspect ratio
    return width / height;
  }
}

// Enum for content types
enum ContentType { photo, video, generated }

// Helper extension for ContentType
extension ContentTypeExtension on ContentType {
  String get value {
    switch (this) {
      case ContentType.photo:
        return 'photo';
      case ContentType.video:
        return 'video';
      case ContentType.generated:
        return 'generated';
    }
  }

  static ContentType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'video':
        return ContentType.video;
      case 'generated':
        return ContentType.generated;
      default:
        return ContentType.photo;
    }
  }
}