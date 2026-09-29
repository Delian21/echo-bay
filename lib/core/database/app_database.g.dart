// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PostsTable extends Posts with TableInfo<$PostsTable, PostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorIdMeta =
      const VerificationMeta('authorId');
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
      'author_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorNameMeta =
      const VerificationMeta('authorName');
  @override
  late final GeneratedColumn<String> authorName = GeneratedColumn<String>(
      'author_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mediaUrlMeta =
      const VerificationMeta('mediaUrl');
  @override
  late final GeneratedColumn<String> mediaUrl = GeneratedColumn<String>(
      'media_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _blurhashMeta =
      const VerificationMeta('blurhash');
  @override
  late final GeneratedColumn<String> blurhash = GeneratedColumn<String>(
      'blurhash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        authorId,
        authorName,
        body,
        mediaUrl,
        blurhash,
        createdAt,
        deletedAt,
        expiresAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'posts';
  @override
  VerificationContext validateIntegrity(Insertable<PostRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(_authorIdMeta,
          authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta));
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('author_name')) {
      context.handle(
          _authorNameMeta,
          authorName.isAcceptableOrUnknown(
              data['author_name']!, _authorNameMeta));
    } else if (isInserting) {
      context.missing(_authorNameMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('media_url')) {
      context.handle(_mediaUrlMeta,
          mediaUrl.isAcceptableOrUnknown(data['media_url']!, _mediaUrlMeta));
    }
    if (data.containsKey('blurhash')) {
      context.handle(_blurhashMeta,
          blurhash.isAcceptableOrUnknown(data['blurhash']!, _blurhashMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PostRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      authorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_id'])!,
      authorName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_name'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      mediaUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_url']),
      blurhash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}blurhash']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at']),
    );
  }

  @override
  $PostsTable createAlias(String alias) {
    return $PostsTable(attachedDatabase, alias);
  }
}

class PostRow extends DataClass implements Insertable<PostRow> {
  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final String? mediaUrl;

  /// Blurhash of the media (Instagram lesson): travels with the metadata,
  /// decodes synchronously at render time so the drift cache paints a
  /// meaningful placeholder offline, before/behind the full image.
  final String? blurhash;
  final DateTime createdAt;

  /// Soft-delete tombstone (undo window): non-null means the post is
  /// hidden from the feed but still restorable. Purged by the repository
  /// after the window closes.
  final DateTime? deletedAt;

  /// Ephemeral expiry ("fades in 24h"): non-null means the post is
  /// temporary. Visibility is filtered AT QUERY TIME (expiresAt > now),
  /// so correctness never depends on a background job; the row itself
  /// is purged lazily on app start. Null = keeps forever.
  final DateTime? expiresAt;
  const PostRow(
      {required this.id,
      required this.authorId,
      required this.authorName,
      required this.body,
      this.mediaUrl,
      this.blurhash,
      required this.createdAt,
      this.deletedAt,
      this.expiresAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['author_id'] = Variable<String>(authorId);
    map['author_name'] = Variable<String>(authorName);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || mediaUrl != null) {
      map['media_url'] = Variable<String>(mediaUrl);
    }
    if (!nullToAbsent || blurhash != null) {
      map['blurhash'] = Variable<String>(blurhash);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    return map;
  }

  PostsCompanion toCompanion(bool nullToAbsent) {
    return PostsCompanion(
      id: Value(id),
      authorId: Value(authorId),
      authorName: Value(authorName),
      body: Value(body),
      mediaUrl: mediaUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaUrl),
      blurhash: blurhash == null && nullToAbsent
          ? const Value.absent()
          : Value(blurhash),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory PostRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PostRow(
      id: serializer.fromJson<String>(json['id']),
      authorId: serializer.fromJson<String>(json['authorId']),
      authorName: serializer.fromJson<String>(json['authorName']),
      body: serializer.fromJson<String>(json['body']),
      mediaUrl: serializer.fromJson<String?>(json['mediaUrl']),
      blurhash: serializer.fromJson<String?>(json['blurhash']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'authorId': serializer.toJson<String>(authorId),
      'authorName': serializer.toJson<String>(authorName),
      'body': serializer.toJson<String>(body),
      'mediaUrl': serializer.toJson<String?>(mediaUrl),
      'blurhash': serializer.toJson<String?>(blurhash),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
    };
  }

  PostRow copyWith(
          {String? id,
          String? authorId,
          String? authorName,
          String? body,
          Value<String?> mediaUrl = const Value.absent(),
          Value<String?> blurhash = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<DateTime?> expiresAt = const Value.absent()}) =>
      PostRow(
        id: id ?? this.id,
        authorId: authorId ?? this.authorId,
        authorName: authorName ?? this.authorName,
        body: body ?? this.body,
        mediaUrl: mediaUrl.present ? mediaUrl.value : this.mediaUrl,
        blurhash: blurhash.present ? blurhash.value : this.blurhash,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
      );
  PostRow copyWithCompanion(PostsCompanion data) {
    return PostRow(
      id: data.id.present ? data.id.value : this.id,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      authorName:
          data.authorName.present ? data.authorName.value : this.authorName,
      body: data.body.present ? data.body.value : this.body,
      mediaUrl: data.mediaUrl.present ? data.mediaUrl.value : this.mediaUrl,
      blurhash: data.blurhash.present ? data.blurhash.value : this.blurhash,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PostRow(')
          ..write('id: $id, ')
          ..write('authorId: $authorId, ')
          ..write('authorName: $authorName, ')
          ..write('body: $body, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('blurhash: $blurhash, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, authorId, authorName, body, mediaUrl,
      blurhash, createdAt, deletedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PostRow &&
          other.id == this.id &&
          other.authorId == this.authorId &&
          other.authorName == this.authorName &&
          other.body == this.body &&
          other.mediaUrl == this.mediaUrl &&
          other.blurhash == this.blurhash &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt &&
          other.expiresAt == this.expiresAt);
}

class PostsCompanion extends UpdateCompanion<PostRow> {
  final Value<String> id;
  final Value<String> authorId;
  final Value<String> authorName;
  final Value<String> body;
  final Value<String?> mediaUrl;
  final Value<String?> blurhash;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime?> expiresAt;
  final Value<int> rowid;
  const PostsCompanion({
    this.id = const Value.absent(),
    this.authorId = const Value.absent(),
    this.authorName = const Value.absent(),
    this.body = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.blurhash = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PostsCompanion.insert({
    required String id,
    required String authorId,
    required String authorName,
    required String body,
    this.mediaUrl = const Value.absent(),
    this.blurhash = const Value.absent(),
    required DateTime createdAt,
    this.deletedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        authorId = Value(authorId),
        authorName = Value(authorName),
        body = Value(body),
        createdAt = Value(createdAt);
  static Insertable<PostRow> custom({
    Expression<String>? id,
    Expression<String>? authorId,
    Expression<String>? authorName,
    Expression<String>? body,
    Expression<String>? mediaUrl,
    Expression<String>? blurhash,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (authorId != null) 'author_id': authorId,
      if (authorName != null) 'author_name': authorName,
      if (body != null) 'body': body,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (blurhash != null) 'blurhash': blurhash,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PostsCompanion copyWith(
      {Value<String>? id,
      Value<String>? authorId,
      Value<String>? authorName,
      Value<String>? body,
      Value<String?>? mediaUrl,
      Value<String?>? blurhash,
      Value<DateTime>? createdAt,
      Value<DateTime?>? deletedAt,
      Value<DateTime?>? expiresAt,
      Value<int>? rowid}) {
    return PostsCompanion(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      body: body ?? this.body,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      blurhash: blurhash ?? this.blurhash,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (authorName.present) {
      map['author_name'] = Variable<String>(authorName.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (mediaUrl.present) {
      map['media_url'] = Variable<String>(mediaUrl.value);
    }
    if (blurhash.present) {
      map['blurhash'] = Variable<String>(blurhash.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PostsCompanion(')
          ..write('id: $id, ')
          ..write('authorId: $authorId, ')
          ..write('authorName: $authorName, ')
          ..write('body: $body, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('blurhash: $blurhash, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PostLikesTable extends PostLikes
    with TableInfo<$PostLikesTable, PostLikeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PostLikesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _postIdMeta = const VerificationMeta('postId');
  @override
  late final GeneratedColumn<String> postId = GeneratedColumn<String>(
      'post_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _likedAtMeta =
      const VerificationMeta('likedAt');
  @override
  late final GeneratedColumn<DateTime> likedAt = GeneratedColumn<DateTime>(
      'liked_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [postId, userId, likedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'post_likes';
  @override
  VerificationContext validateIntegrity(Insertable<PostLikeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('post_id')) {
      context.handle(_postIdMeta,
          postId.isAcceptableOrUnknown(data['post_id']!, _postIdMeta));
    } else if (isInserting) {
      context.missing(_postIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('liked_at')) {
      context.handle(_likedAtMeta,
          likedAt.isAcceptableOrUnknown(data['liked_at']!, _likedAtMeta));
    } else if (isInserting) {
      context.missing(_likedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {postId, userId};
  @override
  PostLikeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PostLikeRow(
      postId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}post_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      likedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}liked_at'])!,
    );
  }

  @override
  $PostLikesTable createAlias(String alias) {
    return $PostLikesTable(attachedDatabase, alias);
  }
}

class PostLikeRow extends DataClass implements Insertable<PostLikeRow> {
  final String postId;
  final String userId;
  final DateTime likedAt;
  const PostLikeRow(
      {required this.postId, required this.userId, required this.likedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['post_id'] = Variable<String>(postId);
    map['user_id'] = Variable<String>(userId);
    map['liked_at'] = Variable<DateTime>(likedAt);
    return map;
  }

  PostLikesCompanion toCompanion(bool nullToAbsent) {
    return PostLikesCompanion(
      postId: Value(postId),
      userId: Value(userId),
      likedAt: Value(likedAt),
    );
  }

  factory PostLikeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PostLikeRow(
      postId: serializer.fromJson<String>(json['postId']),
      userId: serializer.fromJson<String>(json['userId']),
      likedAt: serializer.fromJson<DateTime>(json['likedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'postId': serializer.toJson<String>(postId),
      'userId': serializer.toJson<String>(userId),
      'likedAt': serializer.toJson<DateTime>(likedAt),
    };
  }

  PostLikeRow copyWith({String? postId, String? userId, DateTime? likedAt}) =>
      PostLikeRow(
        postId: postId ?? this.postId,
        userId: userId ?? this.userId,
        likedAt: likedAt ?? this.likedAt,
      );
  PostLikeRow copyWithCompanion(PostLikesCompanion data) {
    return PostLikeRow(
      postId: data.postId.present ? data.postId.value : this.postId,
      userId: data.userId.present ? data.userId.value : this.userId,
      likedAt: data.likedAt.present ? data.likedAt.value : this.likedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PostLikeRow(')
          ..write('postId: $postId, ')
          ..write('userId: $userId, ')
          ..write('likedAt: $likedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(postId, userId, likedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PostLikeRow &&
          other.postId == this.postId &&
          other.userId == this.userId &&
          other.likedAt == this.likedAt);
}

class PostLikesCompanion extends UpdateCompanion<PostLikeRow> {
  final Value<String> postId;
  final Value<String> userId;
  final Value<DateTime> likedAt;
  final Value<int> rowid;
  const PostLikesCompanion({
    this.postId = const Value.absent(),
    this.userId = const Value.absent(),
    this.likedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PostLikesCompanion.insert({
    required String postId,
    required String userId,
    required DateTime likedAt,
    this.rowid = const Value.absent(),
  })  : postId = Value(postId),
        userId = Value(userId),
        likedAt = Value(likedAt);
  static Insertable<PostLikeRow> custom({
    Expression<String>? postId,
    Expression<String>? userId,
    Expression<DateTime>? likedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (postId != null) 'post_id': postId,
      if (userId != null) 'user_id': userId,
      if (likedAt != null) 'liked_at': likedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PostLikesCompanion copyWith(
      {Value<String>? postId,
      Value<String>? userId,
      Value<DateTime>? likedAt,
      Value<int>? rowid}) {
    return PostLikesCompanion(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      likedAt: likedAt ?? this.likedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (postId.present) {
      map['post_id'] = Variable<String>(postId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (likedAt.present) {
      map['liked_at'] = Variable<DateTime>(likedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PostLikesCompanion(')
          ..write('postId: $postId, ')
          ..write('userId: $userId, ')
          ..write('likedAt: $likedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, ConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _participantIdsMeta =
      const VerificationMeta('participantIds');
  @override
  late final GeneratedColumn<String> participantIds = GeneratedColumn<String>(
      'participant_ids', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastActivityAtMeta =
      const VerificationMeta('lastActivityAt');
  @override
  late final GeneratedColumn<DateTime> lastActivityAt =
      GeneratedColumn<DateTime>('last_activity_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, participantIds, lastActivityAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(Insertable<ConversationRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('participant_ids')) {
      context.handle(
          _participantIdsMeta,
          participantIds.isAcceptableOrUnknown(
              data['participant_ids']!, _participantIdsMeta));
    } else if (isInserting) {
      context.missing(_participantIdsMeta);
    }
    if (data.containsKey('last_activity_at')) {
      context.handle(
          _lastActivityAtMeta,
          lastActivityAt.isAcceptableOrUnknown(
              data['last_activity_at']!, _lastActivityAtMeta));
    } else if (isInserting) {
      context.missing(_lastActivityAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      participantIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}participant_ids'])!,
      lastActivityAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_activity_at'])!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class ConversationRow extends DataClass implements Insertable<ConversationRow> {
  final String id;
  final String title;
  final String participantIds;
  final DateTime lastActivityAt;
  const ConversationRow(
      {required this.id,
      required this.title,
      required this.participantIds,
      required this.lastActivityAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['participant_ids'] = Variable<String>(participantIds);
    map['last_activity_at'] = Variable<DateTime>(lastActivityAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      title: Value(title),
      participantIds: Value(participantIds),
      lastActivityAt: Value(lastActivityAt),
    );
  }

  factory ConversationRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      participantIds: serializer.fromJson<String>(json['participantIds']),
      lastActivityAt: serializer.fromJson<DateTime>(json['lastActivityAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'participantIds': serializer.toJson<String>(participantIds),
      'lastActivityAt': serializer.toJson<DateTime>(lastActivityAt),
    };
  }

  ConversationRow copyWith(
          {String? id,
          String? title,
          String? participantIds,
          DateTime? lastActivityAt}) =>
      ConversationRow(
        id: id ?? this.id,
        title: title ?? this.title,
        participantIds: participantIds ?? this.participantIds,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      );
  ConversationRow copyWithCompanion(ConversationsCompanion data) {
    return ConversationRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      participantIds: data.participantIds.present
          ? data.participantIds.value
          : this.participantIds,
      lastActivityAt: data.lastActivityAt.present
          ? data.lastActivityAt.value
          : this.lastActivityAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('participantIds: $participantIds, ')
          ..write('lastActivityAt: $lastActivityAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, participantIds, lastActivityAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.participantIds == this.participantIds &&
          other.lastActivityAt == this.lastActivityAt);
}

class ConversationsCompanion extends UpdateCompanion<ConversationRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> participantIds;
  final Value<DateTime> lastActivityAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.participantIds = const Value.absent(),
    this.lastActivityAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required String title,
    required String participantIds,
    required DateTime lastActivityAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        participantIds = Value(participantIds),
        lastActivityAt = Value(lastActivityAt);
  static Insertable<ConversationRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? participantIds,
    Expression<DateTime>? lastActivityAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (participantIds != null) 'participant_ids': participantIds,
      if (lastActivityAt != null) 'last_activity_at': lastActivityAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? participantIds,
      Value<DateTime>? lastActivityAt,
      Value<int>? rowid}) {
    return ConversationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      participantIds: participantIds ?? this.participantIds,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (participantIds.present) {
      map['participant_ids'] = Variable<String>(participantIds.value);
    }
    if (lastActivityAt.present) {
      map['last_activity_at'] = Variable<DateTime>(lastActivityAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('participantIds: $participantIds, ')
          ..write('lastActivityAt: $lastActivityAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ciphertextMeta =
      const VerificationMeta('ciphertext');
  @override
  late final GeneratedColumn<String> ciphertext = GeneratedColumn<String>(
      'ciphertext', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<MsgSyncStatus, String>
      syncStatus = GeneratedColumn<String>('sync_status', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<MsgSyncStatus>($MessagesTable.$convertersyncStatus);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _editedAtMeta =
      const VerificationMeta('editedAt');
  @override
  late final GeneratedColumn<DateTime> editedAt = GeneratedColumn<DateTime>(
      'edited_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _attachmentKindMeta =
      const VerificationMeta('attachmentKind');
  @override
  late final GeneratedColumn<String> attachmentKind = GeneratedColumn<String>(
      'attachment_kind', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attachmentPathMeta =
      const VerificationMeta('attachmentPath');
  @override
  late final GeneratedColumn<String> attachmentPath = GeneratedColumn<String>(
      'attachment_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attachmentDurationMsMeta =
      const VerificationMeta('attachmentDurationMs');
  @override
  late final GeneratedColumn<int> attachmentDurationMs = GeneratedColumn<int>(
      'attachment_duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        senderId,
        body,
        ciphertext,
        syncStatus,
        createdAt,
        editedAt,
        deletedAt,
        attachmentKind,
        attachmentPath,
        attachmentDurationMs
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<MessageRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
          _ciphertextMeta,
          ciphertext.isAcceptableOrUnknown(
              data['ciphertext']!, _ciphertextMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('edited_at')) {
      context.handle(_editedAtMeta,
          editedAt.isAcceptableOrUnknown(data['edited_at']!, _editedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('attachment_kind')) {
      context.handle(
          _attachmentKindMeta,
          attachmentKind.isAcceptableOrUnknown(
              data['attachment_kind']!, _attachmentKindMeta));
    }
    if (data.containsKey('attachment_path')) {
      context.handle(
          _attachmentPathMeta,
          attachmentPath.isAcceptableOrUnknown(
              data['attachment_path']!, _attachmentPathMeta));
    }
    if (data.containsKey('attachment_duration_ms')) {
      context.handle(
          _attachmentDurationMsMeta,
          attachmentDurationMs.isAcceptableOrUnknown(
              data['attachment_duration_ms']!, _attachmentDurationMsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      ciphertext: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ciphertext']),
      syncStatus: $MessagesTable.$convertersyncStatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      editedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}edited_at']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      attachmentKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attachment_kind']),
      attachmentPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attachment_path']),
      attachmentDurationMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}attachment_duration_ms']),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MsgSyncStatus, String, String>
      $convertersyncStatus =
      const EnumNameConverter<MsgSyncStatus>(MsgSyncStatus.values);
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;

  /// Locally assigned client id; used for dedup and outbox tracking.
  final String conversationId;
  final String senderId;
  final String body;

  /// Encrypted payload. Mock stage: null. Real stage: populated, [body]
  /// holds only a local decryption cache.
  final String? ciphertext;

  /// Outbox state machine (normative — see ARCHITECTURE.md §5):
  ///   pending   — written locally, awaiting transport
  ///   sent      — handed to (mock) transport
  ///   delivered — transport confirmed receipt by the peer/device
  ///   read      — the peer rendered the message
  ///   failed    — attempts exhausted, retryable
  final MsgSyncStatus syncStatus;
  final DateTime createdAt;

  /// Tombstones (Telegram/WhatsApp model): edits and delete-for-everyone
  /// are terminal states synced like any other row, never hard deletes —
  /// the offline read path must stay identical to the online one.
  final DateTime? editedAt;
  final DateTime? deletedAt;

  /// Attachment (schema v9/v10). Kind + local file path; [attachmentPath]
  /// points into the app's attachments directory (copied on send so the
  /// picker's temp file can't vanish under us). [attachmentDurationMs]
  /// carries voice-note length (null for photo/video). Null = text-only.
  final String? attachmentKind;
  final String? attachmentPath;
  final int? attachmentDurationMs;
  const MessageRow(
      {required this.id,
      required this.conversationId,
      required this.senderId,
      required this.body,
      this.ciphertext,
      required this.syncStatus,
      required this.createdAt,
      this.editedAt,
      this.deletedAt,
      this.attachmentKind,
      this.attachmentPath,
      this.attachmentDurationMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_id'] = Variable<String>(senderId);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || ciphertext != null) {
      map['ciphertext'] = Variable<String>(ciphertext);
    }
    {
      map['sync_status'] = Variable<String>(
          $MessagesTable.$convertersyncStatus.toSql(syncStatus));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || editedAt != null) {
      map['edited_at'] = Variable<DateTime>(editedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || attachmentKind != null) {
      map['attachment_kind'] = Variable<String>(attachmentKind);
    }
    if (!nullToAbsent || attachmentPath != null) {
      map['attachment_path'] = Variable<String>(attachmentPath);
    }
    if (!nullToAbsent || attachmentDurationMs != null) {
      map['attachment_duration_ms'] = Variable<int>(attachmentDurationMs);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      body: Value(body),
      ciphertext: ciphertext == null && nullToAbsent
          ? const Value.absent()
          : Value(ciphertext),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      editedAt: editedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      attachmentKind: attachmentKind == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentKind),
      attachmentPath: attachmentPath == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentPath),
      attachmentDurationMs: attachmentDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentDurationMs),
    );
  }

  factory MessageRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      body: serializer.fromJson<String>(json['body']),
      ciphertext: serializer.fromJson<String?>(json['ciphertext']),
      syncStatus: $MessagesTable.$convertersyncStatus
          .fromJson(serializer.fromJson<String>(json['syncStatus'])),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      editedAt: serializer.fromJson<DateTime?>(json['editedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      attachmentKind: serializer.fromJson<String?>(json['attachmentKind']),
      attachmentPath: serializer.fromJson<String?>(json['attachmentPath']),
      attachmentDurationMs:
          serializer.fromJson<int?>(json['attachmentDurationMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderId': serializer.toJson<String>(senderId),
      'body': serializer.toJson<String>(body),
      'ciphertext': serializer.toJson<String?>(ciphertext),
      'syncStatus': serializer.toJson<String>(
          $MessagesTable.$convertersyncStatus.toJson(syncStatus)),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'editedAt': serializer.toJson<DateTime?>(editedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'attachmentKind': serializer.toJson<String?>(attachmentKind),
      'attachmentPath': serializer.toJson<String?>(attachmentPath),
      'attachmentDurationMs': serializer.toJson<int?>(attachmentDurationMs),
    };
  }

  MessageRow copyWith(
          {String? id,
          String? conversationId,
          String? senderId,
          String? body,
          Value<String?> ciphertext = const Value.absent(),
          MsgSyncStatus? syncStatus,
          DateTime? createdAt,
          Value<DateTime?> editedAt = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> attachmentKind = const Value.absent(),
          Value<String?> attachmentPath = const Value.absent(),
          Value<int?> attachmentDurationMs = const Value.absent()}) =>
      MessageRow(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        senderId: senderId ?? this.senderId,
        body: body ?? this.body,
        ciphertext: ciphertext.present ? ciphertext.value : this.ciphertext,
        syncStatus: syncStatus ?? this.syncStatus,
        createdAt: createdAt ?? this.createdAt,
        editedAt: editedAt.present ? editedAt.value : this.editedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        attachmentKind:
            attachmentKind.present ? attachmentKind.value : this.attachmentKind,
        attachmentPath:
            attachmentPath.present ? attachmentPath.value : this.attachmentPath,
        attachmentDurationMs: attachmentDurationMs.present
            ? attachmentDurationMs.value
            : this.attachmentDurationMs,
      );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      body: data.body.present ? data.body.value : this.body,
      ciphertext:
          data.ciphertext.present ? data.ciphertext.value : this.ciphertext,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      attachmentKind: data.attachmentKind.present
          ? data.attachmentKind.value
          : this.attachmentKind,
      attachmentPath: data.attachmentPath.present
          ? data.attachmentPath.value
          : this.attachmentPath,
      attachmentDurationMs: data.attachmentDurationMs.present
          ? data.attachmentDurationMs.value
          : this.attachmentDurationMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('body: $body, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('attachmentKind: $attachmentKind, ')
          ..write('attachmentPath: $attachmentPath, ')
          ..write('attachmentDurationMs: $attachmentDurationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      conversationId,
      senderId,
      body,
      ciphertext,
      syncStatus,
      createdAt,
      editedAt,
      deletedAt,
      attachmentKind,
      attachmentPath,
      attachmentDurationMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.body == this.body &&
          other.ciphertext == this.ciphertext &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.editedAt == this.editedAt &&
          other.deletedAt == this.deletedAt &&
          other.attachmentKind == this.attachmentKind &&
          other.attachmentPath == this.attachmentPath &&
          other.attachmentDurationMs == this.attachmentDurationMs);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> senderId;
  final Value<String> body;
  final Value<String?> ciphertext;
  final Value<MsgSyncStatus> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime?> editedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> attachmentKind;
  final Value<String?> attachmentPath;
  final Value<int?> attachmentDurationMs;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.body = const Value.absent(),
    this.ciphertext = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.attachmentKind = const Value.absent(),
    this.attachmentPath = const Value.absent(),
    this.attachmentDurationMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String conversationId,
    required String senderId,
    required String body,
    this.ciphertext = const Value.absent(),
    required MsgSyncStatus syncStatus,
    required DateTime createdAt,
    this.editedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.attachmentKind = const Value.absent(),
    this.attachmentPath = const Value.absent(),
    this.attachmentDurationMs = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        conversationId = Value(conversationId),
        senderId = Value(senderId),
        body = Value(body),
        syncStatus = Value(syncStatus),
        createdAt = Value(createdAt);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? senderId,
    Expression<String>? body,
    Expression<String>? ciphertext,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? editedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? attachmentKind,
    Expression<String>? attachmentPath,
    Expression<int>? attachmentDurationMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (body != null) 'body': body,
      if (ciphertext != null) 'ciphertext': ciphertext,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (editedAt != null) 'edited_at': editedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (attachmentKind != null) 'attachment_kind': attachmentKind,
      if (attachmentPath != null) 'attachment_path': attachmentPath,
      if (attachmentDurationMs != null)
        'attachment_duration_ms': attachmentDurationMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? conversationId,
      Value<String>? senderId,
      Value<String>? body,
      Value<String?>? ciphertext,
      Value<MsgSyncStatus>? syncStatus,
      Value<DateTime>? createdAt,
      Value<DateTime?>? editedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? attachmentKind,
      Value<String?>? attachmentPath,
      Value<int?>? attachmentDurationMs,
      Value<int>? rowid}) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      ciphertext: ciphertext ?? this.ciphertext,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      attachmentKind: attachmentKind ?? this.attachmentKind,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      attachmentDurationMs: attachmentDurationMs ?? this.attachmentDurationMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<String>(ciphertext.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
          $MessagesTable.$convertersyncStatus.toSql(syncStatus.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<DateTime>(editedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (attachmentKind.present) {
      map['attachment_kind'] = Variable<String>(attachmentKind.value);
    }
    if (attachmentPath.present) {
      map['attachment_path'] = Variable<String>(attachmentPath.value);
    }
    if (attachmentDurationMs.present) {
      map['attachment_duration_ms'] = Variable<int>(attachmentDurationMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('body: $body, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('attachmentKind: $attachmentKind, ')
          ..write('attachmentPath: $attachmentPath, ')
          ..write('attachmentDurationMs: $attachmentDurationMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NexusChannelsTable extends NexusChannels
    with TableInfo<$NexusChannelsTable, NexusChannelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NexusChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastPostAtMeta =
      const VerificationMeta('lastPostAt');
  @override
  late final GeneratedColumn<DateTime> lastPostAt = GeneratedColumn<DateTime>(
      'last_post_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, title, description, lastPostAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nexus_channels';
  @override
  VerificationContext validateIntegrity(Insertable<NexusChannelRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('last_post_at')) {
      context.handle(
          _lastPostAtMeta,
          lastPostAt.isAcceptableOrUnknown(
              data['last_post_at']!, _lastPostAtMeta));
    } else if (isInserting) {
      context.missing(_lastPostAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NexusChannelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NexusChannelRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      lastPostAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_post_at'])!,
    );
  }

  @override
  $NexusChannelsTable createAlias(String alias) {
    return $NexusChannelsTable(attachedDatabase, alias);
  }
}

class NexusChannelRow extends DataClass implements Insertable<NexusChannelRow> {
  final String id;
  final String title;
  final String description;
  final DateTime lastPostAt;
  const NexusChannelRow(
      {required this.id,
      required this.title,
      required this.description,
      required this.lastPostAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['last_post_at'] = Variable<DateTime>(lastPostAt);
    return map;
  }

  NexusChannelsCompanion toCompanion(bool nullToAbsent) {
    return NexusChannelsCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      lastPostAt: Value(lastPostAt),
    );
  }

  factory NexusChannelRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NexusChannelRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      lastPostAt: serializer.fromJson<DateTime>(json['lastPostAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'lastPostAt': serializer.toJson<DateTime>(lastPostAt),
    };
  }

  NexusChannelRow copyWith(
          {String? id,
          String? title,
          String? description,
          DateTime? lastPostAt}) =>
      NexusChannelRow(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        lastPostAt: lastPostAt ?? this.lastPostAt,
      );
  NexusChannelRow copyWithCompanion(NexusChannelsCompanion data) {
    return NexusChannelRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      lastPostAt:
          data.lastPostAt.present ? data.lastPostAt.value : this.lastPostAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NexusChannelRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('lastPostAt: $lastPostAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, description, lastPostAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NexusChannelRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.lastPostAt == this.lastPostAt);
}

class NexusChannelsCompanion extends UpdateCompanion<NexusChannelRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> description;
  final Value<DateTime> lastPostAt;
  final Value<int> rowid;
  const NexusChannelsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.lastPostAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NexusChannelsCompanion.insert({
    required String id,
    required String title,
    required String description,
    required DateTime lastPostAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        description = Value(description),
        lastPostAt = Value(lastPostAt);
  static Insertable<NexusChannelRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<DateTime>? lastPostAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (lastPostAt != null) 'last_post_at': lastPostAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NexusChannelsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? description,
      Value<DateTime>? lastPostAt,
      Value<int>? rowid}) {
    return NexusChannelsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      lastPostAt: lastPostAt ?? this.lastPostAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (lastPostAt.present) {
      map['last_post_at'] = Variable<DateTime>(lastPostAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NexusChannelsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('lastPostAt: $lastPostAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChannelPostsTable extends ChannelPosts
    with TableInfo<$ChannelPostsTable, ChannelPostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelPostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _channelIdMeta =
      const VerificationMeta('channelId');
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
      'channel_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorNameMeta =
      const VerificationMeta('authorName');
  @override
  late final GeneratedColumn<String> authorName = GeneratedColumn<String>(
      'author_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _blurhashMeta =
      const VerificationMeta('blurhash');
  @override
  late final GeneratedColumn<String> blurhash = GeneratedColumn<String>(
      'blurhash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, channelId, authorName, body, createdAt, expiresAt, blurhash];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channel_posts';
  @override
  VerificationContext validateIntegrity(Insertable<ChannelPostRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(_channelIdMeta,
          channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta));
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('author_name')) {
      context.handle(
          _authorNameMeta,
          authorName.isAcceptableOrUnknown(
              data['author_name']!, _authorNameMeta));
    } else if (isInserting) {
      context.missing(_authorNameMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    }
    if (data.containsKey('blurhash')) {
      context.handle(_blurhashMeta,
          blurhash.isAcceptableOrUnknown(data['blurhash']!, _blurhashMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChannelPostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChannelPostRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      channelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel_id'])!,
      authorName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_name'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at']),
      blurhash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}blurhash']),
    );
  }

  @override
  $ChannelPostsTable createAlias(String alias) {
    return $ChannelPostsTable(attachedDatabase, alias);
  }
}

class ChannelPostRow extends DataClass implements Insertable<ChannelPostRow> {
  final String id;
  final String channelId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? blurhash;
  const ChannelPostRow(
      {required this.id,
      required this.channelId,
      required this.authorName,
      required this.body,
      required this.createdAt,
      this.expiresAt,
      this.blurhash});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['channel_id'] = Variable<String>(channelId);
    map['author_name'] = Variable<String>(authorName);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    if (!nullToAbsent || blurhash != null) {
      map['blurhash'] = Variable<String>(blurhash);
    }
    return map;
  }

  ChannelPostsCompanion toCompanion(bool nullToAbsent) {
    return ChannelPostsCompanion(
      id: Value(id),
      channelId: Value(channelId),
      authorName: Value(authorName),
      body: Value(body),
      createdAt: Value(createdAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      blurhash: blurhash == null && nullToAbsent
          ? const Value.absent()
          : Value(blurhash),
    );
  }

  factory ChannelPostRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChannelPostRow(
      id: serializer.fromJson<String>(json['id']),
      channelId: serializer.fromJson<String>(json['channelId']),
      authorName: serializer.fromJson<String>(json['authorName']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      blurhash: serializer.fromJson<String?>(json['blurhash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'channelId': serializer.toJson<String>(channelId),
      'authorName': serializer.toJson<String>(authorName),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'blurhash': serializer.toJson<String?>(blurhash),
    };
  }

  ChannelPostRow copyWith(
          {String? id,
          String? channelId,
          String? authorName,
          String? body,
          DateTime? createdAt,
          Value<DateTime?> expiresAt = const Value.absent(),
          Value<String?> blurhash = const Value.absent()}) =>
      ChannelPostRow(
        id: id ?? this.id,
        channelId: channelId ?? this.channelId,
        authorName: authorName ?? this.authorName,
        body: body ?? this.body,
        createdAt: createdAt ?? this.createdAt,
        expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
        blurhash: blurhash.present ? blurhash.value : this.blurhash,
      );
  ChannelPostRow copyWithCompanion(ChannelPostsCompanion data) {
    return ChannelPostRow(
      id: data.id.present ? data.id.value : this.id,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      authorName:
          data.authorName.present ? data.authorName.value : this.authorName,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      blurhash: data.blurhash.present ? data.blurhash.value : this.blurhash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChannelPostRow(')
          ..write('id: $id, ')
          ..write('channelId: $channelId, ')
          ..write('authorName: $authorName, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('blurhash: $blurhash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, channelId, authorName, body, createdAt, expiresAt, blurhash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelPostRow &&
          other.id == this.id &&
          other.channelId == this.channelId &&
          other.authorName == this.authorName &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.blurhash == this.blurhash);
}

class ChannelPostsCompanion extends UpdateCompanion<ChannelPostRow> {
  final Value<String> id;
  final Value<String> channelId;
  final Value<String> authorName;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<DateTime?> expiresAt;
  final Value<String?> blurhash;
  final Value<int> rowid;
  const ChannelPostsCompanion({
    this.id = const Value.absent(),
    this.channelId = const Value.absent(),
    this.authorName = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.blurhash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelPostsCompanion.insert({
    required String id,
    required String channelId,
    required String authorName,
    required String body,
    required DateTime createdAt,
    this.expiresAt = const Value.absent(),
    this.blurhash = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        channelId = Value(channelId),
        authorName = Value(authorName),
        body = Value(body),
        createdAt = Value(createdAt);
  static Insertable<ChannelPostRow> custom({
    Expression<String>? id,
    Expression<String>? channelId,
    Expression<String>? authorName,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
    Expression<String>? blurhash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (channelId != null) 'channel_id': channelId,
      if (authorName != null) 'author_name': authorName,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (blurhash != null) 'blurhash': blurhash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelPostsCompanion copyWith(
      {Value<String>? id,
      Value<String>? channelId,
      Value<String>? authorName,
      Value<String>? body,
      Value<DateTime>? createdAt,
      Value<DateTime?>? expiresAt,
      Value<String?>? blurhash,
      Value<int>? rowid}) {
    return ChannelPostsCompanion(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      authorName: authorName ?? this.authorName,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      blurhash: blurhash ?? this.blurhash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (authorName.present) {
      map['author_name'] = Variable<String>(authorName.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (blurhash.present) {
      map['blurhash'] = Variable<String>(blurhash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelPostsCompanion(')
          ..write('id: $id, ')
          ..write('channelId: $channelId, ')
          ..write('authorName: $authorName, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('blurhash: $blurhash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NexusGroupsTable extends NexusGroups
    with TableInfo<$NexusGroupsTable, NexusGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NexusGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _memberIdsMeta =
      const VerificationMeta('memberIds');
  @override
  late final GeneratedColumn<String> memberIds = GeneratedColumn<String>(
      'member_ids', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastActivityAtMeta =
      const VerificationMeta('lastActivityAt');
  @override
  late final GeneratedColumn<DateTime> lastActivityAt =
      GeneratedColumn<DateTime>('last_activity_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, title, memberIds, lastActivityAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nexus_groups';
  @override
  VerificationContext validateIntegrity(Insertable<NexusGroupRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('member_ids')) {
      context.handle(_memberIdsMeta,
          memberIds.isAcceptableOrUnknown(data['member_ids']!, _memberIdsMeta));
    } else if (isInserting) {
      context.missing(_memberIdsMeta);
    }
    if (data.containsKey('last_activity_at')) {
      context.handle(
          _lastActivityAtMeta,
          lastActivityAt.isAcceptableOrUnknown(
              data['last_activity_at']!, _lastActivityAtMeta));
    } else if (isInserting) {
      context.missing(_lastActivityAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NexusGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NexusGroupRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      memberIds: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}member_ids'])!,
      lastActivityAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_activity_at'])!,
    );
  }

  @override
  $NexusGroupsTable createAlias(String alias) {
    return $NexusGroupsTable(attachedDatabase, alias);
  }
}

class NexusGroupRow extends DataClass implements Insertable<NexusGroupRow> {
  final String id;
  final String title;
  final String memberIds;
  final DateTime lastActivityAt;
  const NexusGroupRow(
      {required this.id,
      required this.title,
      required this.memberIds,
      required this.lastActivityAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['member_ids'] = Variable<String>(memberIds);
    map['last_activity_at'] = Variable<DateTime>(lastActivityAt);
    return map;
  }

  NexusGroupsCompanion toCompanion(bool nullToAbsent) {
    return NexusGroupsCompanion(
      id: Value(id),
      title: Value(title),
      memberIds: Value(memberIds),
      lastActivityAt: Value(lastActivityAt),
    );
  }

  factory NexusGroupRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NexusGroupRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      memberIds: serializer.fromJson<String>(json['memberIds']),
      lastActivityAt: serializer.fromJson<DateTime>(json['lastActivityAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'memberIds': serializer.toJson<String>(memberIds),
      'lastActivityAt': serializer.toJson<DateTime>(lastActivityAt),
    };
  }

  NexusGroupRow copyWith(
          {String? id,
          String? title,
          String? memberIds,
          DateTime? lastActivityAt}) =>
      NexusGroupRow(
        id: id ?? this.id,
        title: title ?? this.title,
        memberIds: memberIds ?? this.memberIds,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      );
  NexusGroupRow copyWithCompanion(NexusGroupsCompanion data) {
    return NexusGroupRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      memberIds: data.memberIds.present ? data.memberIds.value : this.memberIds,
      lastActivityAt: data.lastActivityAt.present
          ? data.lastActivityAt.value
          : this.lastActivityAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NexusGroupRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('memberIds: $memberIds, ')
          ..write('lastActivityAt: $lastActivityAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, memberIds, lastActivityAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NexusGroupRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.memberIds == this.memberIds &&
          other.lastActivityAt == this.lastActivityAt);
}

class NexusGroupsCompanion extends UpdateCompanion<NexusGroupRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> memberIds;
  final Value<DateTime> lastActivityAt;
  final Value<int> rowid;
  const NexusGroupsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.memberIds = const Value.absent(),
    this.lastActivityAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NexusGroupsCompanion.insert({
    required String id,
    required String title,
    required String memberIds,
    required DateTime lastActivityAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        memberIds = Value(memberIds),
        lastActivityAt = Value(lastActivityAt);
  static Insertable<NexusGroupRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? memberIds,
    Expression<DateTime>? lastActivityAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (memberIds != null) 'member_ids': memberIds,
      if (lastActivityAt != null) 'last_activity_at': lastActivityAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NexusGroupsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? memberIds,
      Value<DateTime>? lastActivityAt,
      Value<int>? rowid}) {
    return NexusGroupsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      memberIds: memberIds ?? this.memberIds,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (memberIds.present) {
      map['member_ids'] = Variable<String>(memberIds.value);
    }
    if (lastActivityAt.present) {
      map['last_activity_at'] = Variable<DateTime>(lastActivityAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NexusGroupsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('memberIds: $memberIds, ')
          ..write('lastActivityAt: $lastActivityAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupMessagesTable extends GroupMessages
    with TableInfo<$GroupMessagesTable, GroupMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<MsgSyncStatus, String>
      syncStatus = GeneratedColumn<String>('sync_status', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<MsgSyncStatus>(
              $GroupMessagesTable.$convertersyncStatus);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _editedAtMeta =
      const VerificationMeta('editedAt');
  @override
  late final GeneratedColumn<DateTime> editedAt = GeneratedColumn<DateTime>(
      'edited_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _blurhashMeta =
      const VerificationMeta('blurhash');
  @override
  late final GeneratedColumn<String> blurhash = GeneratedColumn<String>(
      'blurhash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attachmentKindMeta =
      const VerificationMeta('attachmentKind');
  @override
  late final GeneratedColumn<String> attachmentKind = GeneratedColumn<String>(
      'attachment_kind', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attachmentPathMeta =
      const VerificationMeta('attachmentPath');
  @override
  late final GeneratedColumn<String> attachmentPath = GeneratedColumn<String>(
      'attachment_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attachmentDurationMsMeta =
      const VerificationMeta('attachmentDurationMs');
  @override
  late final GeneratedColumn<int> attachmentDurationMs = GeneratedColumn<int>(
      'attachment_duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        senderId,
        body,
        syncStatus,
        createdAt,
        editedAt,
        deletedAt,
        blurhash,
        attachmentKind,
        attachmentPath,
        attachmentDurationMs
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_messages';
  @override
  VerificationContext validateIntegrity(Insertable<GroupMessageRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('edited_at')) {
      context.handle(_editedAtMeta,
          editedAt.isAcceptableOrUnknown(data['edited_at']!, _editedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('blurhash')) {
      context.handle(_blurhashMeta,
          blurhash.isAcceptableOrUnknown(data['blurhash']!, _blurhashMeta));
    }
    if (data.containsKey('attachment_kind')) {
      context.handle(
          _attachmentKindMeta,
          attachmentKind.isAcceptableOrUnknown(
              data['attachment_kind']!, _attachmentKindMeta));
    }
    if (data.containsKey('attachment_path')) {
      context.handle(
          _attachmentPathMeta,
          attachmentPath.isAcceptableOrUnknown(
              data['attachment_path']!, _attachmentPathMeta));
    }
    if (data.containsKey('attachment_duration_ms')) {
      context.handle(
          _attachmentDurationMsMeta,
          attachmentDurationMs.isAcceptableOrUnknown(
              data['attachment_duration_ms']!, _attachmentDurationMsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMessageRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      syncStatus: $GroupMessagesTable.$convertersyncStatus.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}sync_status'])!),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      editedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}edited_at']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      blurhash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}blurhash']),
      attachmentKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attachment_kind']),
      attachmentPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attachment_path']),
      attachmentDurationMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}attachment_duration_ms']),
    );
  }

  @override
  $GroupMessagesTable createAlias(String alias) {
    return $GroupMessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MsgSyncStatus, String, String>
      $convertersyncStatus =
      const EnumNameConverter<MsgSyncStatus>(MsgSyncStatus.values);
}

class GroupMessageRow extends DataClass implements Insertable<GroupMessageRow> {
  final String id;
  final String groupId;
  final String senderId;
  final String body;
  final MsgSyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? blurhash;

  /// Attachment (schema v9/v10), same contract as [Messages].
  final String? attachmentKind;
  final String? attachmentPath;
  final int? attachmentDurationMs;
  const GroupMessageRow(
      {required this.id,
      required this.groupId,
      required this.senderId,
      required this.body,
      required this.syncStatus,
      required this.createdAt,
      this.editedAt,
      this.deletedAt,
      this.blurhash,
      this.attachmentKind,
      this.attachmentPath,
      this.attachmentDurationMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['sender_id'] = Variable<String>(senderId);
    map['body'] = Variable<String>(body);
    {
      map['sync_status'] = Variable<String>(
          $GroupMessagesTable.$convertersyncStatus.toSql(syncStatus));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || editedAt != null) {
      map['edited_at'] = Variable<DateTime>(editedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || blurhash != null) {
      map['blurhash'] = Variable<String>(blurhash);
    }
    if (!nullToAbsent || attachmentKind != null) {
      map['attachment_kind'] = Variable<String>(attachmentKind);
    }
    if (!nullToAbsent || attachmentPath != null) {
      map['attachment_path'] = Variable<String>(attachmentPath);
    }
    if (!nullToAbsent || attachmentDurationMs != null) {
      map['attachment_duration_ms'] = Variable<int>(attachmentDurationMs);
    }
    return map;
  }

  GroupMessagesCompanion toCompanion(bool nullToAbsent) {
    return GroupMessagesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      senderId: Value(senderId),
      body: Value(body),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      editedAt: editedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      blurhash: blurhash == null && nullToAbsent
          ? const Value.absent()
          : Value(blurhash),
      attachmentKind: attachmentKind == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentKind),
      attachmentPath: attachmentPath == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentPath),
      attachmentDurationMs: attachmentDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentDurationMs),
    );
  }

  factory GroupMessageRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMessageRow(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      body: serializer.fromJson<String>(json['body']),
      syncStatus: $GroupMessagesTable.$convertersyncStatus
          .fromJson(serializer.fromJson<String>(json['syncStatus'])),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      editedAt: serializer.fromJson<DateTime?>(json['editedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      blurhash: serializer.fromJson<String?>(json['blurhash']),
      attachmentKind: serializer.fromJson<String?>(json['attachmentKind']),
      attachmentPath: serializer.fromJson<String?>(json['attachmentPath']),
      attachmentDurationMs:
          serializer.fromJson<int?>(json['attachmentDurationMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'senderId': serializer.toJson<String>(senderId),
      'body': serializer.toJson<String>(body),
      'syncStatus': serializer.toJson<String>(
          $GroupMessagesTable.$convertersyncStatus.toJson(syncStatus)),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'editedAt': serializer.toJson<DateTime?>(editedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'blurhash': serializer.toJson<String?>(blurhash),
      'attachmentKind': serializer.toJson<String?>(attachmentKind),
      'attachmentPath': serializer.toJson<String?>(attachmentPath),
      'attachmentDurationMs': serializer.toJson<int?>(attachmentDurationMs),
    };
  }

  GroupMessageRow copyWith(
          {String? id,
          String? groupId,
          String? senderId,
          String? body,
          MsgSyncStatus? syncStatus,
          DateTime? createdAt,
          Value<DateTime?> editedAt = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> blurhash = const Value.absent(),
          Value<String?> attachmentKind = const Value.absent(),
          Value<String?> attachmentPath = const Value.absent(),
          Value<int?> attachmentDurationMs = const Value.absent()}) =>
      GroupMessageRow(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        senderId: senderId ?? this.senderId,
        body: body ?? this.body,
        syncStatus: syncStatus ?? this.syncStatus,
        createdAt: createdAt ?? this.createdAt,
        editedAt: editedAt.present ? editedAt.value : this.editedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        blurhash: blurhash.present ? blurhash.value : this.blurhash,
        attachmentKind:
            attachmentKind.present ? attachmentKind.value : this.attachmentKind,
        attachmentPath:
            attachmentPath.present ? attachmentPath.value : this.attachmentPath,
        attachmentDurationMs: attachmentDurationMs.present
            ? attachmentDurationMs.value
            : this.attachmentDurationMs,
      );
  GroupMessageRow copyWithCompanion(GroupMessagesCompanion data) {
    return GroupMessageRow(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      body: data.body.present ? data.body.value : this.body,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      blurhash: data.blurhash.present ? data.blurhash.value : this.blurhash,
      attachmentKind: data.attachmentKind.present
          ? data.attachmentKind.value
          : this.attachmentKind,
      attachmentPath: data.attachmentPath.present
          ? data.attachmentPath.value
          : this.attachmentPath,
      attachmentDurationMs: data.attachmentDurationMs.present
          ? data.attachmentDurationMs.value
          : this.attachmentDurationMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMessageRow(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('senderId: $senderId, ')
          ..write('body: $body, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('blurhash: $blurhash, ')
          ..write('attachmentKind: $attachmentKind, ')
          ..write('attachmentPath: $attachmentPath, ')
          ..write('attachmentDurationMs: $attachmentDurationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      groupId,
      senderId,
      body,
      syncStatus,
      createdAt,
      editedAt,
      deletedAt,
      blurhash,
      attachmentKind,
      attachmentPath,
      attachmentDurationMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMessageRow &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.senderId == this.senderId &&
          other.body == this.body &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.editedAt == this.editedAt &&
          other.deletedAt == this.deletedAt &&
          other.blurhash == this.blurhash &&
          other.attachmentKind == this.attachmentKind &&
          other.attachmentPath == this.attachmentPath &&
          other.attachmentDurationMs == this.attachmentDurationMs);
}

class GroupMessagesCompanion extends UpdateCompanion<GroupMessageRow> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> senderId;
  final Value<String> body;
  final Value<MsgSyncStatus> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime?> editedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> blurhash;
  final Value<String?> attachmentKind;
  final Value<String?> attachmentPath;
  final Value<int?> attachmentDurationMs;
  final Value<int> rowid;
  const GroupMessagesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.body = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.blurhash = const Value.absent(),
    this.attachmentKind = const Value.absent(),
    this.attachmentPath = const Value.absent(),
    this.attachmentDurationMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMessagesCompanion.insert({
    required String id,
    required String groupId,
    required String senderId,
    required String body,
    required MsgSyncStatus syncStatus,
    required DateTime createdAt,
    this.editedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.blurhash = const Value.absent(),
    this.attachmentKind = const Value.absent(),
    this.attachmentPath = const Value.absent(),
    this.attachmentDurationMs = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        senderId = Value(senderId),
        body = Value(body),
        syncStatus = Value(syncStatus),
        createdAt = Value(createdAt);
  static Insertable<GroupMessageRow> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? senderId,
    Expression<String>? body,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? editedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? blurhash,
    Expression<String>? attachmentKind,
    Expression<String>? attachmentPath,
    Expression<int>? attachmentDurationMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (senderId != null) 'sender_id': senderId,
      if (body != null) 'body': body,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (editedAt != null) 'edited_at': editedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (blurhash != null) 'blurhash': blurhash,
      if (attachmentKind != null) 'attachment_kind': attachmentKind,
      if (attachmentPath != null) 'attachment_path': attachmentPath,
      if (attachmentDurationMs != null)
        'attachment_duration_ms': attachmentDurationMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<String>? senderId,
      Value<String>? body,
      Value<MsgSyncStatus>? syncStatus,
      Value<DateTime>? createdAt,
      Value<DateTime?>? editedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? blurhash,
      Value<String?>? attachmentKind,
      Value<String?>? attachmentPath,
      Value<int?>? attachmentDurationMs,
      Value<int>? rowid}) {
    return GroupMessagesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      blurhash: blurhash ?? this.blurhash,
      attachmentKind: attachmentKind ?? this.attachmentKind,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      attachmentDurationMs: attachmentDurationMs ?? this.attachmentDurationMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
          $GroupMessagesTable.$convertersyncStatus.toSql(syncStatus.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<DateTime>(editedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (blurhash.present) {
      map['blurhash'] = Variable<String>(blurhash.value);
    }
    if (attachmentKind.present) {
      map['attachment_kind'] = Variable<String>(attachmentKind.value);
    }
    if (attachmentPath.present) {
      map['attachment_path'] = Variable<String>(attachmentPath.value);
    }
    if (attachmentDurationMs.present) {
      map['attachment_duration_ms'] = Variable<int>(attachmentDurationMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMessagesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('senderId: $senderId, ')
          ..write('body: $body, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('blurhash: $blurhash, ')
          ..write('attachmentKind: $attachmentKind, ')
          ..write('attachmentPath: $attachmentPath, ')
          ..write('attachmentDurationMs: $attachmentDurationMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemberRolesTable extends MemberRoles
    with TableInfo<$MemberRolesTable, MemberRoleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemberRolesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<NexusMemberRole, String> role =
      GeneratedColumn<String>('role', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<NexusMemberRole>($MemberRolesTable.$converterrole);
  @override
  late final GeneratedColumnWithTypeConverter<MemberSyncStatus, String>
      syncStatus = GeneratedColumn<String>('sync_status', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<MemberSyncStatus>(
              $MemberRolesTable.$convertersyncStatus);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [groupId, userId, role, syncStatus, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'member_roles';
  @override
  VerificationContext validateIntegrity(Insertable<MemberRoleRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, userId};
  @override
  MemberRoleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemberRoleRow(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      role: $MemberRolesTable.$converterrole.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!),
      syncStatus: $MemberRolesTable.$convertersyncStatus.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}sync_status'])!),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $MemberRolesTable createAlias(String alias) {
    return $MemberRolesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NexusMemberRole, String, String> $converterrole =
      const EnumNameConverter<NexusMemberRole>(NexusMemberRole.values);
  static JsonTypeConverter2<MemberSyncStatus, String, String>
      $convertersyncStatus =
      const EnumNameConverter<MemberSyncStatus>(MemberSyncStatus.values);
}

class MemberRoleRow extends DataClass implements Insertable<MemberRoleRow> {
  final String groupId;
  final String userId;
  final NexusMemberRole role;

  /// Outbox state for the membership operation that produced this row
  /// (join, leave, role change). Kept on the role row itself — one row
  /// per (group, user) carries both state and its sync status.
  final MemberSyncStatus syncStatus;

  /// When the local user issued the membership operation.
  final DateTime updatedAt;
  const MemberRoleRow(
      {required this.groupId,
      required this.userId,
      required this.role,
      required this.syncStatus,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['user_id'] = Variable<String>(userId);
    {
      map['role'] =
          Variable<String>($MemberRolesTable.$converterrole.toSql(role));
    }
    {
      map['sync_status'] = Variable<String>(
          $MemberRolesTable.$convertersyncStatus.toSql(syncStatus));
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MemberRolesCompanion toCompanion(bool nullToAbsent) {
    return MemberRolesCompanion(
      groupId: Value(groupId),
      userId: Value(userId),
      role: Value(role),
      syncStatus: Value(syncStatus),
      updatedAt: Value(updatedAt),
    );
  }

  factory MemberRoleRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemberRoleRow(
      groupId: serializer.fromJson<String>(json['groupId']),
      userId: serializer.fromJson<String>(json['userId']),
      role: $MemberRolesTable.$converterrole
          .fromJson(serializer.fromJson<String>(json['role'])),
      syncStatus: $MemberRolesTable.$convertersyncStatus
          .fromJson(serializer.fromJson<String>(json['syncStatus'])),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'userId': serializer.toJson<String>(userId),
      'role': serializer
          .toJson<String>($MemberRolesTable.$converterrole.toJson(role)),
      'syncStatus': serializer.toJson<String>(
          $MemberRolesTable.$convertersyncStatus.toJson(syncStatus)),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MemberRoleRow copyWith(
          {String? groupId,
          String? userId,
          NexusMemberRole? role,
          MemberSyncStatus? syncStatus,
          DateTime? updatedAt}) =>
      MemberRoleRow(
        groupId: groupId ?? this.groupId,
        userId: userId ?? this.userId,
        role: role ?? this.role,
        syncStatus: syncStatus ?? this.syncStatus,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  MemberRoleRow copyWithCompanion(MemberRolesCompanion data) {
    return MemberRoleRow(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      userId: data.userId.present ? data.userId.value : this.userId,
      role: data.role.present ? data.role.value : this.role,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemberRoleRow(')
          ..write('groupId: $groupId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, userId, role, syncStatus, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemberRoleRow &&
          other.groupId == this.groupId &&
          other.userId == this.userId &&
          other.role == this.role &&
          other.syncStatus == this.syncStatus &&
          other.updatedAt == this.updatedAt);
}

class MemberRolesCompanion extends UpdateCompanion<MemberRoleRow> {
  final Value<String> groupId;
  final Value<String> userId;
  final Value<NexusMemberRole> role;
  final Value<MemberSyncStatus> syncStatus;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MemberRolesCompanion({
    this.groupId = const Value.absent(),
    this.userId = const Value.absent(),
    this.role = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemberRolesCompanion.insert({
    required String groupId,
    required String userId,
    required NexusMemberRole role,
    required MemberSyncStatus syncStatus,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        userId = Value(userId),
        role = Value(role),
        syncStatus = Value(syncStatus),
        updatedAt = Value(updatedAt);
  static Insertable<MemberRoleRow> custom({
    Expression<String>? groupId,
    Expression<String>? userId,
    Expression<String>? role,
    Expression<String>? syncStatus,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemberRolesCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? userId,
      Value<NexusMemberRole>? role,
      Value<MemberSyncStatus>? syncStatus,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return MemberRolesCompanion(
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (role.present) {
      map['role'] =
          Variable<String>($MemberRolesTable.$converterrole.toSql(role.value));
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
          $MemberRolesTable.$convertersyncStatus.toSql(syncStatus.value));
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemberRolesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageReactionsTable extends MessageReactions
    with TableInfo<$MessageReactionsTable, MessageReactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageReactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetModuleMeta =
      const VerificationMeta('targetModule');
  @override
  late final GeneratedColumn<String> targetModule = GeneratedColumn<String>(
      'target_module', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reactionMeta =
      const VerificationMeta('reaction');
  @override
  late final GeneratedColumn<String> reaction = GeneratedColumn<String>(
      'reaction', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<ReactionSyncStatus, String>
      syncStatus = GeneratedColumn<String>('sync_status', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<ReactionSyncStatus>(
              $MessageReactionsTable.$convertersyncStatus);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, messageId, targetModule, userId, reaction, syncStatus, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_reactions';
  @override
  VerificationContext validateIntegrity(Insertable<MessageReactionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('target_module')) {
      context.handle(
          _targetModuleMeta,
          targetModule.isAcceptableOrUnknown(
              data['target_module']!, _targetModuleMeta));
    } else if (isInserting) {
      context.missing(_targetModuleMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('reaction')) {
      context.handle(_reactionMeta,
          reaction.isAcceptableOrUnknown(data['reaction']!, _reactionMeta));
    } else if (isInserting) {
      context.missing(_reactionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageReactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageReactionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      targetModule: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_module'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      reaction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reaction'])!,
      syncStatus: $MessageReactionsTable.$convertersyncStatus.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}sync_status'])!),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MessageReactionsTable createAlias(String alias) {
    return $MessageReactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReactionSyncStatus, String, String>
      $convertersyncStatus =
      const EnumNameConverter<ReactionSyncStatus>(ReactionSyncStatus.values);
}

class MessageReactionRow extends DataClass
    implements Insertable<MessageReactionRow> {
  final String id;

  /// Target message: a Vault message or a Nexus group message.
  final String messageId;

  /// Which module owns the target (vault | nexus_group) so the sync
  /// layer can route the row without reverse-engineering ids.
  final String targetModule;
  final String userId;

  /// Emoji shortcode ('heart', 'laugh', ...) — presentation maps to glyph.
  final String reaction;
  final ReactionSyncStatus syncStatus;
  final DateTime createdAt;
  const MessageReactionRow(
      {required this.id,
      required this.messageId,
      required this.targetModule,
      required this.userId,
      required this.reaction,
      required this.syncStatus,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['message_id'] = Variable<String>(messageId);
    map['target_module'] = Variable<String>(targetModule);
    map['user_id'] = Variable<String>(userId);
    map['reaction'] = Variable<String>(reaction);
    {
      map['sync_status'] = Variable<String>(
          $MessageReactionsTable.$convertersyncStatus.toSql(syncStatus));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessageReactionsCompanion toCompanion(bool nullToAbsent) {
    return MessageReactionsCompanion(
      id: Value(id),
      messageId: Value(messageId),
      targetModule: Value(targetModule),
      userId: Value(userId),
      reaction: Value(reaction),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
    );
  }

  factory MessageReactionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageReactionRow(
      id: serializer.fromJson<String>(json['id']),
      messageId: serializer.fromJson<String>(json['messageId']),
      targetModule: serializer.fromJson<String>(json['targetModule']),
      userId: serializer.fromJson<String>(json['userId']),
      reaction: serializer.fromJson<String>(json['reaction']),
      syncStatus: $MessageReactionsTable.$convertersyncStatus
          .fromJson(serializer.fromJson<String>(json['syncStatus'])),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'messageId': serializer.toJson<String>(messageId),
      'targetModule': serializer.toJson<String>(targetModule),
      'userId': serializer.toJson<String>(userId),
      'reaction': serializer.toJson<String>(reaction),
      'syncStatus': serializer.toJson<String>(
          $MessageReactionsTable.$convertersyncStatus.toJson(syncStatus)),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MessageReactionRow copyWith(
          {String? id,
          String? messageId,
          String? targetModule,
          String? userId,
          String? reaction,
          ReactionSyncStatus? syncStatus,
          DateTime? createdAt}) =>
      MessageReactionRow(
        id: id ?? this.id,
        messageId: messageId ?? this.messageId,
        targetModule: targetModule ?? this.targetModule,
        userId: userId ?? this.userId,
        reaction: reaction ?? this.reaction,
        syncStatus: syncStatus ?? this.syncStatus,
        createdAt: createdAt ?? this.createdAt,
      );
  MessageReactionRow copyWithCompanion(MessageReactionsCompanion data) {
    return MessageReactionRow(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      targetModule: data.targetModule.present
          ? data.targetModule.value
          : this.targetModule,
      userId: data.userId.present ? data.userId.value : this.userId,
      reaction: data.reaction.present ? data.reaction.value : this.reaction,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageReactionRow(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('targetModule: $targetModule, ')
          ..write('userId: $userId, ')
          ..write('reaction: $reaction, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, messageId, targetModule, userId, reaction, syncStatus, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageReactionRow &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.targetModule == this.targetModule &&
          other.userId == this.userId &&
          other.reaction == this.reaction &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt);
}

class MessageReactionsCompanion extends UpdateCompanion<MessageReactionRow> {
  final Value<String> id;
  final Value<String> messageId;
  final Value<String> targetModule;
  final Value<String> userId;
  final Value<String> reaction;
  final Value<ReactionSyncStatus> syncStatus;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MessageReactionsCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.targetModule = const Value.absent(),
    this.userId = const Value.absent(),
    this.reaction = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageReactionsCompanion.insert({
    required String id,
    required String messageId,
    required String targetModule,
    required String userId,
    required String reaction,
    required ReactionSyncStatus syncStatus,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        messageId = Value(messageId),
        targetModule = Value(targetModule),
        userId = Value(userId),
        reaction = Value(reaction),
        syncStatus = Value(syncStatus),
        createdAt = Value(createdAt);
  static Insertable<MessageReactionRow> custom({
    Expression<String>? id,
    Expression<String>? messageId,
    Expression<String>? targetModule,
    Expression<String>? userId,
    Expression<String>? reaction,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (targetModule != null) 'target_module': targetModule,
      if (userId != null) 'user_id': userId,
      if (reaction != null) 'reaction': reaction,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageReactionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? messageId,
      Value<String>? targetModule,
      Value<String>? userId,
      Value<String>? reaction,
      Value<ReactionSyncStatus>? syncStatus,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return MessageReactionsCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      targetModule: targetModule ?? this.targetModule,
      userId: userId ?? this.userId,
      reaction: reaction ?? this.reaction,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (targetModule.present) {
      map['target_module'] = Variable<String>(targetModule.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (reaction.present) {
      map['reaction'] = Variable<String>(reaction.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
          $MessageReactionsTable.$convertersyncStatus.toSql(syncStatus.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageReactionsCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('targetModule: $targetModule, ')
          ..write('userId: $userId, ')
          ..write('reaction: $reaction, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadCursorsTable extends ReadCursors
    with TableInfo<$ReadCursorsTable, ReadCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastReadMessageIdMeta =
      const VerificationMeta('lastReadMessageId');
  @override
  late final GeneratedColumn<String> lastReadMessageId =
      GeneratedColumn<String>('last_read_message_id', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastReadAtMeta =
      const VerificationMeta('lastReadAt');
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
      'last_read_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [conversationId, userId, lastReadMessageId, lastReadAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'read_cursors';
  @override
  VerificationContext validateIntegrity(Insertable<ReadCursorRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('last_read_message_id')) {
      context.handle(
          _lastReadMessageIdMeta,
          lastReadMessageId.isAcceptableOrUnknown(
              data['last_read_message_id']!, _lastReadMessageIdMeta));
    } else if (isInserting) {
      context.missing(_lastReadMessageIdMeta);
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
          _lastReadAtMeta,
          lastReadAt.isAcceptableOrUnknown(
              data['last_read_at']!, _lastReadAtMeta));
    } else if (isInserting) {
      context.missing(_lastReadAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId, userId};
  @override
  ReadCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadCursorRow(
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      lastReadMessageId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_read_message_id'])!,
      lastReadAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_read_at'])!,
    );
  }

  @override
  $ReadCursorsTable createAlias(String alias) {
    return $ReadCursorsTable(attachedDatabase, alias);
  }
}

class ReadCursorRow extends DataClass implements Insertable<ReadCursorRow> {
  final String conversationId;
  final String userId;
  final String lastReadMessageId;
  final DateTime lastReadAt;
  const ReadCursorRow(
      {required this.conversationId,
      required this.userId,
      required this.lastReadMessageId,
      required this.lastReadAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['user_id'] = Variable<String>(userId);
    map['last_read_message_id'] = Variable<String>(lastReadMessageId);
    map['last_read_at'] = Variable<DateTime>(lastReadAt);
    return map;
  }

  ReadCursorsCompanion toCompanion(bool nullToAbsent) {
    return ReadCursorsCompanion(
      conversationId: Value(conversationId),
      userId: Value(userId),
      lastReadMessageId: Value(lastReadMessageId),
      lastReadAt: Value(lastReadAt),
    );
  }

  factory ReadCursorRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadCursorRow(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      userId: serializer.fromJson<String>(json['userId']),
      lastReadMessageId: serializer.fromJson<String>(json['lastReadMessageId']),
      lastReadAt: serializer.fromJson<DateTime>(json['lastReadAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'userId': serializer.toJson<String>(userId),
      'lastReadMessageId': serializer.toJson<String>(lastReadMessageId),
      'lastReadAt': serializer.toJson<DateTime>(lastReadAt),
    };
  }

  ReadCursorRow copyWith(
          {String? conversationId,
          String? userId,
          String? lastReadMessageId,
          DateTime? lastReadAt}) =>
      ReadCursorRow(
        conversationId: conversationId ?? this.conversationId,
        userId: userId ?? this.userId,
        lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
        lastReadAt: lastReadAt ?? this.lastReadAt,
      );
  ReadCursorRow copyWithCompanion(ReadCursorsCompanion data) {
    return ReadCursorRow(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      userId: data.userId.present ? data.userId.value : this.userId,
      lastReadMessageId: data.lastReadMessageId.present
          ? data.lastReadMessageId.value
          : this.lastReadMessageId,
      lastReadAt:
          data.lastReadAt.present ? data.lastReadAt.value : this.lastReadAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadCursorRow(')
          ..write('conversationId: $conversationId, ')
          ..write('userId: $userId, ')
          ..write('lastReadMessageId: $lastReadMessageId, ')
          ..write('lastReadAt: $lastReadAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(conversationId, userId, lastReadMessageId, lastReadAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadCursorRow &&
          other.conversationId == this.conversationId &&
          other.userId == this.userId &&
          other.lastReadMessageId == this.lastReadMessageId &&
          other.lastReadAt == this.lastReadAt);
}

class ReadCursorsCompanion extends UpdateCompanion<ReadCursorRow> {
  final Value<String> conversationId;
  final Value<String> userId;
  final Value<String> lastReadMessageId;
  final Value<DateTime> lastReadAt;
  final Value<int> rowid;
  const ReadCursorsCompanion({
    this.conversationId = const Value.absent(),
    this.userId = const Value.absent(),
    this.lastReadMessageId = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadCursorsCompanion.insert({
    required String conversationId,
    required String userId,
    required String lastReadMessageId,
    required DateTime lastReadAt,
    this.rowid = const Value.absent(),
  })  : conversationId = Value(conversationId),
        userId = Value(userId),
        lastReadMessageId = Value(lastReadMessageId),
        lastReadAt = Value(lastReadAt);
  static Insertable<ReadCursorRow> custom({
    Expression<String>? conversationId,
    Expression<String>? userId,
    Expression<String>? lastReadMessageId,
    Expression<DateTime>? lastReadAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (userId != null) 'user_id': userId,
      if (lastReadMessageId != null) 'last_read_message_id': lastReadMessageId,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadCursorsCompanion copyWith(
      {Value<String>? conversationId,
      Value<String>? userId,
      Value<String>? lastReadMessageId,
      Value<DateTime>? lastReadAt,
      Value<int>? rowid}) {
    return ReadCursorsCompanion(
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (lastReadMessageId.present) {
      map['last_read_message_id'] = Variable<String>(lastReadMessageId.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadCursorsCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('userId: $userId, ')
          ..write('lastReadMessageId: $lastReadMessageId, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PromptsTable extends Prompts with TableInfo<$PromptsTable, PromptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PromptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shapeMeta = const VerificationMeta('shape');
  @override
  late final GeneratedColumn<String> shape = GeneratedColumn<String>(
      'shape', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rotationIndexMeta =
      const VerificationMeta('rotationIndex');
  @override
  late final GeneratedColumn<int> rotationIndex = GeneratedColumn<int>(
      'rotation_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, shape, body, rotationIndex, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prompts';
  @override
  VerificationContext validateIntegrity(Insertable<PromptRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shape')) {
      context.handle(
          _shapeMeta, shape.isAcceptableOrUnknown(data['shape']!, _shapeMeta));
    } else if (isInserting) {
      context.missing(_shapeMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('rotation_index')) {
      context.handle(
          _rotationIndexMeta,
          rotationIndex.isAcceptableOrUnknown(
              data['rotation_index']!, _rotationIndexMeta));
    } else if (isInserting) {
      context.missing(_rotationIndexMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PromptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PromptRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shape: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shape'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      rotationIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rotation_index'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PromptsTable createAlias(String alias) {
    return $PromptsTable(attachedDatabase, alias);
  }
}

class PromptRow extends DataClass implements Insertable<PromptRow> {
  final String id;

  /// Which shape of ask this is: photo | sentence | sound | desk ...
  final String shape;

  /// The prompt's copy ('Show your desk right now.'). Named [body] —
  /// `text` collides with drift's column-builder method.
  final String body;

  /// Order in the rotation; the active prompt is the next unposted one.
  final int rotationIndex;
  final DateTime createdAt;
  const PromptRow(
      {required this.id,
      required this.shape,
      required this.body,
      required this.rotationIndex,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['shape'] = Variable<String>(shape);
    map['body'] = Variable<String>(body);
    map['rotation_index'] = Variable<int>(rotationIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PromptsCompanion toCompanion(bool nullToAbsent) {
    return PromptsCompanion(
      id: Value(id),
      shape: Value(shape),
      body: Value(body),
      rotationIndex: Value(rotationIndex),
      createdAt: Value(createdAt),
    );
  }

  factory PromptRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PromptRow(
      id: serializer.fromJson<String>(json['id']),
      shape: serializer.fromJson<String>(json['shape']),
      body: serializer.fromJson<String>(json['body']),
      rotationIndex: serializer.fromJson<int>(json['rotationIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shape': serializer.toJson<String>(shape),
      'body': serializer.toJson<String>(body),
      'rotationIndex': serializer.toJson<int>(rotationIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PromptRow copyWith(
          {String? id,
          String? shape,
          String? body,
          int? rotationIndex,
          DateTime? createdAt}) =>
      PromptRow(
        id: id ?? this.id,
        shape: shape ?? this.shape,
        body: body ?? this.body,
        rotationIndex: rotationIndex ?? this.rotationIndex,
        createdAt: createdAt ?? this.createdAt,
      );
  PromptRow copyWithCompanion(PromptsCompanion data) {
    return PromptRow(
      id: data.id.present ? data.id.value : this.id,
      shape: data.shape.present ? data.shape.value : this.shape,
      body: data.body.present ? data.body.value : this.body,
      rotationIndex: data.rotationIndex.present
          ? data.rotationIndex.value
          : this.rotationIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PromptRow(')
          ..write('id: $id, ')
          ..write('shape: $shape, ')
          ..write('body: $body, ')
          ..write('rotationIndex: $rotationIndex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, shape, body, rotationIndex, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptRow &&
          other.id == this.id &&
          other.shape == this.shape &&
          other.body == this.body &&
          other.rotationIndex == this.rotationIndex &&
          other.createdAt == this.createdAt);
}

class PromptsCompanion extends UpdateCompanion<PromptRow> {
  final Value<String> id;
  final Value<String> shape;
  final Value<String> body;
  final Value<int> rotationIndex;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PromptsCompanion({
    this.id = const Value.absent(),
    this.shape = const Value.absent(),
    this.body = const Value.absent(),
    this.rotationIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PromptsCompanion.insert({
    required String id,
    required String shape,
    required String body,
    required int rotationIndex,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shape = Value(shape),
        body = Value(body),
        rotationIndex = Value(rotationIndex),
        createdAt = Value(createdAt);
  static Insertable<PromptRow> custom({
    Expression<String>? id,
    Expression<String>? shape,
    Expression<String>? body,
    Expression<int>? rotationIndex,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shape != null) 'shape': shape,
      if (body != null) 'body': body,
      if (rotationIndex != null) 'rotation_index': rotationIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PromptsCompanion copyWith(
      {Value<String>? id,
      Value<String>? shape,
      Value<String>? body,
      Value<int>? rotationIndex,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return PromptsCompanion(
      id: id ?? this.id,
      shape: shape ?? this.shape,
      body: body ?? this.body,
      rotationIndex: rotationIndex ?? this.rotationIndex,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shape.present) {
      map['shape'] = Variable<String>(shape.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (rotationIndex.present) {
      map['rotation_index'] = Variable<int>(rotationIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PromptsCompanion(')
          ..write('id: $id, ')
          ..write('shape: $shape, ')
          ..write('body: $body, ')
          ..write('rotationIndex: $rotationIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PromptPrefsTable extends PromptPrefs
    with TableInfo<$PromptPrefsTable, PromptPrefsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PromptPrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _windowHourMeta =
      const VerificationMeta('windowHour');
  @override
  late final GeneratedColumn<int> windowHour = GeneratedColumn<int>(
      'window_hour', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _optedInMeta =
      const VerificationMeta('optedIn');
  @override
  late final GeneratedColumn<bool> optedIn = GeneratedColumn<bool>(
      'opted_in', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("opted_in" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _pausedUntilMeta =
      const VerificationMeta('pausedUntil');
  @override
  late final GeneratedColumn<DateTime> pausedUntil = GeneratedColumn<DateTime>(
      'paused_until', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [userId, windowHour, optedIn, pausedUntil];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prompt_prefs';
  @override
  VerificationContext validateIntegrity(Insertable<PromptPrefsRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('window_hour')) {
      context.handle(
          _windowHourMeta,
          windowHour.isAcceptableOrUnknown(
              data['window_hour']!, _windowHourMeta));
    } else if (isInserting) {
      context.missing(_windowHourMeta);
    }
    if (data.containsKey('opted_in')) {
      context.handle(_optedInMeta,
          optedIn.isAcceptableOrUnknown(data['opted_in']!, _optedInMeta));
    }
    if (data.containsKey('paused_until')) {
      context.handle(
          _pausedUntilMeta,
          pausedUntil.isAcceptableOrUnknown(
              data['paused_until']!, _pausedUntilMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  PromptPrefsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PromptPrefsRow(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      windowHour: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}window_hour'])!,
      optedIn: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}opted_in'])!,
      pausedUntil: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}paused_until']),
    );
  }

  @override
  $PromptPrefsTable createAlias(String alias) {
    return $PromptPrefsTable(attachedDatabase, alias);
  }
}

class PromptPrefsRow extends DataClass implements Insertable<PromptPrefsRow> {
  final String userId;

  /// Hour of day the user's window opens (0-23). User-picked — never
  /// a random interrupt (§6c rule 1).
  final int windowHour;

  /// Opt-in flag and pause: false or paused = no prompt fires (§6c rule 5).
  final bool optedIn;
  final DateTime? pausedUntil;
  const PromptPrefsRow(
      {required this.userId,
      required this.windowHour,
      required this.optedIn,
      this.pausedUntil});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['window_hour'] = Variable<int>(windowHour);
    map['opted_in'] = Variable<bool>(optedIn);
    if (!nullToAbsent || pausedUntil != null) {
      map['paused_until'] = Variable<DateTime>(pausedUntil);
    }
    return map;
  }

  PromptPrefsCompanion toCompanion(bool nullToAbsent) {
    return PromptPrefsCompanion(
      userId: Value(userId),
      windowHour: Value(windowHour),
      optedIn: Value(optedIn),
      pausedUntil: pausedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedUntil),
    );
  }

  factory PromptPrefsRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PromptPrefsRow(
      userId: serializer.fromJson<String>(json['userId']),
      windowHour: serializer.fromJson<int>(json['windowHour']),
      optedIn: serializer.fromJson<bool>(json['optedIn']),
      pausedUntil: serializer.fromJson<DateTime?>(json['pausedUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'windowHour': serializer.toJson<int>(windowHour),
      'optedIn': serializer.toJson<bool>(optedIn),
      'pausedUntil': serializer.toJson<DateTime?>(pausedUntil),
    };
  }

  PromptPrefsRow copyWith(
          {String? userId,
          int? windowHour,
          bool? optedIn,
          Value<DateTime?> pausedUntil = const Value.absent()}) =>
      PromptPrefsRow(
        userId: userId ?? this.userId,
        windowHour: windowHour ?? this.windowHour,
        optedIn: optedIn ?? this.optedIn,
        pausedUntil: pausedUntil.present ? pausedUntil.value : this.pausedUntil,
      );
  PromptPrefsRow copyWithCompanion(PromptPrefsCompanion data) {
    return PromptPrefsRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      windowHour:
          data.windowHour.present ? data.windowHour.value : this.windowHour,
      optedIn: data.optedIn.present ? data.optedIn.value : this.optedIn,
      pausedUntil:
          data.pausedUntil.present ? data.pausedUntil.value : this.pausedUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PromptPrefsRow(')
          ..write('userId: $userId, ')
          ..write('windowHour: $windowHour, ')
          ..write('optedIn: $optedIn, ')
          ..write('pausedUntil: $pausedUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, windowHour, optedIn, pausedUntil);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptPrefsRow &&
          other.userId == this.userId &&
          other.windowHour == this.windowHour &&
          other.optedIn == this.optedIn &&
          other.pausedUntil == this.pausedUntil);
}

class PromptPrefsCompanion extends UpdateCompanion<PromptPrefsRow> {
  final Value<String> userId;
  final Value<int> windowHour;
  final Value<bool> optedIn;
  final Value<DateTime?> pausedUntil;
  final Value<int> rowid;
  const PromptPrefsCompanion({
    this.userId = const Value.absent(),
    this.windowHour = const Value.absent(),
    this.optedIn = const Value.absent(),
    this.pausedUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PromptPrefsCompanion.insert({
    required String userId,
    required int windowHour,
    this.optedIn = const Value.absent(),
    this.pausedUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        windowHour = Value(windowHour);
  static Insertable<PromptPrefsRow> custom({
    Expression<String>? userId,
    Expression<int>? windowHour,
    Expression<bool>? optedIn,
    Expression<DateTime>? pausedUntil,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (windowHour != null) 'window_hour': windowHour,
      if (optedIn != null) 'opted_in': optedIn,
      if (pausedUntil != null) 'paused_until': pausedUntil,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PromptPrefsCompanion copyWith(
      {Value<String>? userId,
      Value<int>? windowHour,
      Value<bool>? optedIn,
      Value<DateTime?>? pausedUntil,
      Value<int>? rowid}) {
    return PromptPrefsCompanion(
      userId: userId ?? this.userId,
      windowHour: windowHour ?? this.windowHour,
      optedIn: optedIn ?? this.optedIn,
      pausedUntil: pausedUntil ?? this.pausedUntil,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (windowHour.present) {
      map['window_hour'] = Variable<int>(windowHour.value);
    }
    if (optedIn.present) {
      map['opted_in'] = Variable<bool>(optedIn.value);
    }
    if (pausedUntil.present) {
      map['paused_until'] = Variable<DateTime>(pausedUntil.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PromptPrefsCompanion(')
          ..write('userId: $userId, ')
          ..write('windowHour: $windowHour, ')
          ..write('optedIn: $optedIn, ')
          ..write('pausedUntil: $pausedUntil, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PromptActionsTable extends PromptActions
    with TableInfo<$PromptActionsTable, PromptActionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PromptActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _promptIdMeta =
      const VerificationMeta('promptId');
  @override
  late final GeneratedColumn<String> promptId = GeneratedColumn<String>(
      'prompt_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actedAtMeta =
      const VerificationMeta('actedAt');
  @override
  late final GeneratedColumn<DateTime> actedAt = GeneratedColumn<DateTime>(
      'acted_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [promptId, userId, action, actedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prompt_actions';
  @override
  VerificationContext validateIntegrity(Insertable<PromptActionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('prompt_id')) {
      context.handle(_promptIdMeta,
          promptId.isAcceptableOrUnknown(data['prompt_id']!, _promptIdMeta));
    } else if (isInserting) {
      context.missing(_promptIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('acted_at')) {
      context.handle(_actedAtMeta,
          actedAt.isAcceptableOrUnknown(data['acted_at']!, _actedAtMeta));
    } else if (isInserting) {
      context.missing(_actedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {promptId, userId};
  @override
  PromptActionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PromptActionRow(
      promptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prompt_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      actedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}acted_at'])!,
    );
  }

  @override
  $PromptActionsTable createAlias(String alias) {
    return $PromptActionsTable(attachedDatabase, alias);
  }
}

class PromptActionRow extends DataClass implements Insertable<PromptActionRow> {
  final String promptId;
  final String userId;
  final String action;
  final DateTime actedAt;
  const PromptActionRow(
      {required this.promptId,
      required this.userId,
      required this.action,
      required this.actedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['prompt_id'] = Variable<String>(promptId);
    map['user_id'] = Variable<String>(userId);
    map['action'] = Variable<String>(action);
    map['acted_at'] = Variable<DateTime>(actedAt);
    return map;
  }

  PromptActionsCompanion toCompanion(bool nullToAbsent) {
    return PromptActionsCompanion(
      promptId: Value(promptId),
      userId: Value(userId),
      action: Value(action),
      actedAt: Value(actedAt),
    );
  }

  factory PromptActionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PromptActionRow(
      promptId: serializer.fromJson<String>(json['promptId']),
      userId: serializer.fromJson<String>(json['userId']),
      action: serializer.fromJson<String>(json['action']),
      actedAt: serializer.fromJson<DateTime>(json['actedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'promptId': serializer.toJson<String>(promptId),
      'userId': serializer.toJson<String>(userId),
      'action': serializer.toJson<String>(action),
      'actedAt': serializer.toJson<DateTime>(actedAt),
    };
  }

  PromptActionRow copyWith(
          {String? promptId,
          String? userId,
          String? action,
          DateTime? actedAt}) =>
      PromptActionRow(
        promptId: promptId ?? this.promptId,
        userId: userId ?? this.userId,
        action: action ?? this.action,
        actedAt: actedAt ?? this.actedAt,
      );
  PromptActionRow copyWithCompanion(PromptActionsCompanion data) {
    return PromptActionRow(
      promptId: data.promptId.present ? data.promptId.value : this.promptId,
      userId: data.userId.present ? data.userId.value : this.userId,
      action: data.action.present ? data.action.value : this.action,
      actedAt: data.actedAt.present ? data.actedAt.value : this.actedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PromptActionRow(')
          ..write('promptId: $promptId, ')
          ..write('userId: $userId, ')
          ..write('action: $action, ')
          ..write('actedAt: $actedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(promptId, userId, action, actedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptActionRow &&
          other.promptId == this.promptId &&
          other.userId == this.userId &&
          other.action == this.action &&
          other.actedAt == this.actedAt);
}

class PromptActionsCompanion extends UpdateCompanion<PromptActionRow> {
  final Value<String> promptId;
  final Value<String> userId;
  final Value<String> action;
  final Value<DateTime> actedAt;
  final Value<int> rowid;
  const PromptActionsCompanion({
    this.promptId = const Value.absent(),
    this.userId = const Value.absent(),
    this.action = const Value.absent(),
    this.actedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PromptActionsCompanion.insert({
    required String promptId,
    required String userId,
    required String action,
    required DateTime actedAt,
    this.rowid = const Value.absent(),
  })  : promptId = Value(promptId),
        userId = Value(userId),
        action = Value(action),
        actedAt = Value(actedAt);
  static Insertable<PromptActionRow> custom({
    Expression<String>? promptId,
    Expression<String>? userId,
    Expression<String>? action,
    Expression<DateTime>? actedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (promptId != null) 'prompt_id': promptId,
      if (userId != null) 'user_id': userId,
      if (action != null) 'action': action,
      if (actedAt != null) 'acted_at': actedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PromptActionsCompanion copyWith(
      {Value<String>? promptId,
      Value<String>? userId,
      Value<String>? action,
      Value<DateTime>? actedAt,
      Value<int>? rowid}) {
    return PromptActionsCompanion(
      promptId: promptId ?? this.promptId,
      userId: userId ?? this.userId,
      action: action ?? this.action,
      actedAt: actedAt ?? this.actedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (promptId.present) {
      map['prompt_id'] = Variable<String>(promptId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (actedAt.present) {
      map['acted_at'] = Variable<DateTime>(actedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PromptActionsCompanion(')
          ..write('promptId: $promptId, ')
          ..write('userId: $userId, ')
          ..write('action: $action, ')
          ..write('actedAt: $actedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<SettingRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory SettingRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) => SettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PostsTable posts = $PostsTable(this);
  late final $PostLikesTable postLikes = $PostLikesTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $NexusChannelsTable nexusChannels = $NexusChannelsTable(this);
  late final $ChannelPostsTable channelPosts = $ChannelPostsTable(this);
  late final $NexusGroupsTable nexusGroups = $NexusGroupsTable(this);
  late final $GroupMessagesTable groupMessages = $GroupMessagesTable(this);
  late final $MemberRolesTable memberRoles = $MemberRolesTable(this);
  late final $MessageReactionsTable messageReactions =
      $MessageReactionsTable(this);
  late final $ReadCursorsTable readCursors = $ReadCursorsTable(this);
  late final $PromptsTable prompts = $PromptsTable(this);
  late final $PromptPrefsTable promptPrefs = $PromptPrefsTable(this);
  late final $PromptActionsTable promptActions = $PromptActionsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        posts,
        postLikes,
        conversations,
        messages,
        nexusChannels,
        channelPosts,
        nexusGroups,
        groupMessages,
        memberRoles,
        messageReactions,
        readCursors,
        prompts,
        promptPrefs,
        promptActions,
        settings
      ];
}

typedef $$PostsTableCreateCompanionBuilder = PostsCompanion Function({
  required String id,
  required String authorId,
  required String authorName,
  required String body,
  Value<String?> mediaUrl,
  Value<String?> blurhash,
  required DateTime createdAt,
  Value<DateTime?> deletedAt,
  Value<DateTime?> expiresAt,
  Value<int> rowid,
});
typedef $$PostsTableUpdateCompanionBuilder = PostsCompanion Function({
  Value<String> id,
  Value<String> authorId,
  Value<String> authorName,
  Value<String> body,
  Value<String?> mediaUrl,
  Value<String?> blurhash,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<DateTime?> expiresAt,
  Value<int> rowid,
});

class $$PostsTableFilterComposer extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authorId => $composableBuilder(
      column: $table.authorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaUrl => $composableBuilder(
      column: $table.mediaUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get blurhash => $composableBuilder(
      column: $table.blurhash, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));
}

class $$PostsTableOrderingComposer
    extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authorId => $composableBuilder(
      column: $table.authorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaUrl => $composableBuilder(
      column: $table.mediaUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get blurhash => $composableBuilder(
      column: $table.blurhash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));
}

class $$PostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get mediaUrl =>
      $composableBuilder(column: $table.mediaUrl, builder: (column) => column);

  GeneratedColumn<String> get blurhash =>
      $composableBuilder(column: $table.blurhash, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$PostsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PostsTable,
    PostRow,
    $$PostsTableFilterComposer,
    $$PostsTableOrderingComposer,
    $$PostsTableAnnotationComposer,
    $$PostsTableCreateCompanionBuilder,
    $$PostsTableUpdateCompanionBuilder,
    (PostRow, BaseReferences<_$AppDatabase, $PostsTable, PostRow>),
    PostRow,
    PrefetchHooks Function()> {
  $$PostsTableTableManager(_$AppDatabase db, $PostsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> authorId = const Value.absent(),
            Value<String> authorName = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String?> mediaUrl = const Value.absent(),
            Value<String?> blurhash = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PostsCompanion(
            id: id,
            authorId: authorId,
            authorName: authorName,
            body: body,
            mediaUrl: mediaUrl,
            blurhash: blurhash,
            createdAt: createdAt,
            deletedAt: deletedAt,
            expiresAt: expiresAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String authorId,
            required String authorName,
            required String body,
            Value<String?> mediaUrl = const Value.absent(),
            Value<String?> blurhash = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PostsCompanion.insert(
            id: id,
            authorId: authorId,
            authorName: authorName,
            body: body,
            mediaUrl: mediaUrl,
            blurhash: blurhash,
            createdAt: createdAt,
            deletedAt: deletedAt,
            expiresAt: expiresAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PostsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PostsTable,
    PostRow,
    $$PostsTableFilterComposer,
    $$PostsTableOrderingComposer,
    $$PostsTableAnnotationComposer,
    $$PostsTableCreateCompanionBuilder,
    $$PostsTableUpdateCompanionBuilder,
    (PostRow, BaseReferences<_$AppDatabase, $PostsTable, PostRow>),
    PostRow,
    PrefetchHooks Function()>;
typedef $$PostLikesTableCreateCompanionBuilder = PostLikesCompanion Function({
  required String postId,
  required String userId,
  required DateTime likedAt,
  Value<int> rowid,
});
typedef $$PostLikesTableUpdateCompanionBuilder = PostLikesCompanion Function({
  Value<String> postId,
  Value<String> userId,
  Value<DateTime> likedAt,
  Value<int> rowid,
});

class $$PostLikesTableFilterComposer
    extends Composer<_$AppDatabase, $PostLikesTable> {
  $$PostLikesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get postId => $composableBuilder(
      column: $table.postId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get likedAt => $composableBuilder(
      column: $table.likedAt, builder: (column) => ColumnFilters(column));
}

class $$PostLikesTableOrderingComposer
    extends Composer<_$AppDatabase, $PostLikesTable> {
  $$PostLikesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get postId => $composableBuilder(
      column: $table.postId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get likedAt => $composableBuilder(
      column: $table.likedAt, builder: (column) => ColumnOrderings(column));
}

class $$PostLikesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PostLikesTable> {
  $$PostLikesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get postId =>
      $composableBuilder(column: $table.postId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get likedAt =>
      $composableBuilder(column: $table.likedAt, builder: (column) => column);
}

class $$PostLikesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PostLikesTable,
    PostLikeRow,
    $$PostLikesTableFilterComposer,
    $$PostLikesTableOrderingComposer,
    $$PostLikesTableAnnotationComposer,
    $$PostLikesTableCreateCompanionBuilder,
    $$PostLikesTableUpdateCompanionBuilder,
    (PostLikeRow, BaseReferences<_$AppDatabase, $PostLikesTable, PostLikeRow>),
    PostLikeRow,
    PrefetchHooks Function()> {
  $$PostLikesTableTableManager(_$AppDatabase db, $PostLikesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PostLikesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PostLikesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PostLikesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> postId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<DateTime> likedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PostLikesCompanion(
            postId: postId,
            userId: userId,
            likedAt: likedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String postId,
            required String userId,
            required DateTime likedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PostLikesCompanion.insert(
            postId: postId,
            userId: userId,
            likedAt: likedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PostLikesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PostLikesTable,
    PostLikeRow,
    $$PostLikesTableFilterComposer,
    $$PostLikesTableOrderingComposer,
    $$PostLikesTableAnnotationComposer,
    $$PostLikesTableCreateCompanionBuilder,
    $$PostLikesTableUpdateCompanionBuilder,
    (PostLikeRow, BaseReferences<_$AppDatabase, $PostLikesTable, PostLikeRow>),
    PostLikeRow,
    PrefetchHooks Function()>;
typedef $$ConversationsTableCreateCompanionBuilder = ConversationsCompanion
    Function({
  required String id,
  required String title,
  required String participantIds,
  required DateTime lastActivityAt,
  Value<int> rowid,
});
typedef $$ConversationsTableUpdateCompanionBuilder = ConversationsCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> participantIds,
  Value<DateTime> lastActivityAt,
  Value<int> rowid,
});

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get participantIds => $composableBuilder(
      column: $table.participantIds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastActivityAt => $composableBuilder(
      column: $table.lastActivityAt,
      builder: (column) => ColumnFilters(column));
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get participantIds => $composableBuilder(
      column: $table.participantIds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastActivityAt => $composableBuilder(
      column: $table.lastActivityAt,
      builder: (column) => ColumnOrderings(column));
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get participantIds => $composableBuilder(
      column: $table.participantIds, builder: (column) => column);

  GeneratedColumn<DateTime> get lastActivityAt => $composableBuilder(
      column: $table.lastActivityAt, builder: (column) => column);
}

class $$ConversationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConversationsTable,
    ConversationRow,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      ConversationRow,
      BaseReferences<_$AppDatabase, $ConversationsTable, ConversationRow>
    ),
    ConversationRow,
    PrefetchHooks Function()> {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> participantIds = const Value.absent(),
            Value<DateTime> lastActivityAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationsCompanion(
            id: id,
            title: title,
            participantIds: participantIds,
            lastActivityAt: lastActivityAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String participantIds,
            required DateTime lastActivityAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationsCompanion.insert(
            id: id,
            title: title,
            participantIds: participantIds,
            lastActivityAt: lastActivityAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConversationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConversationsTable,
    ConversationRow,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      ConversationRow,
      BaseReferences<_$AppDatabase, $ConversationsTable, ConversationRow>
    ),
    ConversationRow,
    PrefetchHooks Function()>;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String id,
  required String conversationId,
  required String senderId,
  required String body,
  Value<String?> ciphertext,
  required MsgSyncStatus syncStatus,
  required DateTime createdAt,
  Value<DateTime?> editedAt,
  Value<DateTime?> deletedAt,
  Value<String?> attachmentKind,
  Value<String?> attachmentPath,
  Value<int?> attachmentDurationMs,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> id,
  Value<String> conversationId,
  Value<String> senderId,
  Value<String> body,
  Value<String?> ciphertext,
  Value<MsgSyncStatus> syncStatus,
  Value<DateTime> createdAt,
  Value<DateTime?> editedAt,
  Value<DateTime?> deletedAt,
  Value<String?> attachmentKind,
  Value<String?> attachmentPath,
  Value<int?> attachmentDurationMs,
  Value<int> rowid,
});

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ciphertext => $composableBuilder(
      column: $table.ciphertext, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<MsgSyncStatus, MsgSyncStatus, String>
      get syncStatus => $composableBuilder(
          column: $table.syncStatus,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get editedAt => $composableBuilder(
      column: $table.editedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentKind => $composableBuilder(
      column: $table.attachmentKind,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentPath => $composableBuilder(
      column: $table.attachmentPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attachmentDurationMs => $composableBuilder(
      column: $table.attachmentDurationMs,
      builder: (column) => ColumnFilters(column));
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ciphertext => $composableBuilder(
      column: $table.ciphertext, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get editedAt => $composableBuilder(
      column: $table.editedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentKind => $composableBuilder(
      column: $table.attachmentKind,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentPath => $composableBuilder(
      column: $table.attachmentPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attachmentDurationMs => $composableBuilder(
      column: $table.attachmentDurationMs,
      builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get ciphertext => $composableBuilder(
      column: $table.ciphertext, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MsgSyncStatus, String> get syncStatus =>
      $composableBuilder(
          column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get editedAt =>
      $composableBuilder(column: $table.editedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get attachmentKind => $composableBuilder(
      column: $table.attachmentKind, builder: (column) => column);

  GeneratedColumn<String> get attachmentPath => $composableBuilder(
      column: $table.attachmentPath, builder: (column) => column);

  GeneratedColumn<int> get attachmentDurationMs => $composableBuilder(
      column: $table.attachmentDurationMs, builder: (column) => column);
}

class $$MessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessagesTable,
    MessageRow,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (MessageRow, BaseReferences<_$AppDatabase, $MessagesTable, MessageRow>),
    MessageRow,
    PrefetchHooks Function()> {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> senderId = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String?> ciphertext = const Value.absent(),
            Value<MsgSyncStatus> syncStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> editedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> attachmentKind = const Value.absent(),
            Value<String?> attachmentPath = const Value.absent(),
            Value<int?> attachmentDurationMs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            body: body,
            ciphertext: ciphertext,
            syncStatus: syncStatus,
            createdAt: createdAt,
            editedAt: editedAt,
            deletedAt: deletedAt,
            attachmentKind: attachmentKind,
            attachmentPath: attachmentPath,
            attachmentDurationMs: attachmentDurationMs,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String conversationId,
            required String senderId,
            required String body,
            Value<String?> ciphertext = const Value.absent(),
            required MsgSyncStatus syncStatus,
            required DateTime createdAt,
            Value<DateTime?> editedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> attachmentKind = const Value.absent(),
            Value<String?> attachmentPath = const Value.absent(),
            Value<int?> attachmentDurationMs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            body: body,
            ciphertext: ciphertext,
            syncStatus: syncStatus,
            createdAt: createdAt,
            editedAt: editedAt,
            deletedAt: deletedAt,
            attachmentKind: attachmentKind,
            attachmentPath: attachmentPath,
            attachmentDurationMs: attachmentDurationMs,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessagesTable,
    MessageRow,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (MessageRow, BaseReferences<_$AppDatabase, $MessagesTable, MessageRow>),
    MessageRow,
    PrefetchHooks Function()>;
typedef $$NexusChannelsTableCreateCompanionBuilder = NexusChannelsCompanion
    Function({
  required String id,
  required String title,
  required String description,
  required DateTime lastPostAt,
  Value<int> rowid,
});
typedef $$NexusChannelsTableUpdateCompanionBuilder = NexusChannelsCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> description,
  Value<DateTime> lastPostAt,
  Value<int> rowid,
});

class $$NexusChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $NexusChannelsTable> {
  $$NexusChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastPostAt => $composableBuilder(
      column: $table.lastPostAt, builder: (column) => ColumnFilters(column));
}

class $$NexusChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $NexusChannelsTable> {
  $$NexusChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastPostAt => $composableBuilder(
      column: $table.lastPostAt, builder: (column) => ColumnOrderings(column));
}

class $$NexusChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NexusChannelsTable> {
  $$NexusChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPostAt => $composableBuilder(
      column: $table.lastPostAt, builder: (column) => column);
}

class $$NexusChannelsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NexusChannelsTable,
    NexusChannelRow,
    $$NexusChannelsTableFilterComposer,
    $$NexusChannelsTableOrderingComposer,
    $$NexusChannelsTableAnnotationComposer,
    $$NexusChannelsTableCreateCompanionBuilder,
    $$NexusChannelsTableUpdateCompanionBuilder,
    (
      NexusChannelRow,
      BaseReferences<_$AppDatabase, $NexusChannelsTable, NexusChannelRow>
    ),
    NexusChannelRow,
    PrefetchHooks Function()> {
  $$NexusChannelsTableTableManager(_$AppDatabase db, $NexusChannelsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NexusChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NexusChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NexusChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<DateTime> lastPostAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NexusChannelsCompanion(
            id: id,
            title: title,
            description: description,
            lastPostAt: lastPostAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String description,
            required DateTime lastPostAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              NexusChannelsCompanion.insert(
            id: id,
            title: title,
            description: description,
            lastPostAt: lastPostAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NexusChannelsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NexusChannelsTable,
    NexusChannelRow,
    $$NexusChannelsTableFilterComposer,
    $$NexusChannelsTableOrderingComposer,
    $$NexusChannelsTableAnnotationComposer,
    $$NexusChannelsTableCreateCompanionBuilder,
    $$NexusChannelsTableUpdateCompanionBuilder,
    (
      NexusChannelRow,
      BaseReferences<_$AppDatabase, $NexusChannelsTable, NexusChannelRow>
    ),
    NexusChannelRow,
    PrefetchHooks Function()>;
typedef $$ChannelPostsTableCreateCompanionBuilder = ChannelPostsCompanion
    Function({
  required String id,
  required String channelId,
  required String authorName,
  required String body,
  required DateTime createdAt,
  Value<DateTime?> expiresAt,
  Value<String?> blurhash,
  Value<int> rowid,
});
typedef $$ChannelPostsTableUpdateCompanionBuilder = ChannelPostsCompanion
    Function({
  Value<String> id,
  Value<String> channelId,
  Value<String> authorName,
  Value<String> body,
  Value<DateTime> createdAt,
  Value<DateTime?> expiresAt,
  Value<String?> blurhash,
  Value<int> rowid,
});

class $$ChannelPostsTableFilterComposer
    extends Composer<_$AppDatabase, $ChannelPostsTable> {
  $$ChannelPostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get blurhash => $composableBuilder(
      column: $table.blurhash, builder: (column) => ColumnFilters(column));
}

class $$ChannelPostsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChannelPostsTable> {
  $$ChannelPostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get blurhash => $composableBuilder(
      column: $table.blurhash, builder: (column) => ColumnOrderings(column));
}

class $$ChannelPostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChannelPostsTable> {
  $$ChannelPostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get blurhash =>
      $composableBuilder(column: $table.blurhash, builder: (column) => column);
}

class $$ChannelPostsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChannelPostsTable,
    ChannelPostRow,
    $$ChannelPostsTableFilterComposer,
    $$ChannelPostsTableOrderingComposer,
    $$ChannelPostsTableAnnotationComposer,
    $$ChannelPostsTableCreateCompanionBuilder,
    $$ChannelPostsTableUpdateCompanionBuilder,
    (
      ChannelPostRow,
      BaseReferences<_$AppDatabase, $ChannelPostsTable, ChannelPostRow>
    ),
    ChannelPostRow,
    PrefetchHooks Function()> {
  $$ChannelPostsTableTableManager(_$AppDatabase db, $ChannelPostsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelPostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelPostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelPostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> channelId = const Value.absent(),
            Value<String> authorName = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<String?> blurhash = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChannelPostsCompanion(
            id: id,
            channelId: channelId,
            authorName: authorName,
            body: body,
            createdAt: createdAt,
            expiresAt: expiresAt,
            blurhash: blurhash,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String channelId,
            required String authorName,
            required String body,
            required DateTime createdAt,
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<String?> blurhash = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChannelPostsCompanion.insert(
            id: id,
            channelId: channelId,
            authorName: authorName,
            body: body,
            createdAt: createdAt,
            expiresAt: expiresAt,
            blurhash: blurhash,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChannelPostsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChannelPostsTable,
    ChannelPostRow,
    $$ChannelPostsTableFilterComposer,
    $$ChannelPostsTableOrderingComposer,
    $$ChannelPostsTableAnnotationComposer,
    $$ChannelPostsTableCreateCompanionBuilder,
    $$ChannelPostsTableUpdateCompanionBuilder,
    (
      ChannelPostRow,
      BaseReferences<_$AppDatabase, $ChannelPostsTable, ChannelPostRow>
    ),
    ChannelPostRow,
    PrefetchHooks Function()>;
typedef $$NexusGroupsTableCreateCompanionBuilder = NexusGroupsCompanion
    Function({
  required String id,
  required String title,
  required String memberIds,
  required DateTime lastActivityAt,
  Value<int> rowid,
});
typedef $$NexusGroupsTableUpdateCompanionBuilder = NexusGroupsCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> memberIds,
  Value<DateTime> lastActivityAt,
  Value<int> rowid,
});

class $$NexusGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $NexusGroupsTable> {
  $$NexusGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memberIds => $composableBuilder(
      column: $table.memberIds, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastActivityAt => $composableBuilder(
      column: $table.lastActivityAt,
      builder: (column) => ColumnFilters(column));
}

class $$NexusGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $NexusGroupsTable> {
  $$NexusGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memberIds => $composableBuilder(
      column: $table.memberIds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastActivityAt => $composableBuilder(
      column: $table.lastActivityAt,
      builder: (column) => ColumnOrderings(column));
}

class $$NexusGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NexusGroupsTable> {
  $$NexusGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get memberIds =>
      $composableBuilder(column: $table.memberIds, builder: (column) => column);

  GeneratedColumn<DateTime> get lastActivityAt => $composableBuilder(
      column: $table.lastActivityAt, builder: (column) => column);
}

class $$NexusGroupsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NexusGroupsTable,
    NexusGroupRow,
    $$NexusGroupsTableFilterComposer,
    $$NexusGroupsTableOrderingComposer,
    $$NexusGroupsTableAnnotationComposer,
    $$NexusGroupsTableCreateCompanionBuilder,
    $$NexusGroupsTableUpdateCompanionBuilder,
    (
      NexusGroupRow,
      BaseReferences<_$AppDatabase, $NexusGroupsTable, NexusGroupRow>
    ),
    NexusGroupRow,
    PrefetchHooks Function()> {
  $$NexusGroupsTableTableManager(_$AppDatabase db, $NexusGroupsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NexusGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NexusGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NexusGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> memberIds = const Value.absent(),
            Value<DateTime> lastActivityAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NexusGroupsCompanion(
            id: id,
            title: title,
            memberIds: memberIds,
            lastActivityAt: lastActivityAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String memberIds,
            required DateTime lastActivityAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              NexusGroupsCompanion.insert(
            id: id,
            title: title,
            memberIds: memberIds,
            lastActivityAt: lastActivityAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NexusGroupsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NexusGroupsTable,
    NexusGroupRow,
    $$NexusGroupsTableFilterComposer,
    $$NexusGroupsTableOrderingComposer,
    $$NexusGroupsTableAnnotationComposer,
    $$NexusGroupsTableCreateCompanionBuilder,
    $$NexusGroupsTableUpdateCompanionBuilder,
    (
      NexusGroupRow,
      BaseReferences<_$AppDatabase, $NexusGroupsTable, NexusGroupRow>
    ),
    NexusGroupRow,
    PrefetchHooks Function()>;
typedef $$GroupMessagesTableCreateCompanionBuilder = GroupMessagesCompanion
    Function({
  required String id,
  required String groupId,
  required String senderId,
  required String body,
  required MsgSyncStatus syncStatus,
  required DateTime createdAt,
  Value<DateTime?> editedAt,
  Value<DateTime?> deletedAt,
  Value<String?> blurhash,
  Value<String?> attachmentKind,
  Value<String?> attachmentPath,
  Value<int?> attachmentDurationMs,
  Value<int> rowid,
});
typedef $$GroupMessagesTableUpdateCompanionBuilder = GroupMessagesCompanion
    Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> senderId,
  Value<String> body,
  Value<MsgSyncStatus> syncStatus,
  Value<DateTime> createdAt,
  Value<DateTime?> editedAt,
  Value<DateTime?> deletedAt,
  Value<String?> blurhash,
  Value<String?> attachmentKind,
  Value<String?> attachmentPath,
  Value<int?> attachmentDurationMs,
  Value<int> rowid,
});

class $$GroupMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $GroupMessagesTable> {
  $$GroupMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<MsgSyncStatus, MsgSyncStatus, String>
      get syncStatus => $composableBuilder(
          column: $table.syncStatus,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get editedAt => $composableBuilder(
      column: $table.editedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get blurhash => $composableBuilder(
      column: $table.blurhash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentKind => $composableBuilder(
      column: $table.attachmentKind,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentPath => $composableBuilder(
      column: $table.attachmentPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attachmentDurationMs => $composableBuilder(
      column: $table.attachmentDurationMs,
      builder: (column) => ColumnFilters(column));
}

class $$GroupMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupMessagesTable> {
  $$GroupMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get editedAt => $composableBuilder(
      column: $table.editedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get blurhash => $composableBuilder(
      column: $table.blurhash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentKind => $composableBuilder(
      column: $table.attachmentKind,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentPath => $composableBuilder(
      column: $table.attachmentPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attachmentDurationMs => $composableBuilder(
      column: $table.attachmentDurationMs,
      builder: (column) => ColumnOrderings(column));
}

class $$GroupMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupMessagesTable> {
  $$GroupMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MsgSyncStatus, String> get syncStatus =>
      $composableBuilder(
          column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get editedAt =>
      $composableBuilder(column: $table.editedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get blurhash =>
      $composableBuilder(column: $table.blurhash, builder: (column) => column);

  GeneratedColumn<String> get attachmentKind => $composableBuilder(
      column: $table.attachmentKind, builder: (column) => column);

  GeneratedColumn<String> get attachmentPath => $composableBuilder(
      column: $table.attachmentPath, builder: (column) => column);

  GeneratedColumn<int> get attachmentDurationMs => $composableBuilder(
      column: $table.attachmentDurationMs, builder: (column) => column);
}

class $$GroupMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GroupMessagesTable,
    GroupMessageRow,
    $$GroupMessagesTableFilterComposer,
    $$GroupMessagesTableOrderingComposer,
    $$GroupMessagesTableAnnotationComposer,
    $$GroupMessagesTableCreateCompanionBuilder,
    $$GroupMessagesTableUpdateCompanionBuilder,
    (
      GroupMessageRow,
      BaseReferences<_$AppDatabase, $GroupMessagesTable, GroupMessageRow>
    ),
    GroupMessageRow,
    PrefetchHooks Function()> {
  $$GroupMessagesTableTableManager(_$AppDatabase db, $GroupMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String> senderId = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<MsgSyncStatus> syncStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> editedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> blurhash = const Value.absent(),
            Value<String?> attachmentKind = const Value.absent(),
            Value<String?> attachmentPath = const Value.absent(),
            Value<int?> attachmentDurationMs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GroupMessagesCompanion(
            id: id,
            groupId: groupId,
            senderId: senderId,
            body: body,
            syncStatus: syncStatus,
            createdAt: createdAt,
            editedAt: editedAt,
            deletedAt: deletedAt,
            blurhash: blurhash,
            attachmentKind: attachmentKind,
            attachmentPath: attachmentPath,
            attachmentDurationMs: attachmentDurationMs,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            required String senderId,
            required String body,
            required MsgSyncStatus syncStatus,
            required DateTime createdAt,
            Value<DateTime?> editedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> blurhash = const Value.absent(),
            Value<String?> attachmentKind = const Value.absent(),
            Value<String?> attachmentPath = const Value.absent(),
            Value<int?> attachmentDurationMs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GroupMessagesCompanion.insert(
            id: id,
            groupId: groupId,
            senderId: senderId,
            body: body,
            syncStatus: syncStatus,
            createdAt: createdAt,
            editedAt: editedAt,
            deletedAt: deletedAt,
            blurhash: blurhash,
            attachmentKind: attachmentKind,
            attachmentPath: attachmentPath,
            attachmentDurationMs: attachmentDurationMs,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GroupMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GroupMessagesTable,
    GroupMessageRow,
    $$GroupMessagesTableFilterComposer,
    $$GroupMessagesTableOrderingComposer,
    $$GroupMessagesTableAnnotationComposer,
    $$GroupMessagesTableCreateCompanionBuilder,
    $$GroupMessagesTableUpdateCompanionBuilder,
    (
      GroupMessageRow,
      BaseReferences<_$AppDatabase, $GroupMessagesTable, GroupMessageRow>
    ),
    GroupMessageRow,
    PrefetchHooks Function()>;
typedef $$MemberRolesTableCreateCompanionBuilder = MemberRolesCompanion
    Function({
  required String groupId,
  required String userId,
  required NexusMemberRole role,
  required MemberSyncStatus syncStatus,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$MemberRolesTableUpdateCompanionBuilder = MemberRolesCompanion
    Function({
  Value<String> groupId,
  Value<String> userId,
  Value<NexusMemberRole> role,
  Value<MemberSyncStatus> syncStatus,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$MemberRolesTableFilterComposer
    extends Composer<_$AppDatabase, $MemberRolesTable> {
  $$MemberRolesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<NexusMemberRole, NexusMemberRole, String>
      get role => $composableBuilder(
          column: $table.role,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<MemberSyncStatus, MemberSyncStatus, String>
      get syncStatus => $composableBuilder(
          column: $table.syncStatus,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$MemberRolesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemberRolesTable> {
  $$MemberRolesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$MemberRolesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemberRolesTable> {
  $$MemberRolesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NexusMemberRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MemberSyncStatus, String> get syncStatus =>
      $composableBuilder(
          column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MemberRolesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MemberRolesTable,
    MemberRoleRow,
    $$MemberRolesTableFilterComposer,
    $$MemberRolesTableOrderingComposer,
    $$MemberRolesTableAnnotationComposer,
    $$MemberRolesTableCreateCompanionBuilder,
    $$MemberRolesTableUpdateCompanionBuilder,
    (
      MemberRoleRow,
      BaseReferences<_$AppDatabase, $MemberRolesTable, MemberRoleRow>
    ),
    MemberRoleRow,
    PrefetchHooks Function()> {
  $$MemberRolesTableTableManager(_$AppDatabase db, $MemberRolesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemberRolesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemberRolesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemberRolesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<NexusMemberRole> role = const Value.absent(),
            Value<MemberSyncStatus> syncStatus = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MemberRolesCompanion(
            groupId: groupId,
            userId: userId,
            role: role,
            syncStatus: syncStatus,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String userId,
            required NexusMemberRole role,
            required MemberSyncStatus syncStatus,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MemberRolesCompanion.insert(
            groupId: groupId,
            userId: userId,
            role: role,
            syncStatus: syncStatus,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MemberRolesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MemberRolesTable,
    MemberRoleRow,
    $$MemberRolesTableFilterComposer,
    $$MemberRolesTableOrderingComposer,
    $$MemberRolesTableAnnotationComposer,
    $$MemberRolesTableCreateCompanionBuilder,
    $$MemberRolesTableUpdateCompanionBuilder,
    (
      MemberRoleRow,
      BaseReferences<_$AppDatabase, $MemberRolesTable, MemberRoleRow>
    ),
    MemberRoleRow,
    PrefetchHooks Function()>;
typedef $$MessageReactionsTableCreateCompanionBuilder
    = MessageReactionsCompanion Function({
  required String id,
  required String messageId,
  required String targetModule,
  required String userId,
  required String reaction,
  required ReactionSyncStatus syncStatus,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$MessageReactionsTableUpdateCompanionBuilder
    = MessageReactionsCompanion Function({
  Value<String> id,
  Value<String> messageId,
  Value<String> targetModule,
  Value<String> userId,
  Value<String> reaction,
  Value<ReactionSyncStatus> syncStatus,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$MessageReactionsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageReactionsTable> {
  $$MessageReactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetModule => $composableBuilder(
      column: $table.targetModule, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reaction => $composableBuilder(
      column: $table.reaction, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ReactionSyncStatus, ReactionSyncStatus, String>
      get syncStatus => $composableBuilder(
          column: $table.syncStatus,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$MessageReactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageReactionsTable> {
  $$MessageReactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetModule => $composableBuilder(
      column: $table.targetModule,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reaction => $composableBuilder(
      column: $table.reaction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MessageReactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageReactionsTable> {
  $$MessageReactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get targetModule => $composableBuilder(
      column: $table.targetModule, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get reaction =>
      $composableBuilder(column: $table.reaction, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReactionSyncStatus, String> get syncStatus =>
      $composableBuilder(
          column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MessageReactionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessageReactionsTable,
    MessageReactionRow,
    $$MessageReactionsTableFilterComposer,
    $$MessageReactionsTableOrderingComposer,
    $$MessageReactionsTableAnnotationComposer,
    $$MessageReactionsTableCreateCompanionBuilder,
    $$MessageReactionsTableUpdateCompanionBuilder,
    (
      MessageReactionRow,
      BaseReferences<_$AppDatabase, $MessageReactionsTable, MessageReactionRow>
    ),
    MessageReactionRow,
    PrefetchHooks Function()> {
  $$MessageReactionsTableTableManager(
      _$AppDatabase db, $MessageReactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageReactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageReactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageReactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> messageId = const Value.absent(),
            Value<String> targetModule = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> reaction = const Value.absent(),
            Value<ReactionSyncStatus> syncStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessageReactionsCompanion(
            id: id,
            messageId: messageId,
            targetModule: targetModule,
            userId: userId,
            reaction: reaction,
            syncStatus: syncStatus,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String messageId,
            required String targetModule,
            required String userId,
            required String reaction,
            required ReactionSyncStatus syncStatus,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MessageReactionsCompanion.insert(
            id: id,
            messageId: messageId,
            targetModule: targetModule,
            userId: userId,
            reaction: reaction,
            syncStatus: syncStatus,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessageReactionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessageReactionsTable,
    MessageReactionRow,
    $$MessageReactionsTableFilterComposer,
    $$MessageReactionsTableOrderingComposer,
    $$MessageReactionsTableAnnotationComposer,
    $$MessageReactionsTableCreateCompanionBuilder,
    $$MessageReactionsTableUpdateCompanionBuilder,
    (
      MessageReactionRow,
      BaseReferences<_$AppDatabase, $MessageReactionsTable, MessageReactionRow>
    ),
    MessageReactionRow,
    PrefetchHooks Function()>;
typedef $$ReadCursorsTableCreateCompanionBuilder = ReadCursorsCompanion
    Function({
  required String conversationId,
  required String userId,
  required String lastReadMessageId,
  required DateTime lastReadAt,
  Value<int> rowid,
});
typedef $$ReadCursorsTableUpdateCompanionBuilder = ReadCursorsCompanion
    Function({
  Value<String> conversationId,
  Value<String> userId,
  Value<String> lastReadMessageId,
  Value<DateTime> lastReadAt,
  Value<int> rowid,
});

class $$ReadCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $ReadCursorsTable> {
  $$ReadCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastReadMessageId => $composableBuilder(
      column: $table.lastReadMessageId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => ColumnFilters(column));
}

class $$ReadCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadCursorsTable> {
  $$ReadCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastReadMessageId => $composableBuilder(
      column: $table.lastReadMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => ColumnOrderings(column));
}

class $$ReadCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadCursorsTable> {
  $$ReadCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get lastReadMessageId => $composableBuilder(
      column: $table.lastReadMessageId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => column);
}

class $$ReadCursorsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReadCursorsTable,
    ReadCursorRow,
    $$ReadCursorsTableFilterComposer,
    $$ReadCursorsTableOrderingComposer,
    $$ReadCursorsTableAnnotationComposer,
    $$ReadCursorsTableCreateCompanionBuilder,
    $$ReadCursorsTableUpdateCompanionBuilder,
    (
      ReadCursorRow,
      BaseReferences<_$AppDatabase, $ReadCursorsTable, ReadCursorRow>
    ),
    ReadCursorRow,
    PrefetchHooks Function()> {
  $$ReadCursorsTableTableManager(_$AppDatabase db, $ReadCursorsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> conversationId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> lastReadMessageId = const Value.absent(),
            Value<DateTime> lastReadAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadCursorsCompanion(
            conversationId: conversationId,
            userId: userId,
            lastReadMessageId: lastReadMessageId,
            lastReadAt: lastReadAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String conversationId,
            required String userId,
            required String lastReadMessageId,
            required DateTime lastReadAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadCursorsCompanion.insert(
            conversationId: conversationId,
            userId: userId,
            lastReadMessageId: lastReadMessageId,
            lastReadAt: lastReadAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReadCursorsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReadCursorsTable,
    ReadCursorRow,
    $$ReadCursorsTableFilterComposer,
    $$ReadCursorsTableOrderingComposer,
    $$ReadCursorsTableAnnotationComposer,
    $$ReadCursorsTableCreateCompanionBuilder,
    $$ReadCursorsTableUpdateCompanionBuilder,
    (
      ReadCursorRow,
      BaseReferences<_$AppDatabase, $ReadCursorsTable, ReadCursorRow>
    ),
    ReadCursorRow,
    PrefetchHooks Function()>;
typedef $$PromptsTableCreateCompanionBuilder = PromptsCompanion Function({
  required String id,
  required String shape,
  required String body,
  required int rotationIndex,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$PromptsTableUpdateCompanionBuilder = PromptsCompanion Function({
  Value<String> id,
  Value<String> shape,
  Value<String> body,
  Value<int> rotationIndex,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$PromptsTableFilterComposer
    extends Composer<_$AppDatabase, $PromptsTable> {
  $$PromptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shape => $composableBuilder(
      column: $table.shape, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rotationIndex => $composableBuilder(
      column: $table.rotationIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PromptsTableOrderingComposer
    extends Composer<_$AppDatabase, $PromptsTable> {
  $$PromptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shape => $composableBuilder(
      column: $table.shape, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rotationIndex => $composableBuilder(
      column: $table.rotationIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PromptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PromptsTable> {
  $$PromptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shape =>
      $composableBuilder(column: $table.shape, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get rotationIndex => $composableBuilder(
      column: $table.rotationIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PromptsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PromptsTable,
    PromptRow,
    $$PromptsTableFilterComposer,
    $$PromptsTableOrderingComposer,
    $$PromptsTableAnnotationComposer,
    $$PromptsTableCreateCompanionBuilder,
    $$PromptsTableUpdateCompanionBuilder,
    (PromptRow, BaseReferences<_$AppDatabase, $PromptsTable, PromptRow>),
    PromptRow,
    PrefetchHooks Function()> {
  $$PromptsTableTableManager(_$AppDatabase db, $PromptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PromptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PromptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PromptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> shape = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<int> rotationIndex = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PromptsCompanion(
            id: id,
            shape: shape,
            body: body,
            rotationIndex: rotationIndex,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String shape,
            required String body,
            required int rotationIndex,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PromptsCompanion.insert(
            id: id,
            shape: shape,
            body: body,
            rotationIndex: rotationIndex,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PromptsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PromptsTable,
    PromptRow,
    $$PromptsTableFilterComposer,
    $$PromptsTableOrderingComposer,
    $$PromptsTableAnnotationComposer,
    $$PromptsTableCreateCompanionBuilder,
    $$PromptsTableUpdateCompanionBuilder,
    (PromptRow, BaseReferences<_$AppDatabase, $PromptsTable, PromptRow>),
    PromptRow,
    PrefetchHooks Function()>;
typedef $$PromptPrefsTableCreateCompanionBuilder = PromptPrefsCompanion
    Function({
  required String userId,
  required int windowHour,
  Value<bool> optedIn,
  Value<DateTime?> pausedUntil,
  Value<int> rowid,
});
typedef $$PromptPrefsTableUpdateCompanionBuilder = PromptPrefsCompanion
    Function({
  Value<String> userId,
  Value<int> windowHour,
  Value<bool> optedIn,
  Value<DateTime?> pausedUntil,
  Value<int> rowid,
});

class $$PromptPrefsTableFilterComposer
    extends Composer<_$AppDatabase, $PromptPrefsTable> {
  $$PromptPrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get windowHour => $composableBuilder(
      column: $table.windowHour, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get optedIn => $composableBuilder(
      column: $table.optedIn, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get pausedUntil => $composableBuilder(
      column: $table.pausedUntil, builder: (column) => ColumnFilters(column));
}

class $$PromptPrefsTableOrderingComposer
    extends Composer<_$AppDatabase, $PromptPrefsTable> {
  $$PromptPrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get windowHour => $composableBuilder(
      column: $table.windowHour, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get optedIn => $composableBuilder(
      column: $table.optedIn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get pausedUntil => $composableBuilder(
      column: $table.pausedUntil, builder: (column) => ColumnOrderings(column));
}

class $$PromptPrefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PromptPrefsTable> {
  $$PromptPrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get windowHour => $composableBuilder(
      column: $table.windowHour, builder: (column) => column);

  GeneratedColumn<bool> get optedIn =>
      $composableBuilder(column: $table.optedIn, builder: (column) => column);

  GeneratedColumn<DateTime> get pausedUntil => $composableBuilder(
      column: $table.pausedUntil, builder: (column) => column);
}

class $$PromptPrefsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PromptPrefsTable,
    PromptPrefsRow,
    $$PromptPrefsTableFilterComposer,
    $$PromptPrefsTableOrderingComposer,
    $$PromptPrefsTableAnnotationComposer,
    $$PromptPrefsTableCreateCompanionBuilder,
    $$PromptPrefsTableUpdateCompanionBuilder,
    (
      PromptPrefsRow,
      BaseReferences<_$AppDatabase, $PromptPrefsTable, PromptPrefsRow>
    ),
    PromptPrefsRow,
    PrefetchHooks Function()> {
  $$PromptPrefsTableTableManager(_$AppDatabase db, $PromptPrefsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PromptPrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PromptPrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PromptPrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<int> windowHour = const Value.absent(),
            Value<bool> optedIn = const Value.absent(),
            Value<DateTime?> pausedUntil = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PromptPrefsCompanion(
            userId: userId,
            windowHour: windowHour,
            optedIn: optedIn,
            pausedUntil: pausedUntil,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required int windowHour,
            Value<bool> optedIn = const Value.absent(),
            Value<DateTime?> pausedUntil = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PromptPrefsCompanion.insert(
            userId: userId,
            windowHour: windowHour,
            optedIn: optedIn,
            pausedUntil: pausedUntil,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PromptPrefsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PromptPrefsTable,
    PromptPrefsRow,
    $$PromptPrefsTableFilterComposer,
    $$PromptPrefsTableOrderingComposer,
    $$PromptPrefsTableAnnotationComposer,
    $$PromptPrefsTableCreateCompanionBuilder,
    $$PromptPrefsTableUpdateCompanionBuilder,
    (
      PromptPrefsRow,
      BaseReferences<_$AppDatabase, $PromptPrefsTable, PromptPrefsRow>
    ),
    PromptPrefsRow,
    PrefetchHooks Function()>;
typedef $$PromptActionsTableCreateCompanionBuilder = PromptActionsCompanion
    Function({
  required String promptId,
  required String userId,
  required String action,
  required DateTime actedAt,
  Value<int> rowid,
});
typedef $$PromptActionsTableUpdateCompanionBuilder = PromptActionsCompanion
    Function({
  Value<String> promptId,
  Value<String> userId,
  Value<String> action,
  Value<DateTime> actedAt,
  Value<int> rowid,
});

class $$PromptActionsTableFilterComposer
    extends Composer<_$AppDatabase, $PromptActionsTable> {
  $$PromptActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get promptId => $composableBuilder(
      column: $table.promptId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get actedAt => $composableBuilder(
      column: $table.actedAt, builder: (column) => ColumnFilters(column));
}

class $$PromptActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PromptActionsTable> {
  $$PromptActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get promptId => $composableBuilder(
      column: $table.promptId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get actedAt => $composableBuilder(
      column: $table.actedAt, builder: (column) => ColumnOrderings(column));
}

class $$PromptActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PromptActionsTable> {
  $$PromptActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get promptId =>
      $composableBuilder(column: $table.promptId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<DateTime> get actedAt =>
      $composableBuilder(column: $table.actedAt, builder: (column) => column);
}

class $$PromptActionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PromptActionsTable,
    PromptActionRow,
    $$PromptActionsTableFilterComposer,
    $$PromptActionsTableOrderingComposer,
    $$PromptActionsTableAnnotationComposer,
    $$PromptActionsTableCreateCompanionBuilder,
    $$PromptActionsTableUpdateCompanionBuilder,
    (
      PromptActionRow,
      BaseReferences<_$AppDatabase, $PromptActionsTable, PromptActionRow>
    ),
    PromptActionRow,
    PrefetchHooks Function()> {
  $$PromptActionsTableTableManager(_$AppDatabase db, $PromptActionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PromptActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PromptActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PromptActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> promptId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<DateTime> actedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PromptActionsCompanion(
            promptId: promptId,
            userId: userId,
            action: action,
            actedAt: actedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String promptId,
            required String userId,
            required String action,
            required DateTime actedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PromptActionsCompanion.insert(
            promptId: promptId,
            userId: userId,
            action: action,
            actedAt: actedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PromptActionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PromptActionsTable,
    PromptActionRow,
    $$PromptActionsTableFilterComposer,
    $$PromptActionsTableOrderingComposer,
    $$PromptActionsTableAnnotationComposer,
    $$PromptActionsTableCreateCompanionBuilder,
    $$PromptActionsTableUpdateCompanionBuilder,
    (
      PromptActionRow,
      BaseReferences<_$AppDatabase, $PromptActionsTable, PromptActionRow>
    ),
    PromptActionRow,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    SettingRow,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
    SettingRow,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    SettingRow,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
    SettingRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PostsTableTableManager get posts =>
      $$PostsTableTableManager(_db, _db.posts);
  $$PostLikesTableTableManager get postLikes =>
      $$PostLikesTableTableManager(_db, _db.postLikes);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$NexusChannelsTableTableManager get nexusChannels =>
      $$NexusChannelsTableTableManager(_db, _db.nexusChannels);
  $$ChannelPostsTableTableManager get channelPosts =>
      $$ChannelPostsTableTableManager(_db, _db.channelPosts);
  $$NexusGroupsTableTableManager get nexusGroups =>
      $$NexusGroupsTableTableManager(_db, _db.nexusGroups);
  $$GroupMessagesTableTableManager get groupMessages =>
      $$GroupMessagesTableTableManager(_db, _db.groupMessages);
  $$MemberRolesTableTableManager get memberRoles =>
      $$MemberRolesTableTableManager(_db, _db.memberRoles);
  $$MessageReactionsTableTableManager get messageReactions =>
      $$MessageReactionsTableTableManager(_db, _db.messageReactions);
  $$ReadCursorsTableTableManager get readCursors =>
      $$ReadCursorsTableTableManager(_db, _db.readCursors);
  $$PromptsTableTableManager get prompts =>
      $$PromptsTableTableManager(_db, _db.prompts);
  $$PromptPrefsTableTableManager get promptPrefs =>
      $$PromptPrefsTableTableManager(_db, _db.promptPrefs);
  $$PromptActionsTableTableManager get promptActions =>
      $$PromptActionsTableTableManager(_db, _db.promptActions);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
