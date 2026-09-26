CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  status TEXT,
  total_cents INT,
  created_at TIMESTAMP DEFAULT now()
);

CREATE VIEW orders_view AS
  SELECT o.id, o.status, o.total_cents, u.email
  FROM orders o JOIN users u ON u.id = o.user_id;

INSERT INTO users (email)
SELECT 'user' || n || '@test.com'
FROM generate_series(1, 300) AS n;

-- Deterministic seed data keeps each reset identical while preserving the
-- stated distribution: roughly 5% NULL status values.
INSERT INTO orders (user_id, status, total_cents)
SELECT
  ((n * 37) % 300) + 1,
  CASE
    WHEN n % 20 = 0 THEN NULL
    WHEN n % 3 = 0 THEN 'paid'
    ELSE 'pending'
  END,
  100 + ((n * 7919) % 49901)
FROM generate_series(1, 500) AS n;
