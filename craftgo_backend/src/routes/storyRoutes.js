'use strict';

const express = require('express');

const router = express.Router();

const {
  verifyToken,
} = require('../middlewares/authMiddleware');

const storyController =
  require('../controllers/storyController');


// ======================================================
// STORIES
// ======================================================


// Story feed
// Only active stories from the last 24 hours.
router.get(
  '/',
  storyController.getFeed,
);


// Active stories for one artisan.
router.get(
  '/artisan/:id',
  storyController.getByArtisan,
);


// Create Story.
router.post(
  '/',
  verifyToken,
  storyController.create,
);


// ======================================================
// LIKES
// ======================================================


// Like / Unlike
router.post(
  '/:id/like',
  verifyToken,
  storyController.like,
);


// ======================================================
// COMMENTS
// ======================================================


// Get Story comments.
router.get(
  '/:id/comments',
  storyController.getComments,
);


// Add comment.
router.post(
  '/:id/comments',
  verifyToken,
  storyController.addComment,
);


// Delete comment.
//
// Comment owner can delete their comment.
// Story owner can also delete comments on their Story.
router.delete(
  '/:id/comments/:commentId',
  verifyToken,
  storyController.removeComment,
);


// ======================================================
// DELETE STORY
// ======================================================


// Only Story owner can delete.
router.delete(
  '/:id',
  verifyToken,
  storyController.remove,
);


module.exports = router;