const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Ensure uploads directory exists
const uploadDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, {
    recursive: true
  });
}

// Multer storage config
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

// File filter (images & PDFs)
const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/') || file.mimetype === 'application/pdf') {
    cb(null, true);
  } else {
    cb(new Error('Only images and PDF documents are allowed!'), false);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024
  } // 5MB limit
});

// @route   POST /api/upload/image
// @desc    Upload an image and get URL
router.post('/image', upload.single('image'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        message: 'No file uploaded'
      });
    }

    // Construct public URL
    const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;

    res.status(201).json({
      message: 'Image uploaded successfully',
      url: fileUrl
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({
      message: 'Server error during upload'
    });
  }
});

const aiController = require('../controllers/aiController');

// @route   POST /api/upload/verify-id
// @desc    Upload an image, verify quality with AI, and get URL + quality metrics
router.post('/verify-id', upload.single('image'), aiController.verifyIdImage);

// @route   POST /api/upload/visual-search
// @desc    Upload an image for AI visual search
router.post('/visual-search', upload.single('image'), aiController.visualSearch);

// @route   POST /api/upload/generate-sketch-mockup
// @desc    Turn a drawing into a generated craft product image
router.post('/generate-sketch-mockup', upload.single('image'), aiController.generateSketchMockup);

module.exports = router;