# OpenSSL Commands Reference

Tài liệu tham khảo nhanh về các lệnh OpenSSL cho việc tạo và xác thực chữ ký firmware.

## Tạo Cặp Khóa RSA

### Tạo Private Key (2048-bit)

```bash
openssl genrsa -out private_key.pem 2048
```

### Tạo Private Key (4096-bit - Bảo mật cao hơn)

```bash
openssl genrsa -out private_key.pem 4096
```

### Tạo Public Key từ Private Key

```bash
openssl rsa -in private_key.pem -pubout -out public_key.pem
```

### Xem Thông tin Key

```bash
# Xem thông tin private key
openssl rsa -in private_key.pem -text -noout

# Xem thông tin public key
openssl rsa -in public_key.pem -pubin -text -noout
```

## Tạo Chữ ký (Signing)

### Tạo Chữ ký SHA256 cho File

```bash
# Tạo chữ ký cho manifest.json
openssl dgst -sha256 -sign private_key.pem -out signature.sig manifest.json
```

### Tạo Chữ ký với Base64 Encoding (Tùy chọn)

```bash
openssl dgst -sha256 -sign private_key.pem manifest.json | base64 > signature.sig
```

## Xác thực Chữ ký (Verification)

### Xác thực Chữ ký (Standard)

```bash
openssl dgst -sha256 -verify public_key.pem -signature signature.sig manifest.json
```

### Xác thực Chữ ký (Verbose Output)

```bash
openssl dgst -sha256 -verify public_key.pem -signature signature.sig manifest.json -verbose
```

### Xác thực Chữ ký Base64 (Nếu dùng base64)

```bash
cat signature.sig | base64 -d | openssl dgst -sha256 -verify public_key.pem -signature /dev/stdin manifest.json
```

## Ví dụ Hoàn chỉnh

### Bước 1: Tạo Key Pair

```bash
# Tạo private key
openssl genrsa -out private_key.pem 2048

# Tạo public key
openssl rsa -in private_key.pem -pubout -out public_key.pem

# Set permissions
chmod 600 private_key.pem
chmod 644 public_key.pem
```

### Bước 2: Tạo Manifest và Tính Checksum

```bash
# Tạo manifest.json
cat > manifest.json << EOF
{
  "version": "1.2.0",
  "hardware_id": "my_device_v1",
  "checksum_md5": "$(md5sum firmware.img | cut -d' ' -f1)"
}
EOF
```

### Bước 3: Tạo Chữ ký

```bash
# Tạo chữ ký cho manifest.json
openssl dgst -sha256 -sign private_key.pem -out signature.sig manifest.json
```

### Bước 4: Xác thực Chữ ký (Test)

```bash
# Xác thực chữ ký
if openssl dgst -sha256 -verify public_key.pem -signature signature.sig manifest.json; then
    echo "Signature is valid!"
else
    echo "Signature is INVALID!"
fi
```

## Các Thuật toán Hash Khác

### SHA1 (Không khuyến nghị - đã lỗi thời)

```bash
openssl dgst -sha1 -sign private_key.pem -out signature.sig manifest.json
openssl dgst -sha1 -verify public_key.pem -signature signature.sig manifest.json
```

### SHA384

```bash
openssl dgst -sha384 -sign private_key.pem -out signature.sig manifest.json
openssl dgst -sha384 -verify public_key.pem -signature signature.sig manifest.json
```

### SHA512

```bash
openssl dgst -sha512 -sign private_key.pem -out signature.sig manifest.json
openssl dgst -sha512 -verify public_key.pem -signature signature.sig manifest.json
```

## Kiểm tra File Signature

### Xem Thông tin Signature

```bash
# Signature là binary, không thể xem trực tiếp
# Nhưng có thể xem hex dump
hexdump -C signature.sig | head
```

### So sánh Signature

```bash
# So sánh hai signature files
diff signature1.sig signature2.sig
```

## Troubleshooting

### Lỗi: "unable to load Private Key"

```bash
# Kiểm tra file tồn tại
ls -la private_key.pem

# Kiểm tra format
file private_key.pem  # Should show "PEM RSA private key"

# Kiểm tra permissions
chmod 600 private_key.pem
```

### Lỗi: "unable to load Public Key"

```bash
# Kiểm tra file tồn tại
ls -la public_key.pem

# Kiểm tra format
file public_key.pem  # Should show "PEM RSA public key"

# Tạo lại public key từ private key
openssl rsa -in private_key.pem -pubout -out public_key.pem
```

### Lỗi: "Verification Failure"

- Đảm bảo public key khớp với private key đã dùng để ký
- Đảm bảo file manifest.json không bị thay đổi sau khi ký
- Đảm bảo signature.sig không bị hỏng

### Test Key Pair Match

```bash
# Tạo test file
echo "test" > test.txt

# Sign với private key
openssl dgst -sha256 -sign private_key.pem -out test.sig test.txt

# Verify với public key
openssl dgst -sha256 -verify public_key.pem -signature test.sig test.txt

# Nếu output "Verified OK" thì key pair khớp
```

## Best Practices

1. **Key Size**: Sử dụng ít nhất 2048-bit, khuyến nghị 4096-bit cho bảo mật cao
2. **Hash Algorithm**: Sử dụng SHA256 trở lên (SHA1 đã lỗi thời)
3. **Key Storage**: 
   - Private key: Lưu ở nơi an toàn, không copy lên target device
   - Public key: Có thể public, nhưng cần đảm bảo integrity
4. **Key Rotation**: Định kỳ thay đổi key pair
5. **Backup**: Backup private key ở nơi an toàn (encrypted)

## Security Notes

⚠️ **QUAN TRỌNG**:
- **KHÔNG BAO GIỜ** chia sẻ private key
- **KHÔNG BAO GIỜ** copy private key lên target device
- Private key chỉ dùng trên build server
- Public key có thể deploy lên target device
- Sử dụng key management system trong production

