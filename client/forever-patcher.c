// forever-patcher.c — macOS port of the Forever Launcher's key-store patch. v3
//
// Injected via DYLD_INSERT_LIBRARIES into the (ad-hoc re-signed) WoW beta client.
// The client builds a store of 12 region-group entries (40 bytes each:
// [u32 id 1..12][32-byte Ed25519 key][flag][3 pad]) at boot AND REBUILDS it
// during login. We replace entry 8's key with our server's public key.
//
// v3: STRICT validation — we only ever write 32 bytes at entry 8 of a block
// whose ids are 1..12 AND whose entry-8 key is EXACTLY Blizzard's known key
// (or already ours). No structural-only matches. Live-memory write.

#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

// stock region-group-8 key (unchanged in build 70338 — verified live)
static const unsigned char SLOT8_ORIGINAL[32] = {
    0x1F,0xD6,0xDD,0x8F,0xA0,0xEC,0x30,0xD3,0x9E,0x3F,0x72,0xE7,0x55,0xB8,0xA0,0x45,
    0xBD,0xE0,0xF7,0x04,0x49,0xDC,0x71,0x00,0x8B,0x76,0x7C,0x2E,0xAA,0x89,0xFB,0x9F
};
// TrinityCore EnterEncryptedMode public key (our server's signing key)
static const unsigned char NEW_KEY[32] = {
    0x02,0x59,0x6F,0x0D,0x0C,0x06,0x1A,0x8B,0x30,0x74,0x59,0x88,0xFD,0x72,0xC5,0x9E,
    0x29,0xEC,0x36,0x7F,0xB0,0xF3,0x41,0xF2,0x8E,0x0F,0x08,0xD0,0x37,0xBA,0xFC,0x69
};

#define ENTRY_SIZE 40
#define ENTRY_COUNT 12
#define BLOCK_SIZE (ENTRY_SIZE * ENTRY_COUNT)
#define TARGET_INDEX 7 // entry 8, 0-based

static FILE *g_log;
static void logf_(const char *fmt, ...) {
    if (!g_log) return;
    va_list ap; va_start(ap, fmt);
    vfprintf(g_log, fmt, ap);
    fflush(g_log);
    va_end(ap);
}

static int g_writes = 0;

// strict: full structure + entry-8 key must be Blizzard's or ours
static int is_store(unsigned char const *b) {
    for (int e = 0; e < ENTRY_COUNT; e++) {
        unsigned int id;
        memcpy(&id, b + e * ENTRY_SIZE, 4);
        if (id != (unsigned int)(e + 1))
            return 0;
        if (b[e * ENTRY_SIZE + 36] > 1)
            return 0;
        unsigned char pad0 = b[e * ENTRY_SIZE + 37];
        if (pad0 != 0x00 && pad0 != 0x7f)
            return 0;
        if (b[e * ENTRY_SIZE + 38] | b[e * ENTRY_SIZE + 39])
            return 0;
    }
    unsigned char const *slot = b + TARGET_INDEX * ENTRY_SIZE + 4;
    return memcmp(slot, SLOT8_ORIGINAL, 32) == 0 || memcmp(slot, NEW_KEY, 32) == 0;
}

static void try_patch(unsigned char const *copy, unsigned long long real_addr) {
    if (!is_store(copy))
        return;
    unsigned char const *slot = copy + TARGET_INDEX * ENTRY_SIZE + 4;
    if (memcmp(slot, NEW_KEY, 32) == 0)
        return; // already ours
    unsigned char *live = (unsigned char *)(uintptr_t)(real_addr + TARGET_INDEX * ENTRY_SIZE + 4);
    memcpy(live, NEW_KEY, 32);
    logf_("PATCHED store @0x%llx (total %d)\n", real_addr, ++g_writes);
}

static void scan_once(void) {
    task_t task = mach_task_self();
    mach_vm_address_t addr = 0;
    mach_vm_size_t size = 0;
    while (1) {
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object_name;
        kern_return_t kr = mach_vm_region(task, &addr, &size, VM_REGION_BASIC_INFO_64,
                                          (vm_region_info_t)&info, &count, &object_name);
        if (kr != KERN_SUCCESS)
            break;
        if ((info.protection & VM_PROT_WRITE) && size >= BLOCK_SIZE) {
            mach_vm_size_t chunk = 16 * 1024 * 1024;
            for (mach_vm_offset_t off = 0; off + BLOCK_SIZE <= size; off += chunk - BLOCK_SIZE) {
                mach_vm_size_t take = size - off < chunk ? size - off : chunk;
                if (take < BLOCK_SIZE) break;
                mach_vm_address_t bufaddr = 0;
                mach_msg_type_number_t bufcnt = 0;
                if (mach_vm_read(task, addr + off, take, (vm_offset_t *)&bufaddr, &bufcnt) != KERN_SUCCESS)
                    break;
                unsigned char const *buf = (unsigned char const *)(uintptr_t)bufaddr;
                // cheap first filter: the 9th id field (index 7, offset 7*40) of a
                // store holds u32 8 AND 4 bytes later begins Blizzard's key (0x1F 0xD6...)
                for (mach_vm_size_t i = 0; i + BLOCK_SIZE <= bufcnt; i += 4) {
                    if (buf[i + TARGET_INDEX * ENTRY_SIZE + 4] == 0x1F &&
                        buf[i + TARGET_INDEX * ENTRY_SIZE + 5] == 0xD6)
                        try_patch(buf + i, (unsigned long long)(addr + off + i));
                }
                mach_vm_deallocate(task, bufaddr, bufcnt);
                if (take < chunk) break;
            }
        }
        addr += size;
    }
}

static void *watcher(void *arg) {
    (void)arg;
    for (;;) {
        scan_once();
        usleep(100 * 1000); // fast: the client rebuilds the store during login
    }
    return NULL;
}

__attribute__((constructor))
static void init(void) {
    g_log = fopen("/tmp/forever-patcher.log", "a");
    logf_("=== forever-patcher v3 loaded (pid %d) ===\n", getpid());
    pthread_t t;
    pthread_create(&t, NULL, watcher, NULL);
    pthread_detach(t);
}
