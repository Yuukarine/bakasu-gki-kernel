# Patch-source manifest

Patch-only features live here as metadata, not fabricated Kconfig symbols. Each CI matrix entry must resolve a public source/ref and record the applied SHA before build.

Expected source labels include: `bakasu`, `susfs-v2.4.0`, `nomount`, `unicode-bypass-fix`, `faster-sdp-900ma`, `ptrace-leak-fix`, `bore`, and `amneziawg`.

A patch is applied only when its matrix condition matches. No custom SELinux/DeviceTree C patch is accepted.
