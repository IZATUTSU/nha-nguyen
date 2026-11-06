# Nhà Nguyện Ánh Nến

Nhà nguyện Công giáo 3D chơi trên trình duyệt: thắp nến, lần chuỗi Mân Côi, chầu Thánh Thể,
chuông Truyền Tin, tường ý nguyện; nhân vật có thể ngồi, quỳ, chắp tay, làm dấu Thánh Giá
và thấy những người khác đang cùng cầu nguyện.

## Cấu trúc
- `index.html` – toàn bộ game (Three.js tải từ jsDelivr).
- Nhiều người chơi: Supabase Realtime. Điền `supabaseUrl` và `supabaseKey` (khoá anon/publishable)
  trong `NET_CONFIG` ở `index.html`. Không bao giờ dùng khoá service_role/secret.
- Chưa có cấu hình: các thẻ trong cùng một trình duyệt vẫn thấy nhau để thử.

## Hạn mức miễn phí của Supabase (tham khảo, có thể thay đổi)
- 200 kết nối cùng lúc, khoảng 2 triệu tin nhắn Realtime mỗi tháng.
- Dự án tự tạm dừng nếu 7 ngày không có ai truy cập; vào trang Supabase bấm Resume để chạy lại.
- Game chỉ gửi vị trí khi người chơi di chuyển (tối đa 5 lần/giây) và 3 giây một lần khi ngồi yên.

## Lưu ý nội dung
Lời kinh trong bản thử nghiệm cần linh mục duyệt lại trước khi công bố rộng rãi.
Game là nơi cầu nguyện, không thay thế Thánh lễ và các bí tích.

## Nến và tường ý nguyện dùng chung
1. Mở Supabase → **SQL Editor** → **New query**, dán toàn bộ `supabase/schema.sql`, bấm **Run**.
2. Xong. Game tự nhận ra hai bảng `candles` và `intentions`. Nếu chưa chạy SQL, game vẫn chạy và lưu nến/ý nguyện trên từng máy.

### Ẩn một ý nguyện không phù hợp
Supabase → **Table Editor** → bảng `intentions` → đổi cột `hidden` của dòng đó thành `true`.
Người chơi sẽ không thấy ý nguyện này nữa (sau khi tải lại trang).

### Giới hạn chống spam (trong `schema.sql`)
- Toàn nhà nguyện: tối đa 150 ngọn nến và 40 ý nguyện mỗi 10 phút.
- Mỗi máy: 30 giây mới được ghi một ý nguyện, mỗi ý nguyện chỉ bấm "Cầu nguyện" một lần.

## Kiểm duyệt và quản trị
1. Chạy `supabase/kiem-duyet.sql` trong Supabase → SQL Editor (sau `schema.sql`).
2. Thêm email quản trị: `insert into public.admins (email) values ('email@cua-ban.com');`
3. Supabase → Authentication → URL Configuration: Site URL = `https://izatutsu.github.io/nha-nguyen/quan-tri.html`.
4. Mở `https://izatutsu.github.io/nha-nguyen/quan-tri.html`, nhập email, bấm link trong thư để đăng nhập.

- Ý nguyện và tên có từ tục, số điện thoại, đường link, email bị chặn cả trong game lẫn trên máy chủ (bảng `tu_cam`, hàm `noi_dung_vi_pham`).
- 3 người khác nhau báo cáo một ý nguyện thì ý nguyện tự ẩn; quản trị viên có thể hiện lại.
