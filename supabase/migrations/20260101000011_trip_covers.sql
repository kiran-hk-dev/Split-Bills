-- =====================================================================
-- TripSplit World - 0011 trip cover images
--
-- trips.cover_image_url already existed and TripCover already rendered it,
-- but nothing could ever populate it: there was no covers bucket and no
-- picker, so every trip silently fell back to painted artwork and a broken
-- URL was indistinguishable from a trip that had no photo at all.
--
-- This is the one bucket that is public-read. Every other bucket is private
-- and served through short-lived signed URLs, which is right for documents,
-- receipts and bookings but wrong for a cover: cover_image_url stores a
-- stable URL that gets rendered inside lists long after it was written, and
-- a signed URL would have expired. Writes stay owner-only, and the path
-- prefix is the authorisation boundary, as everywhere else.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('trip-covers', 'trip-covers', true, 5242880,
  array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Objects live at <user_id>/<trip_id>/<random>.<ext>.
--
-- The ownership check is written inline rather than via public.storage_owner_of
-- so this file also runs correctly when pasted into the dashboard SQL editor
-- on its own, which is the likely way it gets applied. storage_owner_of is
-- declared in migration 0004, and depending on it here would make this one
-- fail for anyone who has not applied the earlier migrations in order.

drop policy if exists "trip covers are publicly readable" on storage.objects;
create policy "trip covers are publicly readable"
  on storage.objects for select
  using (bucket_id = 'trip-covers');

drop policy if exists "trip covers are inserted by their owner" on storage.objects;
create policy "trip covers are inserted by their owner"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'trip-covers'
    and (split_part(name, '/', 1)) = auth.uid()::text
  );

drop policy if exists "trip covers are updated by their owner" on storage.objects;
create policy "trip covers are updated by their owner"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'trip-covers'
    and (split_part(name, '/', 1)) = auth.uid()::text
  )
  with check (
    bucket_id = 'trip-covers'
    and (split_part(name, '/', 1)) = auth.uid()::text
  );

drop policy if exists "trip covers are deleted by their owner" on storage.objects;
create policy "trip covers are deleted by their owner"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'trip-covers'
    and (split_part(name, '/', 1)) = auth.uid()::text
  );