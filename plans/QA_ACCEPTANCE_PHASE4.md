# QA Acceptance Spec: Phase 4 (High-Velocity Glass)

**Agent:** Antigravity (Lane 3)
**Target Branch:** `feat/phase4-high-velocity-glass`
**Target Commit:** `cd22146` (Codex #2)
**Objective:** Verify Codex #2's frontend WebGL implementation before Scott approves the merge into `main`.

---

## 🚦 Mandatory QA Gates

### 1. The 60FPS Performance Gate
- [ ] **Scroll Stress Test:** Rapidly scroll up and down the viewport. The Motion Trace shader must execute gracefully without causing DOM layout thrashing, locking up, or stuttering.
- [ ] **Canvas Integrity:** Inspect the DOM to verify that a **Single Shared WebGL Canvas** is being used to render the emblems (e.g. within `#hero-three` or a global background layer). If multiple `<canvas>` tags were instantiated per project card, this branch fails.

### 2. The WebGL Loss / Fallback Gate
- [ ] **Graceful Degradation:** Force WebGL context loss (or disable JavaScript). The UI MUST revert immediately to stable, static `<img>` DOM elements without leaving empty missing-texture black holes.
- [ ] **Mobile Responsiveness:** View the layout at mobile width (`< 768px`). Verify that the WebGL canvas doesn't break horizontal scrolling or overflow the viewport width.

### 3. Visual & Asset Fidelity
- [ ] **Trace Intensity:** Ensure the Y-axis scroll velocity shader provides an actual cinematic "glass" light streak (as scoped), avoiding over-exposure or visual artifacting.
- [ ] **Alignment:** The 3D emblem planes must correctly overlay, target, or align with their respective project cards when dynamically rendered.
- [ ] **Asset Quality:** Verify that PNG/SVG image textures cleanly render their alpha transparencies against the WebGL background, without rendering ugly black borders (no improperly formatted JPG textures).

### 4. Zero-Regression Gate
- [ ] **Chat UI Integrity:** Verify that the complex WebGL canvas hasn't broken the `z-index` stacking over the Chat UI or blocked `pointer-events`. The Phase C chatbot must remain perfectly clickable and interactive.
- [ ] **DOM Cleanliness:** Ensure that any placeholder strings or stubbed out HTML comments `<!-- ... -->` Codex identified were resolved cleanly.

---

## 📝 Verdict & Next Steps
- **If ANY gate fails:** Provide the failure log to `AGENT_HANDOFFS.md`. Codex #2 is authorized to submit ONE follow-up visual tuning commit to this branch.
- **If ALL gates pass:** Antigravity signs off. Claude Code finalizes `PRD_RobertoScottCV_ProductionPath.md`, and Scott merges `feat/phase4-high-velocity-glass` into `main`.
