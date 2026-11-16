/*
 * Critical Ops – Skin Changer Dylib
 * Local-only visual swap via il2cpp hook
 */

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-function"

#include <substrate.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <objc/runtime.h>
#include <Foundation/Foundation.h>
#include <unordered_map>

// ─── il2cpp type stubs ───────────────────────────────────────────────────────

typedef struct Il2CppObject {
    void* klass;
    void* monitor;
} Il2CppObject;

typedef struct Il2CppString {
    Il2CppObject obj;
    int32_t length;
    uint16_t chars[1];
} Il2CppString;

typedef struct Il2CppArray {
    Il2CppObject obj;
    void*        bounds;
    uintptr_t    max_length;
    void*        vector[1];
} Il2CppArray;

// ─── RVAs from dump (GameAssembly.dylib) ─────────────────────────────────────

#define RVA_Renderer_set_sharedMaterials   0x2d940a8
#define RVA_Renderer_get_sharedMaterials   0x2d940a4
#define RVA_Object_get_name                0x2dcbabc
#define RVA_Component_get_gameObject       0x2dc3494
#define RVA_Transform_get_parent           0x2dd4db0
#define RVA_Resources_Load                 0x2dbd6fc
#define RVA_AssetBundle_LoadAsset          0x2d628c0

// ─── Function pointer types ───────────────────────────────────────────────────

typedef void          (*fn_set_sharedMaterials)(Il2CppObject* renderer, Il2CppArray* mats, Il2CppObject* method);
typedef Il2CppArray*  (*fn_get_sharedMaterials)(Il2CppObject* renderer, Il2CppObject* method);
typedef Il2CppString* (*fn_get_name)            (Il2CppObject* obj,      Il2CppObject* method);
typedef Il2CppObject* (*fn_get_gameObject)      (Il2CppObject* comp,     Il2CppObject* method);
typedef Il2CppObject* (*fn_get_parent)          (Il2CppObject* transform,Il2CppObject* method);
typedef Il2CppObject* (*fn_resources_load)      (Il2CppString* path,     Il2CppObject* type,   Il2CppObject* method);

static fn_set_sharedMaterials orig_set_sharedMaterials = nullptr;
static fn_get_sharedMaterials orig_get_sharedMaterials = nullptr;
static fn_get_name            orig_get_name            = nullptr;
static fn_get_gameObject      orig_get_gameObject      = nullptr;
static fn_get_parent          orig_get_parent          = nullptr;

// ─── Helpers ─────────────────────────────────────────────────────────────────

static uintptr_t s_base = 0;

static uintptr_t rva(uintptr_t offset) {
    return s_base + offset;
}

static NSString* il2cpp_to_nsstring(Il2CppString* s) {
    if (!s || s->length <= 0 || s->length > 512) return nil;
    return [NSString stringWithCharacters:(const unichar*)s->chars length:s->length];
}

static uintptr_t find_gameassembly_base() {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "GameAssembly")) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

// ─── Skin config ─────────────────────────────────────────────────────────────

struct SkinOverride {
    const char* nameFragment;
    int         materialIndex;
    bool        viewOnly;
};

static const SkinOverride kSkinOverrides[] = {
    { "weapon_ak47",   1, true },
    { "weapon_m4a1",   1, true },
    { "weapon_awp",    1, true },
    { "weapon_deagle", 1, true },
    { "weapon_knife",  1, true },
    { "weapon_glock",  1, true },
    { "weapon_mp5",    1, true },
    { "weapon_sg553",  1, true },
    { nullptr, 0, false }
};

static std::unordered_map<uintptr_t, Il2CppObject*> s_matCache;

// ─── Hook: Renderer.set_sharedMaterials ──────────────────────────────────────

static void hook_set_sharedMaterials(Il2CppObject* renderer,
                                     Il2CppArray*  mats,
                                     Il2CppObject* method) {
    if (!renderer || !mats) {
        orig_set_sharedMaterials(renderer, mats, method);
        return;
    }

    Il2CppString* nameStr = orig_get_name(renderer, nullptr);
    NSString* name = il2cpp_to_nsstring(nameStr);

    if (!name) {
        orig_set_sharedMaterials(renderer, mats, method);
        return;
    }

    for (int i = 0; kSkinOverrides[i].nameFragment != nullptr; i++) {
        const SkinOverride& ov = kSkinOverrides[i];

        bool nameMatch = [name containsString:@(ov.nameFragment)];
        if (!nameMatch) continue;

        if (ov.viewOnly) {
            bool isView = [name containsString:@"_view"];
            if (!isView) continue;
        }

        uintptr_t arrayLen = mats->max_length;
        int targetIdx = ov.materialIndex;
        if (targetIdx < 0 || (uintptr_t)targetIdx >= arrayLen) {
            break;
        }

        Il2CppObject* targetMat = (Il2CppObject*)mats->vector[targetIdx];
        if (!targetMat) break;

        Il2CppObject* originalSlot0 = (Il2CppObject*)mats->vector[0];
        mats->vector[0] = targetMat;
        mats->vector[targetIdx] = originalSlot0;

        orig_set_sharedMaterials(renderer, mats, method);

        mats->vector[0] = originalSlot0;
        mats->vector[targetIdx] = targetMat;
        return;
    }

    orig_set_sharedMaterials(renderer, mats, method);
}

// ─── Initialiser ─────────────────────────────────────────────────────────────

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        s_base = find_gameassembly_base();
        if (!s_base) {
            NSLog(@"[COPSSkin] ERROR: GameAssembly.dylib not found");
            return;
        }
        NSLog(@"[COPSSkin] GameAssembly base: 0x%lx", s_base);

        void* target = (void*)rva(RVA_Renderer_set_sharedMaterials);
        MSHookFunction(target,
                       (void*)hook_set_sharedMaterials,
                       (void**)&orig_set_sharedMaterials);

        NSLog(@"[COPSSkin] Hook installed @ %p", target);
    });
}

#pragma clang diagnostic pop
