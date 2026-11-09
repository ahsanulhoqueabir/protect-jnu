/// One headed block of a legal document.
class LegalSection {
  const LegalSection(this.heading, this.body);

  final String heading;
  final String body;
}

/// DRAFT texts written from what the app actually does (see docs/PRD.md). They have NOT been
/// reviewed by the university or a lawyer and must be approved before a public release.
abstract final class LegalContent {
  static const updated = 'Last updated: 10 November 2026';

  static const terms = [
    LegalSection(
      'About the service',
      "Protect JnU'ins is a student safety app for Jagannath University. It lets a student send "
          'an SOS alert, share live location with university support staff during that alert, and '
          'chat with them. It is not a replacement for the national emergency number 999.',
    ),
    LegalSection(
      'Who can use it',
      'Only students with a verified Jagannath University email address (@jnu.ac.bd or a '
          'subdomain). You must give true information and keep your password private.',
    ),
    LegalSection(
      'Using SOS responsibly',
      'Send an alert only when you need help. False or repeated test alerts take staff away from '
          'real emergencies and may lead to your account being restricted.',
    ),
    LegalSection(
      'Emergency contacts',
      'You must save at least 2 emergency contacts. Make sure the people you list are aware that '
          'you have given their name and phone number.',
    ),
    LegalSection(
      'No guarantee',
      'Alerts depend on your phone, location services and internet connection. Delivery and a '
          'response time cannot be guaranteed.',
    ),
    LegalSection('Changes', 'These terms may change. The date above shows the latest version.'),
  ];

  static const privacy = [
    LegalSection(
      'What we collect',
      'Account: name, student ID, university email, phone (if set) and password (stored by our '
          'authentication provider, not readable by us). Emergency contacts: name and phone. '
          'During an SOS: your location and the chat messages you send.',
    ),
    LegalSection(
      'When your location is shared',
      'Only while you have an open SOS alert. Sharing starts when the alert is sent and stops '
          'when the alert is cancelled or resolved. A notification is shown while it is active.',
    ),
    LegalSection(
      'Who can see it',
      'University support staff (admins) can see your alerts, location during an alert, emergency '
          'contacts and chat messages. Other students cannot.',
    ),
    LegalSection(
      'Photos and videos',
      'Photos and videos you capture stay on this phone only. They are never uploaded. You can '
          'view and delete them any time under Settings.',
    ),
    LegalSection('Email', 'We use your email only to send verification and password-reset codes.'),
    LegalSection(
      'Your choices',
      'You can delete your emergency contacts and your saved photos and videos at any time. '
          'Contact the university support team to ask about your account data.',
    ),
  ];
}
