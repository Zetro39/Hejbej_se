# Firebase Setup Guide

This file outlines the minimal Firebase / Firestore structures and configuration needed to support shared checkpoints, quizzes, and the "Local Sheriff" verification system.

## Quick setup
- Create a Firebase project in the Firebase Console.
- Enable Firestore (preferably in native mode) and set up Android/iOS apps (download `google-services.json` / `GoogleService-Info.plist`).
- Enable Authentication providers you plan to support (Google, Apple). Configure OAuth client IDs as required.
- (Optional) Enable Firebase Cloud Functions and Firebase Storage for server-side verification and media.

## Firestore collections

- `users` (documents keyed by `uid` or internal id)
  - Fields:
    - `displayName` (string)
    - `email` (string)
    - `photoUrl` (string)
    - `createdAt` (timestamp)
    - `role` (string) — e.g. `user`, `local_sheriff`, `admin`
    - `limetkyBalance` (number)
    - `streak` (number)
    - `lastActivity` (timestamp)
    - `provider` (string) — e.g. `google`, `apple`, `local`

- `checkpoints` (documents keyed by checkpoint id)
  - Fields:
    - `title` (string)
    - `description` (string)
    - `location` (GeoPoint)
    - `createdBy` (user id)
    - `createdAt` (timestamp)
    - `verified` (boolean)
    - `verificationRequests` (map / subcollection reference)
    - `metadata` (map)

- `quizzes` (documents keyed by quiz id)
  - Fields:
    - `title` (string)
    - `questions` (array of maps: `{question, options, correctIndex}`)
    - `checkpointId` (optional string)
    - `rewardLimetky` (number)
    - `createdAt` (timestamp)

- `verification_requests` (or subcollection under `checkpoints`)
  - Fields:
    - `checkpointId` (string)
    - `submittedBy` (user id)
    - `images` (array of storage paths)
    - `status` (string) — `pending`, `approved`, `rejected`
    - `reviewedBy` (user id)
    - `reviewedAt` (timestamp)

- `achievements` (optional)
  - Documents that describe achievement rules; user achievement states can be stored as subcollections under `users` (e.g., `users/{uid}/achievements`).

- `trips` or `sessions`
  - Track saved trips (polylines), distances, elevation, and rewards. Reference `userId` and timestamps.

- `donations` (optional)
  - Track donation receipts and payment metadata (provider token, amount, status).

## Security & rules
- Use Firestore security rules to restrict writes:
  - Only authenticated users may create `verification_requests`.
  - Only `local_sheriff` or `admin` roles can set `checkpoints.*.verified = true`.
  - Validate GeoPoint types and basic schema constraints in rules.

## Indexes
- Create composite indexes if you need sorting/queries across multiple fields (e.g., `createdBy` + `createdAt`).

## Cloud Functions (recommended)
- Validate payment tokens server-side and mark `donations` with `status` after verification.
- Run automated verification heuristics for `verification_requests` (e.g., check image EXIF for location, ML-based checks).

## Notes
- Keep sensitive keys and server-side verification logic out of the client; use Cloud Functions or your own backend.
- This is a minimal starting schema; iterate based on product requirements.
