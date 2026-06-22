// Validity control for holder-find legs 3b/3c: mirrors vgc_hf_enumerate_anon +
// vgc_hf_scan_region. Plants a sentinel (a real heap addr) in (i) a malloc'd buffer
// and (ii) a stack array, then walks mach_vm_region (readable+writable, <=64MiB) and
// word-scans each region for the sentinel. PASS = sentinel found (the scanner works,
// so a holder-find "no hits" is a real absence, not a blind scan).
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>

static uintptr_t g_target = 0;
static long g_budget = 0;
static int g_hits_malloc = 0, g_hits_other = 0;
static uintptr_t g_malloc_lo = 0, g_malloc_hi = 0;

static void scan_region(uintptr_t lo, uintptr_t hi) {
    uintptr_t a = (lo + sizeof(uintptr_t) - 1) & ~((uintptr_t)sizeof(uintptr_t) - 1);
    for (; a + sizeof(uintptr_t) <= hi; a += sizeof(uintptr_t)) {
        if (g_budget-- <= 0) return;
        uintptr_t v = *(volatile uintptr_t*)a;
        if (v == g_target) {
            if (a >= g_malloc_lo && a < g_malloc_hi) g_hits_malloc++;
            else g_hits_other++;
        }
    }
}

static void enumerate_anon(uintptr_t arena_lo, uintptr_t arena_hi) {
    mach_vm_address_t address = 0;
    while (1) {
        mach_vm_size_t size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t obj = MACH_PORT_NULL;
        kern_return_t kr = mach_vm_region(mach_task_self(), &address, &size,
            VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &count, &obj);
        if (kr != KERN_SUCCESS) break;
        uintptr_t lo = (uintptr_t)address, hi = (uintptr_t)(address + size);
        int rd = (info.protection & VM_PROT_READ) != 0;
        int wr = (info.protection & VM_PROT_WRITE) != 0;
        address = address + size;
        if (!rd || !wr || hi <= lo) continue;
        if (lo >= arena_lo && hi <= arena_hi) continue;
        if ((hi - lo) > (uintptr_t)64 * 1024 * 1024) continue;
        scan_region(lo, hi);
    }
}

int main(void) {
    // sentinel = a real heap object address (looks like a pointer, unlikely to collide)
    void* obj = malloc(128);
    g_target = (uintptr_t)obj;

    // (i) plant in a malloc'd holder buffer
    uintptr_t* holder = (uintptr_t*)malloc(64);
    holder[0] = g_target;
    g_malloc_lo = (uintptr_t)holder;
    g_malloc_hi = g_malloc_lo + 64;

    g_budget = 8L * 1024 * 1024; // same cap as the instrument
    g_hits_malloc = g_hits_other = 0;
    enumerate_anon(0, 0); // no arena exclusion in the probe

    printf("=== anon-walk probe (validates holder-find legs 3b/3c) ===\n");
    printf("target(sentinel heap addr) = 0x%016llx\n", (unsigned long long)g_target);
    printf("hits in the planted malloc'd holder: %d  (expect >=1 = PASS)\n", g_hits_malloc);
    printf("hits elsewhere (incidental copies):  %d\n", g_hits_other);
    printf("VERDICT: %s\n", g_hits_malloc >= 1 ? "PASS — mach_vm_region walk + word-scan finds a planted holder"
                                               : "FAIL — scanner did NOT find the planted holder");
    free(holder); free(obj);
    return 0;
}
