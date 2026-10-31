#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <zlib.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    uLongf destLen;
    unsigned char *dest;

    if (size > (1u << 20)) return 0;
    destLen = 1u << 16;
    dest = (unsigned char *)malloc(destLen);
    if (!dest) return 0;
    uncompress(dest, &destLen, data, (uLong)size);
    free(dest);
    return 0;
}
