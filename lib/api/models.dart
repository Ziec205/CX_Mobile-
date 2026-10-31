// Mô hình dữ liệu theo JSON của BE (camelCase, enum dạng chuỗi).

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
DateTime _dateOr(Object? v) => _date(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    v is List ? v.whereType<Map<String, dynamic>>().map(f).toList() : <T>[];

/// BE trả DateTime UTC đôi khi không kèm "Z" (Mongo); coi là UTC.
DateTime? parseUtc(Object? v) {
  if (v is! String) return null;
  final s = RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(v) ? v : '${v}Z';
  return DateTime.tryParse(s)?.toUtc();
}

class Me {
  Me({required this.id, required this.displayName, this.username, this.email, this.fullName});
  final String id;
  final String displayName;
  final String? username;
  final String? email;
  final String? fullName;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: j['id'] as String,
        displayName: (j['displayName'] as String?) ?? (j['username'] as String?) ?? 'Bạn',
        username: j['username'] as String?,
        email: j['email'] as String?,
        fullName: j['fullName'] as String?,
      );
}

enum ReminderKind { watering, fertilizing, pruning, repotting, other }

enum ReminderRepeat { none, daily, weekly, monthly, yearly }

T _enum<T extends Enum>(List<T> values, Object? v, T fallback) =>
    values.firstWhere((e) => e.name.toLowerCase() == '$v'.toLowerCase(), orElse: () => fallback);
String enumApi(Enum e) => e.name[0].toUpperCase() + e.name.substring(1);

const reminderKindLabel = {
  ReminderKind.watering: 'Tưới nước',
  ReminderKind.fertilizing: 'Bón phân',
  ReminderKind.pruning: 'Cắt tỉa',
  ReminderKind.repotting: 'Thay chậu',
  ReminderKind.other: 'Việc khác',
};
const reminderRepeatUnit = {
  ReminderRepeat.none: 'Một lần',
  ReminderRepeat.daily: 'ngày',
  ReminderRepeat.weekly: 'tuần',
  ReminderRepeat.monthly: 'tháng',
  ReminderRepeat.yearly: 'năm',
};

String repeatText(ReminderRepeat r, int interval) {
  if (r == ReminderRepeat.none) return 'Một lần';
  return interval <= 1 ? 'Mỗi ${reminderRepeatUnit[r]}' : 'Mỗi $interval ${reminderRepeatUnit[r]}';
}

class CareReminder {
  CareReminder({
    required this.id,
    required this.plantId,
    required this.kind,
    required this.anchorAt,
    required this.repeat,
    required this.interval,
    required this.enabled,
    this.note,
    this.nextAt,
  });
  final String id;
  final String plantId;
  final ReminderKind kind;
  final String? note;
  final DateTime anchorAt; // UTC
  final ReminderRepeat repeat;
  final int interval;
  final DateTime? nextAt; // UTC
  final bool enabled;

  factory CareReminder.fromJson(Map<String, dynamic> j) => CareReminder(
        id: j['id'] as String,
        plantId: j['plantId'] as String,
        kind: _enum(ReminderKind.values, j['kind'], ReminderKind.other),
        note: j['note'] as String?,
        anchorAt: parseUtc(j['anchorAt']) ?? DateTime.now().toUtc(),
        repeat: _enum(ReminderRepeat.values, j['repeat'], ReminderRepeat.none),
        interval: (j['interval'] as num?)?.toInt() ?? 1,
        nextAt: parseUtc(j['nextAt']),
        enabled: j['enabled'] as bool? ?? true,
      );
}

class MyPlant {
  MyPlant({
    required this.id,
    required this.name,
    required this.reminders,
    required this.locked,
    required this.createdAt,
    this.speciesId,
    this.speciesName,
    this.speciesImageUrl,
    this.location,
    this.acquiredAt,
    this.note,
  });
  final String id;
  final String name;
  final String? speciesId;
  final String? speciesName;
  final String? speciesImageUrl;
  final String? location;
  final DateTime? acquiredAt;
  final String? note;
  final DateTime createdAt;
  final bool locked;
  final List<CareReminder> reminders;

  factory MyPlant.fromJson(Map<String, dynamic> j) => MyPlant(
        id: j['id'] as String,
        name: j['name'] as String,
        speciesId: j['speciesId'] as String?,
        speciesName: j['speciesName'] as String?,
        speciesImageUrl: j['speciesImageUrl'] as String?,
        location: j['location'] as String?,
        acquiredAt: _date(j['acquiredAt']),
        note: j['note'] as String?,
        createdAt: _dateOr(j['createdAt']),
        locked: j['locked'] as bool? ?? false,
        reminders: _list(j['reminders'], CareReminder.fromJson),
      );
}

class Species {
  Species(this.id, this.name, {this.scientificName, this.water, this.light});
  final String id;
  final String name;
  final String? scientificName;
  final String? water;
  final String? light;
  factory Species.fromJson(Map<String, dynamic> j) => Species(j['id'] as String, (j['commonName'] ?? j['name'] ?? j['id']) as String,
      scientificName: j['scientificName'] as String?, water: j['water'] as String?, light: j['light'] as String?);
}

class Media {
  Media(this.id, this.urls);
  final String id;
  final Map<String, String> urls;
  String? get card => urls['card'] ?? urls['full'] ?? urls['thumb'];
  String? get thumb => urls['thumb'] ?? card;
  factory Media.fromJson(Map<String, dynamic> j) =>
      Media(j['id'] as String, (j['urls'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {});
}

class Author {
  Author(this.id, this.name, {this.badge, this.expert = false});
  final String id;
  final String name;
  final String? badge;
  final bool expert;
  factory Author.fromJson(Map<String, dynamic>? j) =>
      j == null ? Author('', 'Thành viên') : Author(j['id'] as String? ?? '', j['name'] as String? ?? 'Thành viên', badge: j['badge'] as String?, expert: j['expert'] as bool? ?? false);
}

const postTypeLabel = {'Question': 'Hỏi đáp', 'Showcase': 'Khoe cây', 'Guide': 'Kinh nghiệm'};

class PostSummary {
  PostSummary({required this.id, required this.type, required this.title, required this.excerpt, required this.likes, required this.comments, required this.answered, required this.createdAt, required this.author, this.thumbUrl});
  final String id, type, title, excerpt;
  final int likes, comments;
  final bool answered;
  final DateTime createdAt;
  final String? thumbUrl;
  final Author author;
  factory PostSummary.fromJson(Map<String, dynamic> j) => PostSummary(
        id: j['id'] as String,
        type: '${j['type']}',
        title: j['title'] as String? ?? '',
        excerpt: j['excerpt'] as String? ?? '',
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        comments: (j['comments'] as num?)?.toInt() ?? 0,
        answered: j['answered'] as bool? ?? false,
        createdAt: _dateOr(j['createdAt']),
        thumbUrl: j['thumbUrl'] as String?,
        author: Author.fromJson(j['author'] as Map<String, dynamic>?),
      );
}

class Comment {
  Comment({required this.id, required this.body, required this.likes, required this.isBest, required this.createdAt, required this.author, required this.photos, required this.liked});
  final String id, body;
  final int likes;
  final bool isBest, liked;
  final DateTime createdAt;
  final Author author;
  final List<Media> photos;
  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as String,
        body: j['body'] as String? ?? '',
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        isBest: j['isBest'] as bool? ?? false,
        liked: j['liked'] as bool? ?? false,
        createdAt: _dateOr(j['createdAt']),
        author: Author.fromJson(j['author'] as Map<String, dynamic>?),
        photos: _list(j['photos'], Media.fromJson),
      );
}

class PostDetail {
  PostDetail({required this.id, required this.type, required this.title, required this.body, required this.likes, required this.liked, required this.createdAt, required this.author, required this.photos, required this.comments});
  final String id, type, title, body;
  final int likes;
  final bool liked;
  final DateTime createdAt;
  final Author author;
  final List<Media> photos;
  final List<Comment> comments;
  factory PostDetail.fromJson(Map<String, dynamic> root) {
    final j = root['post'] as Map<String, dynamic>;
    return PostDetail(
      id: j['id'] as String,
      type: '${j['type']}',
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      likes: (j['likes'] as num?)?.toInt() ?? 0,
      liked: j['liked'] as bool? ?? false,
      createdAt: _dateOr(j['createdAt']),
      author: Author.fromJson(j['author'] as Map<String, dynamic>?),
      photos: _list(j['photos'], Media.fromJson),
      comments: _list(root['comments'], Comment.fromJson),
    );
  }
}

class Article {
  Article({required this.id, required this.slug, required this.title, this.summary, this.body, this.cover, this.publishAt, this.tags = const []});
  final String id, slug, title;
  final String? summary, body;
  final Media? cover;
  final DateTime? publishAt;
  final List<String> tags;
  factory Article.fromJson(Map<String, dynamic> j) => Article(
        id: j['id'] as String,
        slug: j['slug'] as String,
        title: j['title'] as String? ?? '',
        summary: j['summary'] as String?,
        body: j['body'] as String?,
        cover: j['cover'] is Map<String, dynamic> ? Media.fromJson(j['cover'] as Map<String, dynamic>) : null,
        publishAt: _date(j['publishAt']),
        tags: (j['tags'] as List?)?.map((e) => '$e').toList() ?? const [],
      );
}

class Conversation {
  Conversation({required this.id, required this.title, required this.role, required this.otherUserId, required this.unread, this.lastPreview, this.lastAt, this.thumbUrl, this.blocked = false});
  final String id, title, role, otherUserId;
  final String? lastPreview, thumbUrl;
  final DateTime? lastAt;
  final int unread;
  final bool blocked;
  factory Conversation.fromJson(Map<String, dynamic> j) {
    final listing = j['listing'] as Map<String, dynamic>?;
    final last = j['last'] as Map<String, dynamic>?;
    return Conversation(
      id: j['id'] as String,
      title: listing?['title'] as String? ?? 'Trò chuyện',
      thumbUrl: listing?['thumbUrl'] as String?,
      role: j['role'] as String? ?? 'buyer',
      otherUserId: j['otherUserId'] as String? ?? '',
      unread: (j['unread'] as num?)?.toInt() ?? 0,
      blocked: j['blocked'] as bool? ?? false,
      lastPreview: last?['preview'] as String?,
      lastAt: _date(last?['at']),
    );
  }
}

class ChatMessage {
  ChatMessage({required this.id, required this.conversationId, required this.senderId, required this.type, required this.createdAt, this.text, this.warning, this.offerAmount});
  final String id, conversationId, senderId, type;
  final String? text, warning;
  final int? offerAmount;
  final DateTime createdAt;
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        conversationId: j['conversationId'] as String,
        senderId: j['senderId'] as String,
        type: '${j['type'] ?? 'Text'}',
        text: j['text'] as String?,
        warning: j['warning'] as String?,
        offerAmount: ((j['offer'] as Map?)?['amount'] as num?)?.toInt(),
        createdAt: parseUtc(j['createdAt'])?.toLocal() ?? DateTime.now(),
      );
}

class PlanInfo {
  PlanInfo({required this.code, required this.name, required this.tagline, required this.monthlyVnd, required this.yearlyVnd, required this.gardenPlants, required this.aiPerDay, required this.listingsPerMonth});
  final String code, name, tagline;
  final int monthlyVnd, yearlyVnd, gardenPlants, aiPerDay, listingsPerMonth;
  factory PlanInfo.fromJson(Map<String, dynamic> j) => PlanInfo(
        code: '${j['code']}',
        name: j['name'] as String? ?? '',
        tagline: j['tagline'] as String? ?? '',
        monthlyVnd: (j['monthlyVnd'] as num?)?.toInt() ?? 0,
        yearlyVnd: (j['yearlyVnd'] as num?)?.toInt() ?? 0,
        gardenPlants: (j['gardenPlants'] as num?)?.toInt() ?? 0,
        aiPerDay: (j['aiPerDay'] as num?)?.toInt() ?? 0,
        listingsPerMonth: (j['listingsPerMonth'] as num?)?.toInt() ?? 0,
      );
}

class MyPlan {
  MyPlan(this.plan, this.endAt, this.gardenPlantsUsed);
  final PlanInfo plan;
  final DateTime? endAt;
  final int gardenPlantsUsed;
  factory MyPlan.fromJson(Map<String, dynamic> j) => MyPlan(
        PlanInfo.fromJson(j['plan'] as Map<String, dynamic>),
        _date(j['endAt']),
        ((j['usage'] as Map?)?['gardenPlants'] as num?)?.toInt() ?? 0,
      );
}

class PlanPayment {
  PlanPayment({required this.id, required this.plan, required this.months, required this.amountVnd, required this.orderCode, required this.status, required this.expiresAt, this.checkoutUrl, this.qrCode});
  final String id, plan, status;
  final int months, amountVnd, orderCode;
  final String? checkoutUrl, qrCode;
  final DateTime expiresAt;
  bool get isPending => status == 'Pending';
  factory PlanPayment.fromJson(Map<String, dynamic> j) => PlanPayment(
        id: j['id'] as String,
        plan: '${j['plan']}',
        months: (j['months'] as num?)?.toInt() ?? 1,
        amountVnd: (j['amountVnd'] as num?)?.toInt() ?? 0,
        orderCode: (j['orderCode'] as num?)?.toInt() ?? 0,
        status: '${j['status']}',
        expiresAt: parseUtc(j['expiresAt'])?.toLocal() ?? DateTime.now(),
        checkoutUrl: j['checkoutUrl'] as String?,
        qrCode: j['qrCode'] as String?,
      );
}
