CREATE TABLE IF NOT EXISTS pending_registrations (
  email text PRIMARY KEY,
  registration_id uuid NOT NULL UNIQUE,
  request_id uuid NOT NULL,
  details jsonb NOT NULL,
  code_hash text NOT NULL,
  code_expires_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  accepted boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_pending_registrations_expiry ON pending_registrations(expires_at);
