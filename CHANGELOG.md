# CHANGELOG

## 0.1.0 (3) - 2024-08-18

### Added
- Relay state visual indicators and added RSVP retry publish button
- Deletion requests
- Calendars view

### Changed
- Updated Explore tab image to be a globe
- Abbreviated public key npub when there is no display name or username
- Renamed Nostr event deletion to retraction

### Fixed
- Hide map if geohash is an empty string
- Event creation participant list bug and start/end time zone bug
- Relay url and role were not being set on EventCreationParticipant
- Time zone bug in event creation when setting time zone toggle is off
- Race condition for handling relay responses 
- Bug with images that do not end with a file extension

## 0.1.0 (2) - 2024-08-06

### Added 
- Profile creation
- Event deletion
- Toolbar menu item to copy njump.me URL for event

### Changed
- Profile name resolution now prefers display name over name

### Fixed
- Sign out bug where active tab is not switched
- Event creation image URL validation
- Bug where updating relay pool settings do not get reflected in the active relay pool
- Alignment of event relay list

## 0.1.0 (1) - 2024-08-04

Initial release of Comingle!
