import { test } from 'node:test';
import assert from 'node:assert/strict';
// @ts-ignore plain JS module served by GitHub Pages
import { rentRangeError, rentRangeLabel, listedPhotoPath, listWords } from '../../../app/console/logic.js';

test('F26 #21: listed hostels: rent range, photo path and plain errors', () => {
  assert.equal(rentRangeError(7000, 9000), '');
  assert.equal(rentRangeError(9000, 7000), 'The highest rent can’t be below the lowest.');
  assert.equal(rentRangeError(500, 9000), 'Enter the expected rent, ₹1,000 to ₹1,00,000.');
  assert.equal(rentRangeError('x', 9000), 'Enter the expected rent, ₹1,000 to ₹1,00,000.');
  assert.equal(rentRangeLabel(7000, 9000), 'Around ₹7,000–9,000');
  assert.equal(rentRangeLabel(7000, 7000), 'Around ₹7,000');
  assert.match(listedPhotoPath('h1', 1000, 0.5), /^h1\/[0-9a-z]+\.jpg$/);
  assert.equal(listWords('ERROR: add a photo first'), 'Not listed: add a photo first.');
  assert.equal(listWords("the map pin isn't in Hyderabad"), 'Not listed: the map pin isn’t in Hyderabad.');
  assert.equal(listWords('boom'), 'Couldn’t save: boom');
});
