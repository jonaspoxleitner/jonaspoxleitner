/* Scroll-linked button shimmer for touch devices: the button nearest the
 * viewport's vertical centre wears the hover wash, handing it off to the next
 * one as it scrolls past. Only active where the magnetic effect is not
 * (coarse pointers) and never under prefers-reduced-motion. */
(() => {
    if (!matchMedia("(pointer: coarse)").matches) return;
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const buttons = [...document.querySelectorAll(".button")];
    if (buttons.length === 0) return;

    const LIT_CLASS = "button--lit";
    let lit = null;
    let scheduled = false;

    function update() {
        scheduled = false;

        const centre = innerHeight / 2;
        let closest = null;
        let closestDistance = Infinity;

        for (const button of buttons) {
            const rect = button.getBoundingClientRect();
            if (rect.bottom < 0 || rect.top > innerHeight) continue;
            const distance = Math.abs(rect.top + rect.height / 2 - centre);
            if (distance < closestDistance) {
                closestDistance = distance;
                closest = button;
            }
        }

        if (closest === lit) return;
        if (lit) lit.classList.remove(LIT_CLASS);
        if (closest) closest.classList.add(LIT_CLASS);
        lit = closest;
    }

    function schedule() {
        if (scheduled) return;
        scheduled = true;
        requestAnimationFrame(update);
    }

    addEventListener("scroll", schedule, { passive: true });
    addEventListener("resize", schedule, { passive: true });
    update();
})();
