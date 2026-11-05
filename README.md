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
