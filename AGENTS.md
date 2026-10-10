# Lyrics

## Description
Shows time-synced lyrics for the song currently playing on the user's Spotify account (any device, e.g. their iPhone). Use when the user asks for lyrics, "what's playing", or "show the lyrics". Displays the previous line (dim), current line (bright) and next line, updating in real time. Shows "Paused" when playback is paused and the plain lyrics or track name if no synced lyrics exist.

## Data
Calls the companion backend `/api/now` (Spotify Web API currently-playing + LRCLIB lyrics), authenticated with a shared bearer token.
