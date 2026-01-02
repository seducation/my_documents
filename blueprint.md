# Feed System Architecture Blueprint

This document outlines the architecture for the social media feed system, designed for a Flutter and Appwrite stack.

## 1. Core Principles

*   **Serverless-first:** All backend logic resides in Appwrite Cloud Functions. No dedicated server.
*   **Single Source of Truth for Ranking:** A single, unified ranking algorithm is used for all feeds, ensuring consistency.
*   **Scalable:** The design allows for pre-computing feeds and scaling horizontally with Appwrite's infrastructure.
*   **Flexible:** The feed generation is parameterized to allow for different types of feeds (e.g., all posts, videos only).

## 2. Appwrite Backend

### 2.1. Database Collections

*   **`posts` (Collection):**
    *   `userId` (string, required): ID of the user who created the post.
    *   `content` (string, required): Text content of the post.
    *   `mediaUrl` (string): URL to the image or video.
    *   `postType` (string, required): 'text', 'image', or 'video'.
    *   `createdAt` (datetime, required): Timestamp of post creation.
    *   `likes` (integer, default: 0): Number of likes.
    *   `comments` (integer, default: 0): Number of comments.
    *   ... (other relevant fields like `tags`, `location`, etc.)

*   **`feeds` (Collection - Optional, for scalability):**
    *   `userId` (string, required): The user for whom the feed is generated.
    *   `feedType` (string, required): 'all', 'video'.
    *   `posts` (string array): An ordered list of post IDs.
    *   `lastUpdatedAt` (datetime, required): When the feed was last generated.

### 2.2. Cloud Function: `generateFeed`

This is the heart of the feed system. It's responsible for fetching, ranking, and filtering posts.

*   **`appwrite-function-generateFeed/index.js`**: The main function code.

*   **Trigger:** Manual execution from the Flutter app. Could also be triggered by a schedule for pre-computation.

*   **Input (JSON payload):**
    ```json
    {
      "userId": "user-id-from-auth",
      "postType": "all" // or "video"
    }
    ```

*   **Logic:**
    1.  **Initialization:** Initialize the Appwrite SDK.
    2.  **Get Parameters:** Extract `userId` and `postType` from the request.
    3.  **Fetch Candidates:**
        *   Fetch posts from the `posts` collection.
        *   If `postType` is not 'all', apply a filter: `Query.equal('postType', postType)`.
        *   Initially, fetch posts from users the current user follows. Add logic to fetch from other sources for discovery (e.g., trending, new users).
    4.  **Ranking:**
        *   Apply the ranking algorithm to the candidate posts. The algorithm can be based on:
            *   **Recency:** Time decay (newer posts are ranked higher).
            *   **Engagement:** Likes, comments, shares.
            *   **User Interest:** Based on topics the user has interacted with.
            *   **Diversity:** Mix different types of content and sources.
    5.  **Return Feed:**
        *   Return a JSON array of ranked post objects.

*   **`appwrite-function-generateFeed/package.json`**:
    *   Will include the `node-appwrite` SDK.

## 3. Flutter Frontend

### 3.1. Shared Feed Logic

*   **`lib/features/feed/controllers/feed_controller.dart`:**
    *   This existing controller can be generalized to handle different feed types.
    *   Add a `postType` property to the controller.
    *   The `fetchFeed()` method will call the `generateFeed` Appwrite function, passing the `postType`.

### 3.2. Feed Screens

*   **`lib/hmv_feature_tabscreen.dart`:**
    *   This screen will instantiate the `FeedController` with `postType: 'all'`.
    *   It will render different widgets (`PostCard`, `AdCard`, etc.) based on the item type returned from the feed.

*   **`lib/hmv_video_tabscreen.dart` (New File):**
    *   This new screen will be very similar to `HmvFeatureTabScreen`.
    *   It will instantiate the `FeedController` with `postType: 'video'`.
    *   It will primarily render video posts but can reuse the same `PostCard` widget (which can handle different post types).

## 4. Implementation Steps

1.  **Create `blueprint.md`:** Finalize and save this architecture document.
2.  **Update Appwrite Function:**
    *   Flesh out `appwrite-function-generateFeed/index.js` with the logic described above.
3.  **Create `hmv_video_tabscreen.dart`:**
    *   Create the new Flutter screen for the video-only feed.
4.  **Refactor `FeedController`:**
    *   Generalize the `FeedController` to be reusable for both feeds.
5.  **Update `hmv_feature_tabscreen.dart`:**
    *   Update the feature tab screen to use the refactored controller.

This architecture provides a robust and scalable foundation for the feed system while keeping the backend logic centralized and maintainable.
