# HANDOFF TICKET: High-Velocity Glass & 3D Cinematic Emblems

**Target Agent:** Codex (Frontend / UI Implementer)
**From:** Antigravity (QA/Verification) & Human-Ops (Scott)
**Domain:** `public/index.html` (and any necessary Three.js/WebGL scripts)
**Status:** 🟢 APPROVED TO BEGIN

---

## 🎬 1. The Genie's Vision (The Goal)
The CV chatbot bridge is active and stable. We are now pivoting maximum focus to the **Frontend UI** to create a Fortune 100 level "first impression". 

We need to upgrade the static `.project-emblem` images in the `public/index.html` file into **True 3D Cinematic Planes** using the "High-Velocity Glass" design pattern. When the user scrolls, these emblems shouldn't just move—they should leave a cinematic, visual trace (motion blur/light trail) inside a WebGL canvas.

## 🧠 2. Codex Implementation Instructions
You are to use your specialized frontend skills to implement the following:

1. **Single Shared WebGL Canvas (CRITICAL QA CALL):** You MUST use ONE shared WebGL scene/canvas (e.g., `#hero-three` or a full-page overlay) for all items to pass the 60fps performance gate. Do NOT instantiate a separate `<canvas>` on every `.project-card`.
2. **Strict File Scoping:** There are two HTML files in the repo structure. You are ONLY authorized to edit `public/index.html`. Do not touch the root `index.html`.
3. **True 3D Planes:** Convert the static `/sir-travis-emblem.png` and `/seatrace-logo-alt.png` images from standard `<img />` tags into 3D textures mapped onto rotating, interactive planes inside the shared canvas.
3. **High-Velocity Glass Effect:** Implement a custom shader or CSS 3D transform that triggers a visual "tracer" or "motion blur" effect tied directly to the user's scroll velocity. As they scroll faster, the emblem's light sweeps and stretches.
4. **Cinematic Hover State:** When a user hovers over the project card, the emblem should smoothly transition into a focused, floating 3D state with dynamic drop-shadows (as hinted in the previous CSS, but executed natively in 3D).

*If you get stuck on the math for the scroll-velocity shader, you are authorized to use your Gemini (Genie) API coding tools to generate the exact GLSL shader code.*

## 🛡️ 3. Antigravity's QA Gates (Acceptance Criteria)
As the Antigravity agent, I will be verifying your work against the following strict constraints. **Do not claim completion until these are met:**

- [ ] **Performance (60 FPS):** The WebGL canvas must not tank the browser. Scroll performance must remain silky smooth. 
- [ ] **Graceful Degradation:** If WebGL fails to load or the user is on a low-battery mobile device, the UI must gracefully fall back to the existing pure CSS static emblems.
- [ ] **No Cross-Lane Bleed:** Do NOT edit `chat.ts` or any backend APIs. Your strict boundary is `public/index.html` and its associated visual assets.
- [ ] **Visual Trace Verified:** The scrolling tracer effect must be visual and apparent, not just a standard CSS translation.

---
**Codex:** Once you have read this, begin implementing the WebGL glass effects in `public/index.html`. Run your local tests, and when you are confident it passes the Antigravity Gates, log your commit and report back to the Master.
