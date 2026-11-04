/* Magnetic buttons: elements lean toward the cursor inside a small radius and
 * spring back once it leaves. Only active for precise pointers (mouse, no
 * touch) and never under prefers-reduced-motion. */
(() => {
    if (!matchMedia("(pointer: fine)").matches) return;
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const RADIUS = 70;      // px, measured from the element's centre
    const STRENGTH = 0.18;  // fraction of the cursor distance the element travels
    const MAX_OFFSET = 5;   // px cap, so buttons never leave their neighbours
    const LERP = 0.15;      // easing factor per frame

    const items = new Map();
    for (const el of document.querySelectorAll(".button")) {
        items.set(el, { x: 0, y: 0, tx: 0, ty: 0 });
    }
    if (items.size === 0) return;

    let pointer = null;
    let running = false;

    const clamp = (value) => Math.max(-MAX_OFFSET, Math.min(MAX_OFFSET, value));

    addEventListener("pointermove", (event) => {
        pointer = event;
        for (const [el, s] of items) {
            const rect = el.getBoundingClientRect();
            const dx = event.clientX - (rect.left + rect.width / 2);
            const dy = event.clientY - (rect.top + rect.height / 2);
            const falloff = Math.max(0, 1 - Math.hypot(dx, dy) / RADIUS);
            s.tx = clamp(dx * STRENGTH * falloff);
            s.ty = clamp(dy * STRENGTH * falloff);
        }
        if (!running) {
            running = true;
            requestAnimationFrame(tick);
        }
    }, { passive: true });

    document.addEventListener("pointerleave", () => {
        pointer = null;
        for (const s of items.values()) {
            s.tx = 0;
            s.ty = 0;
        }
        if (!running) {
            running = true;
            requestAnimationFrame(tick);
        }
    });

    function tick() {
        let settled = true;
        for (const [el, s] of items) {
            s.x += (s.tx - s.x) * LERP;
            s.y += (s.ty - s.y) * LERP;
            if (Math.abs(s.x) > 0.05 || Math.abs(s.y) > 0.05) settled = false;
            el.style.transform = `translate3d(${s.x.toFixed(2)}px, ${s.y.toFixed(2)}px, 0)`;
        }
        // Keep animating while anything moves, or while a cursor is still
        // around to move things. Otherwise sleep until the next pointermove.
        if (settled && pointer === null) {
            for (const el of items.keys()) el.style.transform = "";
            running = false;
            return;
        }
        requestAnimationFrame(tick);
    }
})();
