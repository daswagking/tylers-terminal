/*
  # Create Core Tables for Tyler's Terminal

  ## Summary
  Creates all tables required by the iOS app.

  ## New Tables
  - `profiles` - User accounts with username, email, password hash, admin/verified flags
  - `posts` - Trade posts with image, description, ticker, category, reaction counts
  - `comments` - Comments on posts
  - `reactions` - User reactions (fire, hundred, heart) on posts
  - `notifications` - In-app notifications for users
  - `asset_requests` - User requests for new assets to be tracked

  ## Security
  - RLS enabled on all tables
  - Service role bypass for app operations (app uses service role key)
  - Policies allow service role full access (app authenticates via service role key)

  ## Notes
  1. The iOS app uses the Supabase service role key for all requests (not Supabase Auth JWT)
  2. Password hashing is done client-side (base64 for demo); proper bcrypt in production
  3. Reaction counts are denormalized onto posts for performance
*/

-- ============================================================
-- PROFILES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text UNIQUE NOT NULL,
  email text UNIQUE NOT NULL,
  password_hash text,
  is_admin boolean DEFAULT false,
  is_verified boolean DEFAULT false,
  push_notifications_enabled boolean DEFAULT true,
  fcm_token text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role has full access to profiles"
  ON profiles
  FOR SELECT
  TO service_role
  USING (true);

CREATE POLICY "Service role can insert profiles"
  ON profiles
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Service role can update profiles"
  ON profiles
  FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role can delete profiles"
  ON profiles
  FOR DELETE
  TO service_role
  USING (true);

-- ============================================================
-- POSTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_username text NOT NULL,
  author_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  image_url text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  ticker text DEFAULT '',
  category text NOT NULL DEFAULT 'TRADE',
  fire_count integer NOT NULL DEFAULT 0,
  hundred_count integer NOT NULL DEFAULT 0,
  heart_count integer NOT NULL DEFAULT 0,
  comment_count integer NOT NULL DEFAULT 0,
  is_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role has full access to posts"
  ON posts
  FOR SELECT
  TO service_role
  USING (true);

CREATE POLICY "Service role can insert posts"
  ON posts
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Service role can update posts"
  ON posts
  FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role can delete posts"
  ON posts
  FOR DELETE
  TO service_role
  USING (true);

-- Allow anon to read posts
CREATE POLICY "Anyone can read posts"
  ON posts
  FOR SELECT
  TO anon
  USING (true);

-- ============================================================
-- COMMENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  author_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  author_username text NOT NULL,
  content text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role has full access to comments"
  ON comments
  FOR SELECT
  TO service_role
  USING (true);

CREATE POLICY "Service role can insert comments"
  ON comments
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Service role can update comments"
  ON comments
  FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role can delete comments"
  ON comments
  FOR DELETE
  TO service_role
  USING (true);

-- ============================================================
-- REACTIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('FIRE', 'HUNDRED', 'HEART')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id, type)
);

ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role has full access to reactions"
  ON reactions
  FOR SELECT
  TO service_role
  USING (true);

CREATE POLICY "Service role can insert reactions"
  ON reactions
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Service role can update reactions"
  ON reactions
  FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role can delete reactions"
  ON reactions
  FOR DELETE
  TO service_role
  USING (true);

-- ============================================================
-- NOTIFICATIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'system',
  title text NOT NULL DEFAULT '',
  body text NOT NULL DEFAULT '',
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role has full access to notifications"
  ON notifications
  FOR SELECT
  TO service_role
  USING (true);

CREATE POLICY "Service role can insert notifications"
  ON notifications
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Service role can update notifications"
  ON notifications
  FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role can delete notifications"
  ON notifications
  FOR DELETE
  TO service_role
  USING (true);

-- ============================================================
-- ASSET REQUESTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS asset_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  ticker text NOT NULL,
  category text NOT NULL DEFAULT 'stock',
  description text DEFAULT '',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'fulfilled', 'rejected')),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE asset_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role has full access to asset_requests"
  ON asset_requests
  FOR SELECT
  TO service_role
  USING (true);

CREATE POLICY "Service role can insert asset_requests"
  ON asset_requests
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Service role can update asset_requests"
  ON asset_requests
  FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role can delete asset_requests"
  ON asset_requests
  FOR DELETE
  TO service_role
  USING (true);

-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_reactions_post_id ON reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_reactions_user_id ON reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_asset_requests_user_id ON asset_requests(user_id);
