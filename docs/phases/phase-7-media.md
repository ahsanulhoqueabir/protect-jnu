# Phase 7 — Photo/Video Capture & Local Gallery

## Objectives
Students capture photos/videos in-app, stored only on the phone, viewable in an in-app gallery.

## Requirements covered
FR-MEDIA-1, 2; PRD §5.5; screen Media Gallery & Camera.

## Prerequisites
Phase 3 complete (navigation, auth). Integration with active SOS needs Phase 4. Ask: video max duration/quality, storage location (app-private vs public gallery), delete support, camera package choice (D-023), whether capture during SOS must keep the location service running (it must not break it).

## Components
Flutter `features/media`: camera screen (photo/video), gallery grid, viewer (image/video playback), local file index.

## Steps
1. Add camera, video player, path/storage packages after verifying compatibility with min SDK.
2. Permissions: camera, microphone (video); handle denial.
3. Capture photo and video; save to agreed local directory; record metadata (timestamp, optionally alert id if during SOS — ask).
4. Gallery lists files, thumbnails, open viewer, delete (if approved).
5. Camera accessible from Home and Active Alert screen; ensure foreground location service continues while camera is open.
6. Confirm nothing is uploaded (inspect network calls; no storage buckets created).

## Dependencies / integrations
Camera/video packages, local filesystem.

## Database / API
None (explicitly no cloud storage).

## Testing & validation
- Capture photo and video on a low-end device; files persist after app restart.
- During active SOS capture video: location updates continue (check MCP rows).
- Permission-denied paths.
- Network inspection shows no media upload.

## Completion criteria
- [ ] Capture + gallery working
- [ ] No upload verified
- [ ] SOS/location unaffected
- [ ] PROGRESS updated; user confirmed

## Out of scope
Cloud sync, sharing to admins.
