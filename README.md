# University Bus Tracker

A lightweight, real-time bus tracking system built for university students and campus transport. The system tracks the driver's live GPS coordinates via a mobile client, syncs them through Firebase, and displays the bus position, road distance, and ETA on an embeddable Google Maps web interface.

## Features

- **Live Location Streaming:** Real-time bus GPS updates synced through Firebase Realtime Database.
- **Distance & ETA:** Calculates road distance and estimated arrival time using the student's live location.
- **Background Tracking:** The driver app runs foreground services with wake-lock support to maintain continuous updates.
- **Web & Iframe Ready:** Embeddable into WordPress or custom university portals without styling conflicts.

## Tech Stack

- **Mobile App:** Flutter, Dart, Geolocator, Wakelock
- **Frontend:** HTML5, CSS3, JavaScript
- **Mapping & Routing:** Google Maps JavaScript API, Distance Matrix API
- **Database:** Firebase Realtime Database
- **Hosting & CI/CD:** GitHub Pages, GitHub Actions

## University Website Integration

To embed the live tracker into any university portal or webpage, use this responsive embed snippet:

```html
<div style="width: 100%; height: 650px; max-width: 1200px; margin: 0 auto; border-radius: 10px; overflow: hidden; border: 1px solid #e2e8f0;">
  <iframe 
    src="[https://tamjidulislamgit.github.io/Bus-tracking-uni/](https://tamjidulislamgit.github.io/Bus-tracking-uni/)" 
    title="University Bus Live Tracker"
    width="100%" 
    height="100%" 
    style="border: 0;"
    allow="geolocation"
    loading="lazy">
  </iframe>
</div>
