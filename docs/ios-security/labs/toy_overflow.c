#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static volatile int sink;

/* Teaching bug: the copy length and the later read use the input size,
   while the allocation uses a different field from the same input.
   Built only so AddressSanitizer can show a heap-buffer-overflow. */
static void parse(const uint8_t *data, size_t size) {
    uint32_t n;
    uint32_t i;
    int sum;
    char *buf;

    if (size < 4) return;
    memcpy(&n, data, 4);
    if (n > 64) n = 64;
    buf = (char *)malloc((size_t)n + 1);
    if (!buf) return;
    memcpy(buf, data + 4, size - 4);
    sum = 0;
    for (i = 0; i < n + 8; i++) sum += (unsigned char)buf[i];
    sink = sum;
    free(buf);
}

#ifdef TOY_FUZZ
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    parse(data, size);
    return 0;
}
#else
int main(void) {
    uint8_t input[12] = {0};
    parse(input, sizeof input);
    printf("no crash sink=%d\n", sink);
    return 0;
}
#endif
