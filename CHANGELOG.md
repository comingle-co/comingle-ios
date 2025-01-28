# CHANGELOG

## 0.1.0 (8) - 2024-01-27

### Fixed
- Removed xcstrings-tool-plugin to improve performance
- Improved memory usage by removing unnecessary fields from what is cached in the tries

## 0.1.0 (7) - 2024-11-18

### Fixed
- Replacing old calendars did not update calendar search
- Padding issues with event list

## 0.1.0 (6) - 2024-08-22

### Added
- Condensed profile pictures of invitees and RSVPs on event list

### Fixed
- Time zone not being set on event creation when it is the system time zone
- Newly created events and calendars were not searchable
- Events were not searchable by summary

## 0.1.0 (5) - 2024-08-21

### Added
- Search by username, calendar name
- Profile description

### Changed
- Change calendar description component from disclosure group to just plain text with a collapse button

### Fixed
- Case sensitivity when searching event details
- Erroneously showing events from followed pubkeys in calendar view and profile view

## 0.1.0 (4) - 2024-08-20

### Added
- Search by event details, naddr, nevent, npub

### Changed
- Consolidated Home and Explore tabs

### Fixed
- Signing in with public key would use private key if it used to exist in the keychain

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
