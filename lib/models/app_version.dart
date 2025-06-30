class AppVersion {
  final String id;
  final int versionCode;
  final String versionName;
  final int minimumVersionCode;
  final String downloadUrl;
  final double? fileSizeMb;
  final String? releaseNotes;
  final String platform;
  final bool isActive;
  final DateTime createdAt;

  AppVersion({
    required this.id,
    required this.versionCode,
    required this.versionName,
    required this.minimumVersionCode,
    required this.downloadUrl,
    this.fileSizeMb,
    this.releaseNotes,
    required this.platform,
    required this.isActive,
    required this.createdAt,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      id: json['id'],
      versionCode: json['version_code'] is String 
          ? int.parse(json['version_code']) 
          : json['version_code'],
      versionName: json['version_name'],
      minimumVersionCode: json['minimum_version_code'] is String 
          ? int.parse(json['minimum_version_code']) 
          : json['minimum_version_code'],
      downloadUrl: json['download_url'],
      fileSizeMb: json['file_size_mb'] is String 
          ? double.parse(json['file_size_mb']) 
          : json['file_size_mb']?.toDouble(),
      releaseNotes: json['release_notes'],
      platform: json['platform'],
      isActive: json['is_active'] is String 
          ? json['is_active'].toLowerCase() == 'true' 
          : json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version_code': versionCode,
      'version_name': versionName,
      'minimum_version_code': minimumVersionCode,
      'download_url': downloadUrl,
      'file_size_mb': fileSizeMb,
      'release_notes': releaseNotes,
      'platform': platform,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool isUpdateRequired(int currentVersionCode) {
    return currentVersionCode < minimumVersionCode;
  }

  bool isUpdateAvailable(int currentVersionCode) {
    return currentVersionCode < versionCode;
  }
}