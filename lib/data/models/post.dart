// lib/data/models/post.dart
import 'package:parrokit/data/models/vote_option.dart';

class Post {
  final String id;
  final String postType;
  final String category;
  final String? targetLanguage;
  final String title;
  final String content;
  final List<String> tags;
  final String authorId;
  final String authorNickname;
  final String? authorAvatarUrl;
  final String snippet;
  final bool hasImage;
  final List<String> imageUrls;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int scrapCount;
  final String status;
  final int reportCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<DateTime> editHistory;
  final List<VoteOption>? voteOptions;
  final DateTime? voteEndTime;
  
  // --- Q&A 전용 필드 ---
  final String questionStatus; // 'waiting', 'resolved', 'expired'
  final String? acceptedCommentId;
  final int rewardCrackers;
  final DateTime? expireAt;

  const Post({
    required this.id,
    required this.postType,
    required this.category,
    this.targetLanguage,
    required this.title,
    required this.content,
    this.tags = const [],
    required this.authorId,
    required this.authorNickname,
    this.authorAvatarUrl,
    required this.snippet,
    this.hasImage = false,
    this.imageUrls = const [],
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.scrapCount = 0,
    this.status = 'active',
    this.reportCount = 0,
    this.createdAt,
    this.updatedAt,
    this.editHistory = const [],
    this.voteOptions,
    this.voteEndTime,
    this.questionStatus = 'waiting',
    this.acceptedCommentId,
    this.rewardCrackers = 0,
    this.expireAt,
  });

  Post copyWith({
    String? id,
    String? postType,
    String? category,
    String? targetLanguage,
    bool clearTargetLanguage = false,
    String? title,
    String? content,
    List<String>? tags,
    String? authorId,
    String? authorNickname,
    String? authorAvatarUrl,
    bool clearAuthorAvatarUrl = false,
    String? snippet,
    bool? hasImage,
    List<String>? imageUrls,
    int? viewCount,
    int? likeCount,
    int? commentCount,
    int? scrapCount,
    String? status,
    int? reportCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DateTime>? editHistory,
    List<VoteOption>? voteOptions,
    DateTime? voteEndTime,
    bool clearVoteEndTime = false,
    String? questionStatus,
    String? acceptedCommentId,
    bool clearAcceptedCommentId = false,
    int? rewardCrackers,
    DateTime? expireAt,
    bool clearExpireAt = false,
  }) {
    return Post(
      id: id ?? this.id,
      postType: postType ?? this.postType,
      category: category ?? this.category,
      targetLanguage: clearTargetLanguage ? null : (targetLanguage ?? this.targetLanguage),
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      authorId: authorId ?? this.authorId,
      authorNickname: authorNickname ?? this.authorNickname,
      authorAvatarUrl: clearAuthorAvatarUrl ? null : (authorAvatarUrl ?? this.authorAvatarUrl),
      snippet: snippet ?? this.snippet,
      hasImage: hasImage ?? this.hasImage,
      imageUrls: imageUrls ?? this.imageUrls,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      scrapCount: scrapCount ?? this.scrapCount,
      status: status ?? this.status,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      editHistory: editHistory ?? this.editHistory,
      voteOptions: voteOptions ?? this.voteOptions,
      voteEndTime: clearVoteEndTime ? null : (voteEndTime ?? this.voteEndTime),
      questionStatus: questionStatus ?? this.questionStatus,
      acceptedCommentId: clearAcceptedCommentId ? null : (acceptedCommentId ?? this.acceptedCommentId),
      rewardCrackers: rewardCrackers ?? this.rewardCrackers,
      expireAt: clearExpireAt ? null : (expireAt ?? this.expireAt),
    );
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String? ?? '',
      postType: json['postType'] as String? ?? 'board',
      category: json['category'] as String? ?? '',
      targetLanguage: json['targetLanguage'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      authorId: json['authorId'] as String? ?? '',
      authorNickname: json['authorNickname'] as String? ?? '',
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      snippet: json['snippet'] as String? ?? '',
      hasImage: json['hasImage'] as bool? ?? false,
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      scrapCount: (json['scrapCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      editHistory: (json['editHistory'] as List<dynamic>?)
              ?.map((e) => _parseDateTime(e))
              .whereType<DateTime>()
              .toList() ?? 
          [],
      voteOptions: (json['voteOptions'] as List<dynamic>?)
          ?.map((e) => VoteOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      voteEndTime: _parseDateTime(json['voteEndTime']),
      questionStatus: json['questionStatus'] as String? ?? 'waiting',
      acceptedCommentId: json['acceptedCommentId'] as String?,
      rewardCrackers: (json['rewardCrackers'] as num?)?.toInt() ?? 0,
      expireAt: _parseDateTime(json['expireAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postType': postType,
      'category': category,
      'targetLanguage': targetLanguage,
      'title': title,
      'content': content,
      'tags': tags,
      'authorId': authorId,
      'authorNickname': authorNickname,
      'authorAvatarUrl': authorAvatarUrl,
      'snippet': snippet,
      'hasImage': hasImage,
      'imageUrls': imageUrls,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'scrapCount': scrapCount,
      'status': status,
      'reportCount': reportCount,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'editHistory': editHistory.map((e) => e.toIso8601String()).toList(),
      if (voteOptions != null) 'voteOptions': voteOptions!.map((e) => e.toJson()).toList(),
      if (voteEndTime != null) 'voteEndTime': voteEndTime!.toUtc().toIso8601String(),
      'questionStatus': questionStatus,
      'acceptedCommentId': acceptedCommentId,
      'rewardCrackers': rewardCrackers,
      if (expireAt != null) 'expireAt': expireAt!.toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    // 서버 함수가 쓴 시각은 UTC(끝에 Z)다. 앱이 쓴 시각은 시간대 없는 현지
    // 시각이다. 둘 다 현지 시각으로 맞춰 둔다.
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }
}
