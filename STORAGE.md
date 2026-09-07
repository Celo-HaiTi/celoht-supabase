# STORAGE.md — Storage Architecture

## Buckets

| Bucket | Public | Contents | Path convention |
|---|---|---|---|
| `agent-kyc` | No | KYC documents | `{agent_id}/{filename}` |
| `reforestation-evidence` | No | Physical impact evidence (photos, reports) | `{project_id}/{filename}` |
| `certificates` | No | Issued certificate files | `{profile_id}/{filename}` |
| `user-media` | Yes | Avatars, non-sensitive user media | `{profile_id}/{filename}` |
| `education-materials` | No | Course files and learning materials | `{course_id}/{filename}` |

## Access model
- `agent-kyc`, `reforestation-evidence`, `certificates` are **private buckets**.
  There is no public URL for objects in these buckets. Access is either:
  1. a direct `select` via an authenticated session matching the RLS policies
     in `migrations/0007_storage.sql`, or
  2. a **short-lived signed URL** issued by `celoht-backend` after it verifies
     the request server-side.
- `user-media` is public because avatars are not sensitive, but writes are
  still restricted to the owning profile.
- `education-materials` is private. Authenticated users can read objects only
   when the path begins with a published course ID; administrators manage files.

## Sensitive document handling rules
1. Never generate a permanent public link for `agent-kyc` or
   `reforestation-evidence` objects.
2. Signed URLs issued by the backend must have a short expiry
   (recommend ≤ 15 minutes) and must be generated only after an
   authorization check equivalent to the table-level RLS policy.
3. Deleting a KYC or evidence object must be logged to `audit_logs`.

## Verification checklist
- [ ] `agent-kyc` and `reforestation-evidence` buckets have `public = false`.
- [ ] No storage policy grants `select` on those buckets with `using (true)`.
- [ ] Backend signed-URL generation is covered by an authorization test.
