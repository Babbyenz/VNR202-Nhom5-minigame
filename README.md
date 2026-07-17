# Đấu trường Lịch sử Việt Nam 1975–1981

Game quiz nhiều người chơi theo thời gian thực, phù hợp để tổ chức trong lớp học hoặc thuyết trình nhóm.

## Luật chơi

- Một người tạo phòng và gửi mã gồm 6 ký tự cho người khác.
- Tất cả thiết bị nhận cùng một câu hỏi.
- Mỗi câu có 20 giây.
- Chỉ câu trả lời đúng mới có điểm.
- Người trả lời đúng nhanh nhất nhận 1.000 điểm cơ bản; hạng 2 nhận 700; hạng 3 nhận 500; các hạng sau nhận 300.
- Mỗi người còn nhận tối đa 200 điểm thưởng tốc độ.
- Sau từng câu, game công bố đáp án, giải thích và xếp hạng tốc độ.
- Kết thúc trận, người có tổng điểm cao nhất chiến thắng.

Thời gian, thứ hạng và điểm số được tính trong hàm PostgreSQL trên Supabase, không tính trực tiếp trong trình duyệt.

## Thành phần dự án

```text
.
├── index.html
├── package.json
├── vite.config.js
├── vercel.json
├── .env.example
├── src/
│   ├── main.js
│   └── style.css
└── supabase/
    └── schema.sql
```

## Bước 1: Tạo Supabase

1. Tạo một project mới tại Supabase.
2. Mở **SQL Editor → New query**.
3. Sao chép toàn bộ nội dung file `supabase/schema.sql` và chọn **Run**.
4. Mở phần **Project Settings / API** hoặc hộp thoại **Connect**.
5. Lấy:
   - Project URL.
   - Publishable key hoặc `anon` key.

Không sử dụng `service_role` hoặc secret key trong website.

## Bước 2: Chạy trên máy

Tạo file `.env` tại thư mục gốc:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

Sau đó chạy:

```bash
npm install
npm run dev
```

Mở địa chỉ Vite hiển thị trong Terminal, thường là `http://localhost:5173`.

## Bước 3: Đưa lên Vercel

### Cách dùng GitHub

1. Đưa toàn bộ dự án lên một GitHub repository.
2. Vào Vercel, chọn **Add New → Project**.
3. Chọn repository vừa tạo.
4. Framework Preset: **Vite**.
5. Thêm hai Environment Variables:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
6. Chọn **Deploy**.

### Cách dùng Vercel CLI

```bash
npm install -g vercel
vercel
```

Thêm hai biến môi trường trong Vercel Dashboard rồi triển khai production:

```bash
vercel --prod
```

Sau khi thêm hoặc sửa biến môi trường, cần triển khai lại để Vite đưa cấu hình vào bản build mới.

## Kiểm tra nhiều người chơi

1. Mở website trên máy tính và tạo phòng.
2. Dùng điện thoại hoặc cửa sổ ẩn danh mở liên kết phòng.
3. Nhập một tên khác và tham gia.
4. Bắt đầu khi phòng có ít nhất 2 người.

## Lưu ý

- Mỗi phòng hỗ trợ tối đa 30 người.
- Không cho người mới tham gia khi một trận đang diễn ra.
- Có thể tham gia sau khi trận kết thúc để chơi trận mới.
- Người chơi tải lại trang vẫn có thể quay lại phiên cũ trên cùng trình duyệt.
