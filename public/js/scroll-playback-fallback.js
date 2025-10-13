/**
 * Scroll playback fallback helper.
 *
 * Some mobile browsers (notably Safari on iOS) fail to reliably trigger media
 * playback when the active slide changes while the user is scrolling. To make
 * the behaviour more deterministic we retry playback once the scroll action is
 * considered finished. The helper listens for the `scrollend` event when
 * available and falls back to a debounced `scroll` handler otherwise.
 */
const DEFAULT_SCROLL_STOP_DELAY = 180; // ms
const DEFAULT_SECOND_PLAY_DELAY = 220; // ms
const MAX_ATTEMPTS = 2;

const toArray = (value) => {
    if (!value) {
        return [];
    }
    return Array.isArray(value) ? value : [value];
};

const attemptPlay = (player, attempt = 0, delay = DEFAULT_SECOND_PLAY_DELAY) => {
    if (!player || typeof player.play !== "function") {
        return;
    }

    const scheduleRetry = () => {
        if (attempt + 1 >= MAX_ATTEMPTS) {
            return;
        }
        window.setTimeout(() => {
            attemptPlay(player, attempt + 1, delay);
        }, delay);
    };

    try {
        const result = player.play();
        if (result && typeof result.then === "function") {
            result.then(scheduleRetry).catch(scheduleRetry);
        } else {
            scheduleRetry();
        }
    } catch (error) {
        scheduleRetry();
    }
};

const runPlayback = (players, delay) => {
    toArray(players).forEach((player) => {
        attemptPlay(player, 0, delay);
    });
};

/**
 * Attach fallback behaviour to a scroll container.
 *
 * @param {Object} options configuration options
 * @param {HTMLElement|Document|Window} [options.scrollContainer=document]
 *   Element that emits scroll events. Defaults to the document.
 * @param {function(): (HTMLMediaElement|HTMLMediaElement[])} options.getPlayers
 *   Function returning the media element(s) that need to be played.
 * @param {number} [options.scrollStopDelay=DEFAULT_SCROLL_STOP_DELAY]
 *   Debounce delay used to infer the end of scrolling when `scrollend`
 *   is not supported.
 * @param {number} [options.secondPlayDelay=DEFAULT_SECOND_PLAY_DELAY]
 *   Delay before attempting the fallback play.
 * @returns {function(): void} cleanup function removing the listeners
 */
export function installScrollPlaybackFallback({
    scrollContainer = document,
    getPlayers,
    scrollStopDelay = DEFAULT_SCROLL_STOP_DELAY,
    secondPlayDelay = DEFAULT_SECOND_PLAY_DELAY
} = {}) {
    if (typeof getPlayers !== "function") {
        throw new TypeError("installScrollPlaybackFallback requires getPlayers()");
    }

    const container = scrollContainer || document;
    let scrollTimeoutId = null;

    const triggerPlayback = () => {
        const players = getPlayers();
        if (!players) {
            return;
        }
        runPlayback(players, secondPlayDelay);
    };

    const scheduleScrollEndFallback = () => {
        if (scrollTimeoutId) {
            window.clearTimeout(scrollTimeoutId);
        }
        scrollTimeoutId = window.setTimeout(triggerPlayback, scrollStopDelay);
    };

    const onScroll = () => {
        scheduleScrollEndFallback();
    };

    const onScrollEnd = () => {
        if (scrollTimeoutId) {
            window.clearTimeout(scrollTimeoutId);
            scrollTimeoutId = null;
        }
        triggerPlayback();
    };

    const onPointerRelease = () => {
        scheduleScrollEndFallback();
    };

    container.addEventListener("scroll", onScroll, { passive: true });

    if ("onscrollend" in window) {
        container.addEventListener("scrollend", onScrollEnd, { passive: true });
    }

    container.addEventListener("touchend", onPointerRelease, { passive: true });
    container.addEventListener("pointerup", onPointerRelease, { passive: true });
    container.addEventListener("mouseup", onPointerRelease, { passive: true });

    return () => {
        container.removeEventListener("scroll", onScroll);

        if ("onscrollend" in window) {
            container.removeEventListener("scrollend", onScrollEnd);
        }

        container.removeEventListener("touchend", onPointerRelease);
        container.removeEventListener("pointerup", onPointerRelease);
        container.removeEventListener("mouseup", onPointerRelease);

        if (scrollTimeoutId) {
            window.clearTimeout(scrollTimeoutId);
            scrollTimeoutId = null;
        }
    };
}

export default installScrollPlaybackFallback;
