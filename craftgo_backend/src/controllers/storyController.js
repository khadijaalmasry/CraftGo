'use strict';

const crypto = require('crypto');

const Story =
  require('../models/Story');

const User =
  require('../models/User');

const {
  Op,
} = require('sequelize');


const ONE_DAY_MS =
  24 * 60 * 60 * 1000;


// ======================================================
// HELPERS
// ======================================================


function activeStoryWhere(
  extra = {},
) {
  const since =
    new Date(
      Date.now() - ONE_DAY_MS,
    );

  const now =
    new Date();

  return {
    ...extra,

    createdAt: {
      [Op.gte]: since,
    },

    [Op.and]: [
      {
        [Op.or]: [
          {
            expiresAt: null,
          },
          {
            expiresAt: {
              [Op.gt]: now,
            },
          },
        ],
      },
    ],
  };
}


function cleanCommentText(
  value,
) {
  return String(
    value ?? '',
  )
    .replace(
      /\s+/g,
      ' ',
    )
    .trim()
    .slice(
      0,
      500,
    );
}


function storyJsonWithoutComments(
  story,
) {
  const json =
    story.toJSON();

  delete json.comments;

  return json;
}


// ======================================================
// GET FEED
// GET /api/stories
// ======================================================


exports.getFeed =
  async (
    req,
    res,
  ) => {
    try {
      const stories =
        await Story.findAll({
          where:
            activeStoryWhere(),

          include: [
            {
              model: User,

              as: 'artisan',

              attributes: [
                'id',
                'name',
                'profileImage',
              ],
            },
          ],

          // Comments have their own endpoint.
          // No need to return the full list
          // every time the feed loads.
          attributes: {
            exclude: [
              'comments',
            ],
          },

          order: [
            [
              'createdAt',
              'DESC',
            ],
          ],
        });

      return res.json(
        stories,
      );
    } catch (err) {
      console.error(
        '[Stories] getFeed error:',
        err,
      );

      return res
        .status(500)
        .json({
          error:
            err.message,
        });
    }
  };


// ======================================================
// GET ARTISAN STORIES
// GET /api/stories/artisan/:id
// ======================================================


exports.getByArtisan =
  async (
    req,
    res,
  ) => {
    try {
      const stories =
        await Story.findAll({
          where:
            activeStoryWhere({
              artisanId:
                req.params.id,
            }),

          include: [
            {
              model: User,

              as: 'artisan',

              attributes: [
                'id',
                'name',
                'profileImage',
              ],
            },
          ],

          attributes: {
            exclude: [
              'comments',
            ],
          },

          order: [
            [
              'createdAt',
              'DESC',
            ],
          ],
        });

      return res.json(
        stories,
      );
    } catch (err) {
      console.error(
        '[Stories] getByArtisan error:',
        err,
      );

      return res
        .status(500)
        .json({
          error:
            err.message,
        });
    }
  };


// ======================================================
// CREATE STORY
// POST /api/stories
// ======================================================


exports.create =
  async (
    req,
    res,
  ) => {
    try {
      const artisanId =
        req.user.id;

      const textAr =
        String(
          req.body.textAr ?? '',
        ).trim();

      const textEn =
        String(
          req.body.textEn ?? '',
        ).trim();

      const imageUrl =
        String(
          req.body.imageUrl ?? '',
        ).trim();


      // Story can be:
      // text only
      // photo only
      // text + photo
      if (
        !textAr &&
        !textEn &&
        !imageUrl
      ) {
        return res
          .status(400)
          .json({
            error:
              'Story must contain text or an image',
          });
      }


      const story =
        await Story.create({
          artisanId,

          textAr:
            textAr ||
            textEn ||
            '',

          textEn:
            textEn ||
            textAr ||
            '',

          imageUrl:
            imageUrl ||
            null,

          likes: 0,

          likedBy: [],

          commentsCount: 0,

          comments: [],

          expiresAt:
            new Date(
              Date.now() +
                ONE_DAY_MS,
            ),
        });


      // Reload Story with artisan
      // so frontend receives
      // profileImage immediately.
      const created =
        await Story.findByPk(
          story.id,
          {
            include: [
              {
                model: User,

                as: 'artisan',

                attributes: [
                  'id',
                  'name',
                  'profileImage',
                ],
              },
            ],

            attributes: {
              exclude: [
                'comments',
              ],
            },
          },
        );


      return res
        .status(201)
        .json({
          story:
            created
              ? storyJsonWithoutComments(
                  created,
                )
              : storyJsonWithoutComments(
                  story,
                ),
        });
    } catch (err) {
      console.error(
        '[Stories] create error:',
        err,
      );

      return res
        .status(500)
        .json({
          error:
            err.message,
        });
    }
  };


// ======================================================
// LIKE / UNLIKE
// POST /api/stories/:id/like
// ======================================================


exports.like =
  async (
    req,
    res,
  ) => {
    try {
      const story =
        await Story.findByPk(
          req.params.id,
        );


      if (!story) {
        return res
          .status(404)
          .json({
            error:
              'Story not found',
          });
      }


      // Don't allow interaction
      // after expiration.
      if (
        story.expiresAt &&
        new Date(
          story.expiresAt,
        ) <= new Date()
      ) {
        return res
          .status(410)
          .json({
            error:
              'Story has expired',
          });
      }


      const userId =
        String(
          req.user.id,
        );


      const likedBy =
        Array.isArray(
          story.likedBy,
        )
          ? story.likedBy.map(
              String,
            )
          : [];


      const alreadyLiked =
        likedBy.includes(
          userId,
        );


      const updatedLikedBy =
        alreadyLiked
          ? likedBy.filter(
              (
                id,
              ) =>
                id !== userId,
            )
          : [
              ...likedBy,
              userId,
            ];


      story.likedBy =
        updatedLikedBy;


      // Keep number always synced
      // with likedBy.
      story.likes =
        updatedLikedBy.length;


      await story.save();


      return res.json({
        liked:
          !alreadyLiked,

        likes:
          story.likes,
      });
    } catch (err) {
      console.error(
        '[Stories] like error:',
        err,
      );

      return res
        .status(500)
        .json({
          error:
            err.message,
        });
    }
  };


// ======================================================
// GET COMMENTS
// GET /api/stories/:id/comments
// ======================================================


exports.getComments =
  async (
    req,
    res,
  ) => {
    try {
      const story =
        await Story.findByPk(
          req.params.id,
        );


      if (!story) {
        return res
          .status(404)
          .json({
            error:
              'Story not found',
          });
      }


      const comments =
        Array.isArray(
          story.comments,
        )
          ? [
              ...story.comments,
            ]
          : [];


      // Newest first.
      comments.sort(
        (
          a,
          b,
        ) => {
          return (
            new Date(
              b.createdAt ||
                0,
            ) -
            new Date(
              a.createdAt ||
                0,
            )
          );
        },
      );


      return res.json(
        comments,
      );
    } catch (err) {
      console.error(
        '[Stories] getComments error:',
        err,
      );

      return res
        .status(500)
        .json({
          error:
            err.message,
        });
    }
  };


// ======================================================
// ADD COMMENT
// POST /api/stories/:id/comments
// ======================================================


exports.addComment =
  async (
    req,
    res,
  ) => {
    try {
      const story =
        await Story.findByPk(
          req.params.id,
        );


      if (!story) {
        return res
          .status(404)
          .json({
            error:
              'Story not found',
          });
      }


      if (
        story.expiresAt &&
        new Date(
          story.expiresAt,
        ) <= new Date()
      ) {
        return res
          .status(410)
          .json({
            error:
              'Story has expired',
          });
      }


      const text =
        cleanCommentText(
          req.body.text,
        );


      if (!text) {
        return res
          .status(400)
          .json({
            error:
              'Comment text is required',
          });
      }


      const userId =
        String(
          req.user.id,
        );


      // Retrieve the real profile
      // name and photo.
      const user =
        await User.findByPk(
          userId,
          {
            attributes: [
              'id',
              'name',
              'profileImage',
            ],
          },
        );


      const comment = {
        id:
          crypto.randomUUID(),

        userId,

        userName:
          user?.name
            ?.toString()
            .trim() ||
          'User',

        profileImage:
          user?.profileImage ||
          null,

        text,

        createdAt:
          new Date()
            .toISOString(),
      };


      const comments =
        Array.isArray(
          story.comments,
        )
          ? [
              ...story.comments,
            ]
          : [];


      comments.push(
        comment,
      );


      story.comments =
        comments;


      story.commentsCount =
        comments.length;


      await story.save();


      return res
        .status(201)
        .json({
          comment,

          commentsCount:
            story.commentsCount,
        });
    } catch (err) {
      console.error(
        '[Stories] addComment error:',
        err,
      );

      return res
        .status(500)
        .json({
          error:
            err.message,
        });
    }
  };


// ======================================================
// DELETE COMMENT
// DELETE /api/stories/:id/comments/:commentId
// ======================================================


exports.removeComment =
  async (
    req,
    res,
  ) => {
    try {
      const story =
        await Story.findByPk(
          req.params.id,
        );


      if (!story) {
        return res
          .status(404)
          .json({
            error:
              'Story not found',
          });
      }


      const comments =
        Array.isArray(
          story.comments,
        )
          ? [
              ...story.comments,
            ]
          : [];


      const index =
        comments.findIndex(
          (
            comment,
          ) =>
            String(
              comment.id,
            ) ===
            String(
              req.params
                .commentId,
            ),
        );


      if (index < 0) {
        return res
          .status(404)
          .json({
            error:
              'Comment not found',
          });
      }


      const comment =
        comments[index];


      const currentUserId =
        String(
          req.user.id,
        );


      const isCommentOwner =
        String(
          comment.userId,
        ) ===
        currentUserId;


      const isStoryOwner =
        String(
          story.artisanId,
        ) ===
        currentUserId;


      // User can delete their own comment.
      // Story owner can moderate
      // comments on their own Story.
      if (
        !isCommentOwner &&
        !isStoryOwner
      ) {
        return res
          .status(403)
          .json({
            error:
              'Forbidden',
          });
      }


      comments.splice(
        index,
        1,
      );


      story.comments =
        comments;


      story.commentsCount =
        comments.length;


      await story.save();


      return res.json({
        success: true,

        commentsCount:
          story.commentsCount,
      });
    } catch (err) {
      console.error(
        '[Stories] removeComment error:',
        err,
      );

      return res
        .status(500)
        .json({
          error:
            err.message,
        });
    }
  };


// ======================================================
// DELETE STORY
// DELETE /api/stories/:id
// ======================================================


exports.remove =
  async (
    req,
    res,
  ) => {
    try {
      const story =
        await Story.findByPk(
          req.params.id,
        );


      if (!story) {
        return res
          .status(404)
          .json({
            error:
              'Story not found',
          });
      }


      if (
        String(
          story.artisanId,
        ) !==
        String(
          req.user.id,
        )
      ) {
        return res
          .status(403)
          .json({
            error:
              'Forbidden',
          });
      }


      await story.destroy();


      return res.json({
        success: true,
      });
    } catch (err) {
      console.error(
        '[Stories] remove error:',
        err,
      );

      return res
        .status(500)
        .json({
          error:
            err.message,
        });
    }
  };