# Customer Dashboard Full Backend Integration

This document outlines the plan to fully connect the Customer Dashboard (`ClientDashboard`) and its related features to the real backend API.

## User Review Required

> [!IMPORTANT]
> This integration touches multiple parts of the app (Products, Artisans, AI Gift Quiz, AI Visual Search). Review the proposed changes to the backend APIs and frontend UI to ensure they meet your expectations.

## Open Questions

- **Camera Search**: Currently, the camera icon navigates to the "Custom Order" screen. Do you want it to navigate to the Custom Order screen, OR do you want it to act as an "AI Visual Search" that searches for ready-made products in the store based on a photo? (The plan currently assumes you want an AI Visual Search for ready-made products).
- **Images**: Do you have a working cloud storage (like Cloudinary) connected to your backend to handle image uploads for the visual search?

## Proposed Changes

### Backend Changes

#### [MODIFY] `src/controllers/productController.js`
- Fix the bug in `getAllProducts` which mistakenly filters by `req.params.craftsmanId` (which is undefined on this route).
- Enhance `getAllProducts` to accept query parameters:
  - `?category=خزفيات` (for top category filters)
  - `?sort=new` (for "New" tab)
  - `?sort=most_liked` (for "Most Liked" tab)

#### [MODIFY] `src/routes/craftsmanRoutes.js` & `src/controllers/craftsmanController.js`
- Add a new `GET /api/craftsmen` endpoint to fetch a list of all verified artisans, including their profiles, ratings, and basic info to populate the "Top Artisans" section in the dashboard.

#### [MODIFY] `src/routes/aiRoutes.js` & `src/controllers/aiController.js`
- Add `POST /api/ai/visual-search`: Takes an uploaded image, sends it to Gemini API to analyze the craft, and searches the database for matching ready-made products.
- Add `POST /api/ai/gift-quiz`: Takes the answers from the Gift Quiz screen, sends them to Gemini API to understand the gift persona, and returns recommended products from the database.

---

### Frontend Changes

#### [NEW] `lib/services/customer_service.dart`
- Create a new service file dedicated to customer data fetching.
- Add methods: `fetchProducts(category, sort)`, `fetchTopArtisans()`, `submitGiftQuiz(answers)`, and `visualSearch(imageFile)`.

#### [MODIFY] `lib/screens/customer/client_dashboard.dart`
- Remove all hardcoded mock data for `topArtisans` and `products`.
- Introduce `FutureBuilder` (or state variables) to fetch real Artisans and Products on load.
- Link the top Category Filters (e.g. "فخاريات", "تطريز") to re-fetch products with the `category` query parameter.
- Link the bottom Filter Tabs ("الأكثر طلباً", "جديد") to re-fetch products with the `sort` query parameter.
- Link the **Camera Icon** to open the device gallery/camera, send the image to `/api/ai/visual-search`, and navigate to `SearchResultsScreen`.

#### [MODIFY] `lib/screens/customer/gift_quiz_screen.dart`
- Connect the final "Find Gifts" button to the `/api/ai/gift-quiz` backend route.
- Show a loading indicator while AI processes the answers.
- Navigate to `SearchResultsScreen` passing the list of AI-recommended products.

## Verification Plan

### Automated Tests
- N/A

### Manual Verification
1. Launch the app and log in as a Customer.
2. Verify that the Dashboard loads real products and artisans from the database.
3. Tap on different Categories and verify that products are filtered correctly.
4. Tap on the Camera icon, upload an image, and verify AI returns matching products.
5. Tap the Gift icon, complete the quiz, and verify AI returns personalized gift recommendations.
