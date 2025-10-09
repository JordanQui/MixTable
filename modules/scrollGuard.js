/**
 * Utility to detect slide boundaries in a scroll snapping carousel.
 *
 * On iOS Safari `scrollLeft` may end up being a non integer number of pixels
 * even when the browser visually aligns the content on the beginning of a
 * slide. This makes guards based on a strict equality such as
 * `scrollLeft % slideWidth === 0` fail and the autoplay logic does not restart
 * when reaching the end of the scroll.
 *
 * We solve that by accepting a small tolerance. We also round the theoretical
 * slide index to the closest integer so the autoplay resumes once the user
 * stops scrolling close to the expected boundary. Because of floating point
 * rounding we additionally allow a minuscule epsilon when comparing the
 * computed distance to the tolerated value so Safari's fractional scroll
 * positions are still accepted.
 */
export function shouldTriggerLoop(scrollLeft, slideWidth, slideCount, { tolerance = 1 } = {}) {
  if (slideWidth <= 0 || slideCount <= 0) {
    return false;
  }

  const maxOffset = slideWidth * (slideCount - 1);
  const boundedScrollLeft = Math.min(Math.max(scrollLeft, 0), maxOffset);

  const exactIndex = boundedScrollLeft / slideWidth;
  const nearestIndex = Math.round(exactIndex);
  const distanceToSnap = Math.abs(exactIndex - nearestIndex) * slideWidth;
  const epsilon = Math.max(Number.EPSILON * slideWidth * 4, 1e-9);

  if (distanceToSnap - tolerance > epsilon) {
    return false;
  }

  return nearestIndex === slideCount - 1;
}
