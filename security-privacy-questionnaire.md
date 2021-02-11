# Self-Review Questionnaire: Security and Privacy

01. What information might this feature expose to Web sites or other parties,
    and for what purposes is that exposure necessary?

This feature will expose depth map of the user's environment to the Web sites.
This is the main goal of the feature.

02. Is this specification exposing the minimum amount of information necessary
    to power the feature?

Yes. This is the minimal amount of information needed to enable Web sites to
perform general purpose physical computations against device-perceived user
environment.

03. How does this specification deal with personal information or
    personally-identifiable information or information derived thereof?

The specification does not directly deal with PI / PII, but it does offer the
sites a glimpse into the user's space, which could potentially expose PI/PII,
depending on the conditions. The feature is an extension to WebXR Device API,
which already provides a mechanism to ensure that appropriate user consent is
collected prior to creating a WebXR session. The specification should leave
room for the implementers to reduce fidelity of the returned data if that is
something that they desire.

04. How does this specification deal with sensitive information?

The specification exposes information that could be considered sensitive by
the user, depending on the conditions. See answer to q. 3 for mitigation
mechanisms.

05. Does this specification introduce new state for an origin that persists
    across browsing sessions?

No.

06. What information from the underlying platform, e.g. configuration data, is
    exposed by this specification to an origin?

The existence or nonexistence of the feature may imply some information about
the underlying platform.

07. Does this specification allow an origin access to sensors on a user’s
    device.

Indirectly. Depending on the underlying implementation, the returned data may
have been computed using specialized sensors.

08. What data does this specification expose to an origin?  Please also
    document what data is identical to data exposed by other features, in the
    same or different contexts.

The feature is designed to expose information about how far away from the
device's camera plane are there some real-world objects.

09. Does this specification enable new script execution/loading mechanisms?

No.

10. Does this specification allow an origin to access other devices?

No.

11. Does this specification allow an origin some measure of control over a user
    agent's native UI?

No.

12. What temporary identifiers might this this specification create or expose
    to the web?

The specification exposes a depth map, which could potentially be very similar
to a depth map that would get returned in a subsequent XR session ran by the
same user if they did not move to a different space.

13. How does this specification distinguish between behavior in first-party and
    third-party contexts?

No.

14. How does this specification work in the context of a user agent’s Private
    Browsing or "incognito" mode?

No difference in behavior.

15. Does this specification have a "Security Considerations" and "Privacy
    Considerations" section?

No. Written specification is not available yet.

16. Does this specification allow downgrading default security characteristics?

No.

17. What should this questionnaire have asked?

N/A.
