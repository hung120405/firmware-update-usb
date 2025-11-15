/*
 * flash_updater.c
 * 
 * Chương trình ghi firmware vào flash partition
 * 
 * Usage: flash_updater <firmware_path> <flash_partition_path>
 * 
 * Ví dụ: flash_updater firmware.img /dev/mtdblock1
 */

#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <stdint.h>

/* MTD erase ioctl definitions (nếu không có mtd-utils.h) */
#ifndef MEMERASE
#define MEMERASE _IOW('M', 2, struct erase_info_user)
struct erase_info_user {
    uint32_t start;
    uint32_t length;
};
#endif

/* Kích thước buffer để đọc/ghi (4KB) */
#define BUFFER_SIZE (4 * 1024)

/* Hàm in lỗi và thoát */
static void error_exit(const char *message) {
    fprintf(stderr, "ERROR: %s", message);
    if (errno != 0) {
        fprintf(stderr, ": %s", strerror(errno));
    }
    fprintf(stderr, "\n");
    exit(1);
}

/* Hàm erase flash partition (cho MTD devices) */
static int erase_flash_partition(const char *partition_path) {
    int fd;
    struct stat st;
    struct erase_info_user erase_info;
    uint64_t partition_size;
    
    /* Kiểm tra xem có phải là MTD device không */
    if (strncmp(partition_path, "/dev/mtd", 8) != 0) {
        /* Không phải MTD device, bỏ qua erase */
        fprintf(stderr, "INFO: Not an MTD device, skipping erase\n");
        return 0;
    }
    
    /* Mở partition để erase */
    fd = open(partition_path, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "WARNING: Cannot open partition for erase: %s\n", strerror(errno));
        return -1;
    }
    
    /* Lấy kích thước partition */
    if (fstat(fd, &st) < 0) {
        close(fd);
        fprintf(stderr, "WARNING: Cannot get partition size: %s\n", strerror(errno));
        return -1;
    }
    
    partition_size = st.st_size;
    
    /* Erase toàn bộ partition */
    erase_info.start = 0;
    erase_info.length = (uint32_t)partition_size;
    
    fprintf(stderr, "INFO: Erasing flash partition (size: %lu bytes)...\n", 
            (unsigned long)partition_size);
    
    if (ioctl(fd, MEMERASE, &erase_info) < 0) {
        close(fd);
        fprintf(stderr, "WARNING: Erase failed: %s (continuing anyway)\n", strerror(errno));
        return -1;
    }
    
    close(fd);
    fprintf(stderr, "INFO: Flash partition erased successfully\n");
    return 0;
}

/* Hàm chính */
int main(int argc, char *argv[]) {
    FILE *firmware_file = NULL;
    FILE *flash_partition = NULL;
    char *firmware_path;
    char *flash_partition_path;
    char *buffer = NULL;
    size_t bytes_read;
    size_t bytes_written;
    size_t total_bytes = 0;
    struct stat st;
    uint64_t firmware_size;
    
    /* Kiểm tra số lượng tham số */
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <firmware_path> <flash_partition_path>\n", argv[0]);
        fprintf(stderr, "Example: %s firmware.img /dev/mtdblock1\n", argv[0]);
        exit(1);
    }
    
    firmware_path = argv[1];
    flash_partition_path = argv[2];
    
    /* Kiểm tra file firmware tồn tại */
    if (stat(firmware_path, &st) < 0) {
        error_exit("Cannot access firmware file");
    }
    
    firmware_size = st.st_size;
    fprintf(stderr, "INFO: Firmware size: %lu bytes\n", (unsigned long)firmware_size);
    
    /* Erase flash partition trước khi ghi (nếu là MTD device) */
    erase_flash_partition(flash_partition_path);
    
    /* Mở file firmware ở chế độ read binary */
    firmware_file = fopen(firmware_path, "rb");
    if (firmware_file == NULL) {
        error_exit("Cannot open firmware file for reading");
    }
    
    /* Mở flash partition ở chế độ write binary */
    flash_partition = fopen(flash_partition_path, "wb");
    if (flash_partition == NULL) {
        fclose(firmware_file);
        error_exit("Cannot open flash partition for writing");
    }
    
    /* Cấp phát buffer */
    buffer = (char *)malloc(BUFFER_SIZE);
    if (buffer == NULL) {
        fclose(firmware_file);
        fclose(flash_partition);
        error_exit("Cannot allocate memory for buffer");
    }
    
    /* Đọc và ghi dữ liệu theo khối */
    fprintf(stderr, "INFO: Writing firmware to flash partition...\n");
    
    while ((bytes_read = fread(buffer, 1, BUFFER_SIZE, firmware_file)) > 0) {
        bytes_written = fwrite(buffer, 1, bytes_read, flash_partition);
        
        if (bytes_written != bytes_read) {
            free(buffer);
            fclose(firmware_file);
            fclose(flash_partition);
            error_exit("Write error: bytes written != bytes read");
        }
        
        total_bytes += bytes_written;
        
        /* In progress (mỗi 1MB) */
        if (total_bytes % (1024 * 1024) == 0) {
            fprintf(stderr, "INFO: Written %lu bytes...\n", (unsigned long)total_bytes);
        }
    }
    
    /* Kiểm tra lỗi đọc */
    if (ferror(firmware_file)) {
        free(buffer);
        fclose(firmware_file);
        fclose(flash_partition);
        error_exit("Error reading firmware file");
    }
    
    /* Đảm bảo dữ liệu được flush vào flash */
    if (fflush(flash_partition) != 0) {
        free(buffer);
        fclose(firmware_file);
        fclose(flash_partition);
        error_exit("Error flushing data to flash");
    }
    
    /* Sync để đảm bảo dữ liệu được ghi vào storage */
    if (fsync(fileno(flash_partition)) < 0) {
        fprintf(stderr, "WARNING: fsync failed: %s\n", strerror(errno));
        /* Không exit vì có thể vẫn thành công */
    }
    
    /* Giải phóng tài nguyên */
    free(buffer);
    fclose(firmware_file);
    fclose(flash_partition);
    
    /* In thông báo thành công */
    fprintf(stdout, "Ghi thành công\n");
    fprintf(stderr, "INFO: Total bytes written: %lu\n", (unsigned long)total_bytes);
    
    return 0;
}

