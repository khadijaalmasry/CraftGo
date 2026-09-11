'use strict';

const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Story = sequelize.define(
  'Story',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },

    artisanId: {
      type: DataTypes.STRING,
      allowNull: false,
    },

    textAr: {
      type: DataTypes.TEXT,
      allowNull: false,
      defaultValue: '',
    },

    textEn: {
      type: DataTypes.TEXT,
      allowNull: true,
      defaultValue: '',
    },

    imageUrl: {
      type: DataTypes.STRING,
      allowNull: true,
    },

    likes: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    commentsCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },

    // JSON array containing user IDs that liked this story.
    likedBy: {
      type: DataTypes.TEXT,
      allowNull: false,
      defaultValue: '[]',

      get() {
        const raw = this.getDataValue('likedBy');

        if (Array.isArray(raw)) {
          return raw;
        }

        try {
          const parsed = JSON.parse(raw || '[]');

          return Array.isArray(parsed)
            ? parsed
            : [];
        } catch (_) {
          return [];
        }
      },

      set(value) {
        this.setDataValue(
          'likedBy',
          JSON.stringify(
            Array.isArray(value)
              ? value
              : [],
          ),
        );
      },
    },

    // Comments are stored as JSON.
    //
    // Each item:
    // {
    //   id,
    //   userId,
    //   userName,
    //   profileImage,
    //   text,
    //   createdAt
    // }
    comments: {
      type: DataTypes.TEXT,
      allowNull: false,
      defaultValue: '[]',

      get() {
        const raw =
          this.getDataValue('comments');

        if (Array.isArray(raw)) {
          return raw;
        }

        try {
          const parsed =
            JSON.parse(raw || '[]');

          return Array.isArray(parsed)
            ? parsed
            : [];
        } catch (_) {
          return [];
        }
      },

      set(value) {
        this.setDataValue(
          'comments',
          JSON.stringify(
            Array.isArray(value)
              ? value
              : [],
          ),
        );
      },
    },

    expiresAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    timestamps: true,
    tableName: 'stories',
  },
);

module.exports = Story;