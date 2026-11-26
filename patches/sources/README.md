# Patch-source manifest

Patch-only features live here as metadata, not fabricated Kconfig symbols. Each CI matrix entry resolves the declared public source/ref and records its immutable remote SHA before build. Local `*.patch` files, when present, are then applied in lexical order.

Expected source labels include: `bakasu`, `susfs-v2.4.0`, `unicode-bypass-fix`, `faster-sdp-900ma`, `ptrace-leak-fix`, `bore`, and `amneziawg`.

A patch source is selected only when its matrix condition matches. Missing local patches are not silently treated as success: the log records `source-verified-no-local-patch` so the checked-out source must already contain that upstream integration. No custom SELinux/DeviceTree C patch is accepted.
