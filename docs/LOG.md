# Build log

Newest at the top. One entry per slot. What shipped, what broke, what the reader did.

## 2026-09-06 — Day 0

**Shipped.** The whole skeleton: model, reader, two parsers, look, table, import, detail, seed path, fixtures, scripts, playbook, ADRs. Linear project created. Repo pushed.

**Reader.** Vision read 9–10 lines per fixture. Foundation Models reported `.available` and then failed all four calls with `GenerationError -1` wrapping `ModelManagerServices.ModelManagerError 1026`. Heuristics filed all four at 100% confidence: The Brutalist / Embassy Theatre / H12; Perfect Days / Lighthouse Cinema Cuba / F7; Dune Part Two / The Roxy Cinema / D4; Past Lives / Penthouse Cinema / K9.

**Broke and fixed.** Fonts with `[wght]` in the filename did not register from `UIAppFonts` (renamed). The misregistered plate rendered grey because the inner `foregroundStyle` won (now `DisplayTitle` draws both passes explicitly). Two-column table overflowed the screen because `scaledToFill` images had no width constraint (now `Color.clear.overlay`). Metal toolchain catalog fetch failed twice before succeeding.

**For Bruno.** Check System Settings → Apple Intelligence & Siri is on and the model has finished downloading; error 1026 from ModelManager on the simulator is usually the host's model assets. Once the model answers, the seed log will show `by foundation-models`.

**Still rough.** Cards show the table around the stub (crop is Day 1). Import screen says "On-device model ready" when it is not (Day 1). Metal shaders compiled but not active (Day 1).
