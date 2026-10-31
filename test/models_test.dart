import 'package:cham_xanh/api/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PlanPayment đọc qrCode từ BE', () {
    final p = PlanPayment.fromJson({
      'id': 'x', 'plan': 'Plus', 'months': 1, 'amountVnd': 49000, 'orderCode': 123, 'gateway': 'PAYOS',
      'checkoutUrl': 'https://pay.payos.vn/web/abc', 'qrCode': '000201010212', 'status': 'Pending',
      'createdAt': '2027-01-01T00:00:00Z', 'expiresAt': '2027-01-01T00:15:00Z',
    });
    expect(p.qrCode, '000201010212');
    expect(p.isPending, isTrue);
  });

  test('MyPlant: ảnh loài, lời nhắc, ngày không có Z coi là UTC', () {
    final p = MyPlant.fromJson({
      'id': 'p', 'name': 'Trầu bà', 'speciesId': 'trau-ba', 'speciesName': 'Trầu bà', 'speciesImageUrl': 'https://img/x.webp',
      'createdAt': '2027-01-01T00:00:00Z', 'locked': false, 'photos': [],
      'reminders': [
        {'id': 'r', 'plantId': 'p', 'kind': 'Watering', 'anchorAt': '2027-01-02T00:30:00', 'repeat': 'Daily', 'interval': 2, 'nextAt': '2027-01-02T00:30:00', 'enabled': true},
      ],
    });
    expect(p.speciesImageUrl, 'https://img/x.webp');
    final r = p.reminders.single;
    expect(r.kind, ReminderKind.watering);
    expect(r.repeat, ReminderRepeat.daily);
    expect(r.anchorAt, DateTime.utc(2027, 1, 2, 0, 30));
    expect(repeatText(r.repeat, r.interval), 'Mỗi 2 ngày');
    expect(enumApi(ReminderRepeat.monthly), 'Monthly');
  });

  test('ChatMessage và Conversation', () {
    final m = ChatMessage.fromJson({'id': 'm', 'conversationId': 'c', 'senderId': 'u', 'type': 'Offer', 'offer': {'amount': 150000, 'status': 'Pending'}, 'createdAt': '2027-01-01T00:00:00Z'});
    expect(m.offerAmount, 150000);
    final c = Conversation.fromJson({'id': 'c', 'listing': {'title': 'Sen đá', 'type': 'Sell'}, 'last': {'senderId': 'u', 'preview': 'Chào', 'at': '2027-01-01T00:00:00Z'}, 'role': 'buyer', 'otherUserId': 'v', 'unread': 2});
    expect((c.title, c.lastPreview, c.unread), ('Sen đá', 'Chào', 2));
  });
}
