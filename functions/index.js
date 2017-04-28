// Start writing Firebase Functions
// https://firebase.google.com/functions/write-firebase-functions

'use strict';

const functions = require('firebase-functions');
//const gcs = require('@google-cloud/storage')();

// Max number of lines of the chat history.
const MAX_LOG_COUNT = 50;
const TRIM_TO_COUNT = 25;

// Removes siblings of the node that element that triggered the function if there are more than MAX_LOG_COUNT, trims the number of items to TRIM_TO_COUNT.
exports.truncate = functions.database.ref('/eph/{userID}/msgs').onWrite(event => {
  const parentRef = event.data.ref;
  return parentRef.once('value').then(snapshot => {
    if (snapshot.numChildren() > MAX_LOG_COUNT) {
      let childCount = 0;
      const updates = {};
      snapshot.forEach(function(child) {
        if (++childCount < snapshot.numChildren() - TRIM_TO_COUNT) {
          updates[child.key] = null;
        }
      });
      // Update the parent. This effectively removes the extra children.
      return parentRef.update(updates);
    }
  });
});