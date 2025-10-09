import assert from 'node:assert/strict';
import { shouldTriggerLoop } from './scrollGuard.js';

const slideWidth = 375;
const slideCount = 5;
const tolerance = slideWidth / slideCount;
const maxOffset = slideWidth * (slideCount - 1);

// Baseline: exactly at the tolerated offset from the last snap point.
const alignedScrollLeft = maxOffset - tolerance;
assert.equal(
  shouldTriggerLoop(alignedScrollLeft, slideWidth, slideCount, { tolerance }),
  true,
  'Scroll positions offset by the tolerated amount from the last slide should loop.'
);

// Numeric noise slightly above the tolerance must still be accepted on iOS Safari.
const safariScrollLeft = alignedScrollLeft + Number.EPSILON * slideWidth * 4;
assert.equal(
  shouldTriggerLoop(safariScrollLeft, slideWidth, slideCount, { tolerance }),
  true,
  'Tiny floating point errors produced by Safari should not block the loop restart.'
);

// Positions further away than the tolerance must still be rejected.
const beforeLastSlide = alignedScrollLeft - tolerance * 2;
assert.equal(
  shouldTriggerLoop(beforeLastSlide, slideWidth, slideCount, { tolerance }),
  false,
  'Values too far from the snap point must not trigger the loop.'
);

console.log('All scroll guard tests passed');
