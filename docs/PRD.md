# Product Requirements Document

## Protect JnU'ins

**Author:** Md. Mehedi Hasan\
**Platform:** Flutter Android app · Next.js admin dashboard · Supabase\
**Integrations:** Supabase MCP · OpenStreetMap · Brevo Transactional
Email API\
**Status:** Updated Draft\
**Project type:** University course project

------------------------------------------------------------------------

## 1. Overview

Protect JnU'ins is a student safety system for Jagannath University. It
consists of a Flutter Android application for students and a Next.js web
dashboard for a single admin team, with Supabase as the application
backend.

Students can register using their university email, verify ownership
through a one-time password (OTP), send an SOS alert, share their live
location, communicate with the admin team, and capture photo or video
evidence that remains stored locally on their phones.

The admin dashboard displays live student locations on a map powered by
Leaflet and OpenStreetMap. Brevo's Transactional Email API is used to
send all application-generated authentication and system emails.
Supabase's built-in SMTP/email delivery is not used.

## 2. Problem Statement

Students may face harassment or unsafe situations, particularly around
Old Dhaka, without having a fast, campus-specific way to alert someone
who can respond. Calling friends or emergency numbers can be slow, does
not necessarily share a live location with a responsible team, and
leaves no organized incident record.

Protect JnU'ins provides one-tap alerting for students and a central
dashboard where the admin team can receive alerts, follow locations,
communicate with students, and review incident history.

## 3. Goals and Non-Goals

### 3.1 Goals

-   Only students with a verified Jagannath University email address can
    register and use the student app.
-   A student can send an SOS in a few seconds, and the admin dashboard
    receives the alert in real time.
-   Admins can follow a student's live location, communicate with them,
    and view monthly and yearly support reports.
-   Students can capture photo or video evidence on their phones during
    an incident.
-   Authentication-related and other transactional emails are delivered
    through Brevo's Transactional Email API.

### 3.2 Non-Goals for This Version

-   iOS application and access for non-university users.
-   Guardian SMS or push notifications and a safe-spots map.
-   Uploading photos or videos to cloud storage; captured media remains
    on the student's phone.
-   Separate volunteer or university-administration roles. This version
    has one admin team, whose members can be added over time.
-   Automatic dispatch of police or ambulance services.

## 4. Users and Roles

  -----------------------------------------------------------------------
  Role                    Platform                Main needs
  ----------------------- ----------------------- -----------------------
  Student                 Flutter Android app     Quick SOS, live
                                                  location sharing, chat
                                                  with admins,
                                                  photo/video capture

  Admin team              Next.js dashboard       Receive alerts, track
                                                  locations on a map,
                                                  reply to students,
                                                  close alerts, and view
                                                  monthly/yearly reports
  -----------------------------------------------------------------------

All users sign in with a Jagannath University email address. A role
field on each profile (`user` or `admin`) determines whether the account
can access the student app or the admin dashboard. Admin accounts are
provisioned by the project team; public admin registration is not
available.

## 5. Core Features

### 5.1 University Email Authentication (P0)

-   Registration collects the student's name, student ID, university
    email, and password.
-   Only email addresses on the university domain are accepted: the
    address must end in `@jnu.ac.bd` or in `@<department>.jnu.ac.bd`
    (a subdomain of `jnu.ac.bd`, for example `@cse.jnu.ac.bd`). Look-alike
    domains such as `jnu.ac.bd.example.com` are rejected. Validate
    the domain in the UI and enforce it again on the trusted server
    side; client-side validation alone is insufficient.
    *(Wording amended 2026-11-09 at the project owner's request to allow
    department subdomains; see decision D-052.)*
-   **University email ownership must be verified using a one-time
    password (OTP).** The OTP is sent to the registered university
    address through Brevo's Transactional Email API. A verification link
    is not used for this flow.
-   The OTP flow must have explicit expiry and abuse protection:
    -   Generate a cryptographically secure, numeric 6-digit OTP.
    -   OTP validity (TTL): **10 minutes** from issue time.
    -   An OTP can be used only once and becomes invalid immediately
        after successful verification.
    -   Limit verification attempts to **5 attempts per issued OTP**.
        Invalidate the OTP after the limit is reached.
    -   Enforce a **60-second resend cooldown** and a configurable
        per-email rate limit (initial default: no more than 3 OTP sends
        in 15 minutes).
    -   A newly issued OTP invalidates any previously issued OTP for the
        same verification purpose and email address.
    -   Store only a secure hash of the OTP, not the plain OTP. Never
        log or return the OTP from an API.
    -   Use server-side time for expiry checks. Reject expired,
        already-used, superseded, or attempt-exhausted OTPs.
    -   Show clear states for sent, invalid, expired, verified, and
        temporarily rate-limited OTPs. Provide a resend action when
        allowed.
-   A user must not be treated as a verified university-email user, nor
    gain access to protected student features, until OTP verification
    succeeds.
-   **Email delivery provider:** use Brevo's Transactional Email API for
    OTP, password-reset, and every other authentication-related email.
    Do not use Supabase SMTP or Supabase's built-in email delivery for
    these messages.
-   Login, logout, and session persistence are required.
-   Forgot-password and password-reset flows must also send their emails
    through Brevo. Implement the reset flow server-side with single-use,
    expiring reset tokens; do not rely on Supabase sending an email.
-   After first successful login, the student adds 2--3 emergency
    contacts (name and phone number). Admins can view these contacts
    during an alert.
-   Admin accounts are created by the project team. Additional admin
    members can be added by assigning the admin role through a
    controlled, authorized process. The dashboard must reject accounts
    without the admin role.

**Implementation note --- authentication and Supabase:** Supabase
remains responsible for the application's database,
authentication/session infrastructure as selected for implementation,
Realtime, and Row Level Security. However, email OTP
issuance/verification and password-reset email delivery are
application-managed server workflows that call Brevo's API. Do not
trigger Supabase Auth email templates or Supabase SMTP for these flows.
The implementation must ensure that an unverified account cannot obtain
or use an authenticated session with access to protected application
data. Keep privileged Supabase credentials and the Brevo API key on the
server only.

### 5.2 SOS Alert (P0)

-   The home screen has a prominent SOS button, activated by pressing
    and holding for 2 seconds, followed by a 5-second cancellation
    window.
-   Sending an SOS creates an alert containing the student's details and
    initial location, with status `active`.
-   The dashboard displays new alerts immediately and provides an
    audible or visual notification.
-   Admins can mark an alert as `acknowledged` and then `resolved`.
-   The student can see the alert's current status in the app.

### 5.3 Live Location Tracker (P0)

-   After an SOS is sent, the app sends GPS coordinates every 5--10
    seconds through an Android foreground service until the alert is
    resolved or cancelled.
-   The dashboard map displays the student's moving marker, a short
    trail of recent location points, and the time of the latest update.
-   If the network connection drops, location points are queued on the
    phone and sent when connectivity returns.
-   Location collection must stop when the alert ends.

### 5.4 Real-Time Messaging (P0)

-   Each alert has one chat thread shared by the student and the admin
    team.
-   Messages are delivered in real time through Supabase Realtime and
    include timestamps.
-   The dashboard lists conversations and unread-message counts so
    admins can identify which student needs a reply.

### 5.5 Photo and Video Capture (P1)

-   Students can capture photos or videos from inside the app, including
    during an active SOS.
-   Captured files are saved to the phone's local storage.
-   An in-app gallery lists locally saved media.
-   Media is not uploaded to cloud storage in this version.

### 5.6 Support Reports (P1)

-   The dashboard includes a Reports page showing the number of students
    supported and alerts handled, grouped by month and year.
-   A student is counted as supported when an admin acknowledges or
    resolves that student's alert. Count each student once per reporting
    period; count alerts separately.
-   Provide month/year filters, a monthly bar chart, and CSV export.
-   Derive report figures from alert records and their
    status/timestamps; avoid unnecessary duplicate tracking data.

## 6. Application Screens

### 6.1 Flutter Student App

-   Splash
-   Sign Up
-   Verify University Email (OTP)
-   Login
-   Forgot Password
-   Emergency Contacts Setup
-   Home (SOS button)
-   Active Alert (status and location tracking)
-   Chat
-   Media Gallery and Camera
-   Profile

### 6.2 Next.js Admin Dashboard

-   Admin Login
-   Forgot Password
-   Live Alerts List
-   Alert Details (map, student information, emergency contacts, and
    chat)
-   Conversations
-   Users
-   Alert History
-   Reports

## 7. Technology Stack and Data Model

### 7.1 Technology Stack

  -----------------------------------------------------------------------
  Layer / Concern         Technology              Responsibility
  ----------------------- ----------------------- -----------------------
  Student application     Flutter (Android)       Authentication UI, SOS,
                                                  location service, chat,
                                                  camera, and local media
                                                  gallery

  Admin dashboard         Next.js                 Admin authentication
                                                  UI, live alerts, map,
                                                  chat, user/history
                                                  views, and reports

  Application backend and Supabase                PostgreSQL database,
  database                                        application data,
                                                  Realtime, and Row Level
                                                  Security

  Development database    Supabase MCP            Development-time schema
  tooling                                         inspection, database
                                                  management, and
                                                  verification of
                                                  database changes

  Dashboard mapping       Leaflet + OpenStreetMap Display current student
                                                  location, moving
                                                  marker, and recent
                                                  location trail

  Transactional email     Brevo Transactional     Send OTP verification,
                          Email API (Free plan    password-reset
                          initially)              messages, and other
                                                  authentication/system
                                                  emails from trusted
                                                  server-side code
  -----------------------------------------------------------------------

### 7.2 Supabase MCP

-   Use Supabase MCP during development to inspect the project, review
    the database schema and objects, and apply or verify database
    changes.
-   Supabase MCP is a development tool, not an application runtime
    dependency.
-   Never expose MCP credentials in Flutter assets, browser code,
    deployed client bundles, or the public repository.
-   The deployed application connects to Supabase through the
    appropriate Supabase SDK/server integration, not through MCP.

### 7.3 OpenStreetMap

-   Use Leaflet with OpenStreetMap map tiles in the Next.js admin
    dashboard.
-   Show the student's latest location, a moving marker, a short trail
    of recent points, and the last-update time.
-   Display the required OpenStreetMap attribution.
-   Do not use Google Maps in this version.
-   Use the public tile service in accordance with its usage policy. The
    implementation must handle tile-service unavailability gracefully
    and must not assume a guaranteed SLA from the public tile service.

### 7.4 Brevo Transactional Email

-   Use the **Brevo Transactional Email API**, initially on Brevo's
    **Free plan**, for all authentication-related and
    application-generated transactional emails.
-   This includes university email OTP verification, password-reset
    emails, and any future authentication/system emails.
-   **Do not use Supabase SMTP, Supabase's default email sender, or
    Supabase Auth email delivery** for these flows.
-   Send emails from trusted server-side code (for example, Next.js
    server routes/actions or a dedicated trusted backend endpoint). The
    Flutter app must never call Brevo directly.
-   Store the Brevo API key only in server-side environment variables.
    Never expose it in client-side code, mobile app assets, public
    environment variables, or source control.
-   Configure and verify the sender identity/domain supported by the
    available Brevo plan before testing email delivery.
-   Design the email flow around the Free plan's current sending limits.
    Add safe handling for provider errors, temporary failures, and rate
    limits; do not silently mark an email as sent when Brevo rejects the
    request.
-   Keep OTP generation, hashing, storage, expiry checks, attempt
    counting, resend throttling, and verification on the trusted server
    side.
-   Do not include OTPs, reset tokens, API keys, or sensitive provider
    responses in application logs or user-facing error messages.

### 7.5 Initial Data Model

  -----------------------------------------------------------------------
  Table                               Main columns
  ----------------------------------- -----------------------------------
  `profiles`                          `id`, `full_name`, `student_id`,
                                      `university_email`, `phone`,
                                      `role`, verification state

  `emergency_contacts`                `id`, `user_id`, `name`, `phone`

  `alerts`                            `id`, `user_id`, `status`,
                                      `started_at`, `resolved_at`

  `locations`                         `id`, `alert_id`, `latitude`,
                                      `longitude`, `recorded_at`

  `messages`                          `id`, `alert_id`, `sender_id`,
                                      `body`, `sent_at`, `read_at`

  OTP verification records            Email/user reference, OTP hash,
                                      purpose, expiry time, attempt
                                      count, resend/rate-limit metadata,
                                      used/invalidated state
  -----------------------------------------------------------------------

The final schema may normalize OTP verification records into a dedicated
table. Never store plaintext OTP values. Apply Row Level Security to all
user-facing data.

### 7.6 Row Level Security

-   A student can read and write only their own profile, emergency
    contacts, alerts, locations, and messages, subject to the intended
    workflow.
-   Admins can read all alerts and related information needed to
    respond, and can send messages on any alert thread.
-   OTP and password-reset records must not be directly readable or
    writable by student clients. Only trusted server-side code may
    manage or verify them.
-   Test policies using at least two student accounts and an admin
    account.

## 8. Non-Functional Requirements

-   **Performance:** An SOS should appear on the dashboard within
    approximately 3 seconds on a normal mobile connection.
-   **Security:** HTTPS only; enforce the university email domain on the
    server; require successful OTP verification before protected access;
    apply Row Level Security to every relevant table; authorize every
    admin dashboard request; keep Brevo and privileged Supabase
    credentials server-side.
-   **Privacy:** Collect location only after an SOS and make it visible
    only to authorized admins. Keep captured media on the student's
    phone.
-   **Compatibility:** Android 8.0 or newer, including low-end devices.
-   **Battery:** Use an Android foreground service for location updates
    and stop it as soon as the alert ends.
-   **Email reliability:** Handle Brevo API errors, rate limits, and
    temporary delivery failures without bypassing OTP expiry or
    verification rules.

## 9. Build Phases

1.  Set up the Supabase project, database schema, Row Level Security,
    and university email-domain enforcement. Connect Supabase MCP for
    development-time schema inspection and database management.
2.  Implement the server-managed OTP lifecycle and Brevo Transactional
    Email API integration. Configure the Brevo Free plan sender
    identity, environment variables, OTP TTL, attempt limits, and resend
    throttling. Ensure Supabase SMTP/email delivery is not used.
3.  Build Flutter registration, OTP verification, login, logout,
    forgot-password, and the Next.js admin login/reset flows.
4.  Build the SOS flow end to end: app button, alert record, and live
    alerts list on the dashboard.
5.  Add live location sending and the admin dashboard map using
    Leaflet + OpenStreetMap, including attribution and the
    recent-location trail.
6.  Add real-time chat on both sides.
7.  Add photo/video capture and the local media gallery.
8.  Build monthly/yearly reports and CSV export.
9.  Test authentication, OTP expiry/reuse/rate limits, email delivery,
    Row Level Security, SOS, location tracking, and messaging on real
    Android phones; fix bugs and prepare the demo and report.

## 10. Risks and Mitigations

  -----------------------------------------------------------------------
  Risk                                Mitigation
  ----------------------------------- -----------------------------------
  Android stops background location   Use a foreground service with a
  updates                             visible notification; test on
                                      several phone brands.

  Brevo Free plan limits or sender    Verify sender identity and API
  configuration prevent email         credentials early; design within
  delivery                            the plan's current limits; handle
                                      failures and provide a controlled
                                      resend option.

  OTP is guessed, reused, or used     Use a cryptographically secure OTP,
  after expiry                        hashed storage, 10-minute TTL,
                                      one-time use, five-attempt limit,
                                      resend cooldown, and server-side
                                      rate limiting.

  Students outside the university     Enforce the university domain
  register                            (`@jnu.ac.bd` and its subdomains)
                                      on the trusted server, not only in
                                      the form.

  An unverified account accesses      Gate protected access on successful
  protected features                  server-side OTP verification and
                                      test the complete
                                      registration/session flow.

  Accidental SOS triggers             Require press-and-hold plus a
                                      5-second cancellation window.

  Location or chat data is exposed to Apply and test Row Level Security
  the wrong user                      with multiple student accounts and
                                      an admin account.

  OpenStreetMap tile service is       Follow the tile usage policy and
  unavailable or usage limits are     show a graceful unavailable state;
  exceeded                            do not assume a public tile-service
                                      SLA.

  Brevo API key or Supabase MCP       Keep credentials in trusted
  credentials are exposed             server/developer secret storage;
                                      never commit them or expose them to
                                      client-side code.
  -----------------------------------------------------------------------

## 11. Open Questions

-   Does the course require a written report, a live demo, or both, and
    what is the deadline?
-   Which verified sender email/domain will be available for the Brevo
    account?
-   Confirm the final OTP email template and sender details before
    implementation. The proposed OTP TTL and protection defaults in this
    PRD should be treated as the initial implementation values and may
    be adjusted if project constraints require it.

------------------------------------------------------------------------

## Implementation Constraints Summary

1.  Supabase MCP is for development-time database work only.
2.  Supabase is the application's backend and database.
3.  Leaflet + OpenStreetMap is the dashboard mapping solution.
4.  Brevo Transactional Email API (Free plan initially) sends all
    authentication-related and transactional emails.
5.  Supabase SMTP and Supabase's built-in email delivery must not be
    used for authentication emails.
6.  University email verification is OTP-based, with a 10-minute TTL,
    single-use validation, attempt limits, resend cooldown, and
    server-side enforcement.
7.  Brevo credentials and privileged backend credentials must never be
    exposed to client applications.
