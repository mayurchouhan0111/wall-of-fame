/*
// lib/models/video_model.dart

class Video {
  final int id;
  final int width;
  final int height;
  final String url;
  final String image;
  final int duration;
  final String user;
  final List<VideoFile> videoFiles;

  Video({
    required this.id,
    required this.width,
    required this.height,
    required this.url,
    required this.image,
    required this.duration,
    required this.user,
    required this.videoFiles,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'],
      width: json['width'],
      height: json['height'],
      url: json['url'],
      image: json['image'],
      duration: json['duration'],
      user: json['user']['name'] ?? 'Unknown',
      videoFiles: (json['video_files'] as List)
          .map((file) => VideoFile.fromJson(file))
          .toList(),
    );
  }
}

class VideoFile {
  final int id;
  final String quality;
  final String fileType;
  final int width;
  final int height;
  final String link;

  VideoFile({
    required this.id,
    required this.quality,
    required this.fileType,
    required this.width,
    required this.height,
    required this.link,
  });

  factory VideoFile.fromJson(Map<String, dynamic> json) {
    return VideoFile(
      id: json['id'],
      quality: json['quality'] ?? 'hd',
      fileType: json['file_type'] ?? 'video/mp4',
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      link: json['link'],
    );
  }
}

// Updated Photo Model to include type
class Photo {
  final int id;
  final int width;
  final int height;
  final String photographer;
  final String photographerUrl;
  final PhotoSrc src;
  final String alt;
  final String type; // 'photo' or 'video'

  Photo({
    required this.id,
    required this.width,
    required this.height,
    required this.photographer,
    required this.photographerUrl,
    required this.src,
    required this.alt,
    this.type = 'photo',
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      width: json['width'],
      height: json['height'],
      photographer: json['photographer'],
      photographerUrl: json['photographer_url'],
      src: PhotoSrc.fromJson(json['src']),
      alt: json['alt'],
      type: 'photo',
    );
  }

  // Create Photo from Video for unified handling
  factory Photo.fromVideo(Video video) {
    final bestQuality = video.videoFiles.isNotEmpty
        ? video.videoFiles.first.link
        : video.url;

    return Photo(
      id: video.id,
      width: video.width,
      height: video.height,
      photographer: video.user,
      photographerUrl: '',
      src: PhotoSrc(
        original: bestQuality,
        large2x: bestQuality,
        large: bestQuality,
        medium: bestQuality,
        small: video.image,
        portrait: bestQuality,
        landscape: bestQuality,
        tiny: video.image,
      ),
      alt: 'Live wallpaper video by ${video.user}',
      type: 'video',
    );
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
      original: json['original'],
      large2x: json['large2x'],
      large: json['large'],
      medium: json['medium'],
      small: json['small'],
      portrait: json['portrait'],
      landscape: json['landscape'],
      tiny: json['tiny'],
    );
  }
}
*/
