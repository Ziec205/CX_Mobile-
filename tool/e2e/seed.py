"""Tạo dữ liệu mẫu cho test giao diện: ảnh loài, bài Khám phá, bài cộng đồng, tin rao + tin nhắn.
Dùng: python3 seed.py http://localhost:5080 <media_base_cho_app> <thư mục ảnh>"""
import json, sys, uuid, urllib.request, urllib.error

API, MEDIA_BASE, IMG = sys.argv[1].rstrip('/'), sys.argv[2].rstrip('/'), sys.argv[3]

class SeedError(Exception):
    def __init__(self, status, body):
        super().__init__(f'{status} {body[:300]}'); self.status = status
        try: self.data = json.loads(body)
        except Exception: self.data = {}

def call(method, path, body=None, token=None, raw=None, ctype='application/json'):
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(API + path, data=data, method=method)
    if data is not None: req.add_header('Content-Type', ctype)
    if token: req.add_header('Authorization', 'Bearer ' + token)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            t = r.read().decode()
            return json.loads(t) if t else None
    except urllib.error.HTTPError as e:
        raise SeedError(e.code, e.read().decode())

def upload(token, file, kind, url='/api/media'):
    b = uuid.uuid4().hex
    body = (f'--{b}\r\nContent-Disposition: form-data; name="kind"\r\n\r\n{kind}\r\n'
            f'--{b}\r\nContent-Disposition: form-data; name="file"; filename="a.jpg"\r\nContent-Type: image/jpeg\r\n\r\n').encode() + open(file, 'rb').read() + f'\r\n--{b}--\r\n'.encode()
    return call('POST', url, raw=body, token=token, ctype=f'multipart/form-data; boundary={b}')['id']

def member(username, full):
    try:
        r = call('POST', '/api/auth/register', {'username': username, 'password': 'matkhau123', 'confirmPassword': 'matkhau123'})
    except SeedError:
        r = call('POST', '/api/auth/login', {'username': username, 'password': 'matkhau123'})
    tok = r['tokens']['accessToken']
    call('PUT', '/api/me', {'displayName': full, 'fullName': full, 'provinceId': '92', 'email': f'{username}@example.com'}, tok)
    return tok, r['user']['id']

admin = call('POST', '/api/admin/auth/login', {'username': 'admin', 'password': '123'})
atok = admin['tokens']['accessToken'] if 'tokens' in admin else admin['accessToken']

# Ảnh minh họa loài
for sid, img in [('monstera', 'monstera'), ('luoi-ho', 'luoi-ho'), ('sen-da-kim-tuyen', 'sen-da'), ('trau-ba', 'trau-ba')]:
    mid = upload(atok, f'{IMG}/{img}.jpg', 'ArticlePhoto', '/api/admin/media')
    s = call('GET', f'/api/species/{sid}')
    s['imageUrl'] = f'{MEDIA_BASE}/media/{mid}/card.webp'
    call('PUT', f'/api/admin/catalog/species/{sid}', s, atok)

# Bài Khám phá
arts = [
    ('Trầu bà: cây dễ sống nhất cho người mới', 'Ánh sáng tán xạ, tưới khi mặt đất khô 2–3 cm.', 'trau-ba', 'trau-ba',
     'Trầu bà chịu được bóng râm, hợp đặt trong phòng khách hoặc văn phòng.\n\nTưới khi lớp đất mặt khô khoảng 2–3 cm, mùa mưa giảm còn 1 lần mỗi tuần.\n\nMỗi tháng bón một lần phân tan chậm để lá xanh bóng.'),
    ('Lưỡi hổ lọc không khí, gần như không cần tưới', 'Hai tuần tưới một lần là đủ.', 'luoi-ho', 'luoi-ho',
     'Lưỡi hổ chịu hạn tốt nhờ lá mọng nước.\n\nTưới quá nhiều là nguyên nhân chính khiến cây thối gốc.\n\nĐặt nơi có nắng nhẹ buổi sáng để lá lên màu đẹp.'),
    ('Sen đá: nắng sớm, đất thoát nước', 'Bí quyết giữ sen đá không bị úng.', 'sen-da-kim-tuyen', 'sen-da',
     'Sen đá cần ít nhất 4 giờ nắng mỗi ngày.\n\nTrộn đất với đá perlite hoặc xỉ than để thoát nước nhanh.\n\nTưới đẫm rồi để khô hẳn mới tưới lần sau.'),
    ('Monstera lá xẻ: chăm sao cho lá to', 'Ánh sáng sáng, độ ẩm cao và cột bám.', 'monstera', 'monstera',
     'Monstera thích ánh sáng sáng nhưng không gắt.\n\nCắm cột dừa cho cây leo, lá sẽ xẻ nhiều và to hơn.\n\nLau lá định kỳ để cây quang hợp tốt.'),
]
existing = {a['slug'] for a in call('GET', '/api/explore?pageSize=50')['items']}
for title, summary, sid, img, body in arts:
    cover = upload(atok, f'{IMG}/{img}.jpg', 'ArticlePhoto', '/api/admin/media')
    extra = upload(atok, f'{IMG}/vuon.jpg', 'ArticlePhoto', '/api/admin/media')
    try:
        call('POST', '/api/admin/explore', {'title': title, 'summary': summary, 'body': body, 'mediaIds': [cover, extra], 'speciesId': sid,
                                            'tags': ['cham-cay', sid], 'status': 'Published', 'publishAt': None}, atok)
    except SeedError as e:
        if 'SLUG_TAKEN' not in str(e): raise

# Thành viên + bài cộng đồng
lan, lan_id = member('chi.lan', 'Chị Lan')
minh, minh_id = member('anh.minh', 'Anh Minh')
titles = {x['title'] for x in call('GET', '/api/community/posts')['items']}
if 'Trầu bà bị vàng lá phía dưới là do đâu?' not in titles:
    call('POST', '/api/community/posts', {'type': 'Question', 'title': 'Trầu bà bị vàng lá phía dưới là do đâu?', 'body': 'Cây nhà mình để trong phòng, tưới 2 ngày một lần mà lá dưới cứ vàng dần. Mọi người chỉ giúp với ạ!', 'topics': ['benh-cay']}, lan)
if 'Khoe chậu sen đá mới trồng lại' not in titles:
    p = call('POST', '/api/community/posts', {'type': 'Showcase', 'title': 'Khoe chậu sen đá mới trồng lại', 'body': 'Vừa thay đất trộn perlite, cây lên màu đẹp hẳn. Cảm ơn cả nhà đã chỉ cách!', 'mediaIds': [upload(minh, f'{IMG}/sen-da.jpg', 'CommunityPhoto')]}, minh)
    call('POST', f"/api/community/posts/{p['id']}/comments", {'body': 'Đẹp quá anh ơi, đất trộn tỉ lệ bao nhiêu vậy?'}, lan)
if 'Kinh nghiệm tưới cây khi đi vắng 1 tuần' not in titles:
    call('POST', '/api/community/posts', {'type': 'Guide', 'title': 'Kinh nghiệm tưới cây khi đi vắng 1 tuần', 'body': 'Dùng chai nhựa đục lỗ nhỏ cắm ngược vào chậu, hoặc đặt chậu lên khay sỏi có nước. Cây ưa ẩm thì gom lại một chỗ để giữ độ ẩm.'}, lan)

# Tin rao của anh Minh để người dùng test nhắn tin
photos = [upload(minh, f'{IMG}/{n}.jpg', 'ListingPhoto') for n in ('monstera', 'vuon', 'monstera')]
try:
  l = call('POST', '/api/listings', {'listing': {'type': 'Sell', 'categoryId': 'noi-that', 'speciesId': 'monstera', 'title': 'Monstera lá xẻ chậu 30cm',
          'description': 'Cây khỏe, 6 lá to, đã quen nắng trong nhà.', 'price': 450000, 'quantity': 1, 'attributes': {'tinhTrang': 'Trồng chậu', 'chieuCao': 80},
          'mediaIds': photos, 'lat': 10.03, 'lng': 105.78}, 'submit': True}, minh)
  listing = l.get('id') or l['listing']['id']
except SeedError as e:
  if e.data.get('code') != 'DUPLICATE_LISTING': raise
  listing = e.data['details']['existingListingId']
print(json.dumps({'listingId': listing, 'sellerToken': minh, 'sellerId': minh_id}))
