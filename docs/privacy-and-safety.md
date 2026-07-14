# Privacy and Safety Baseline

Conversation content can expose identity, location, relationships, sexuality,
health, and other sensitive information. ConvoCoach treats all imported or typed
conversation content as sensitive, regardless of whether a platform labels it as
personal data.

## Data lifecycle

Before a feature handles conversation content, its design must state:

- what data enters the system and through which user action;
- whether processing occurs on-device, on ConvoCoach infrastructure, or through a
  named processor;
- the minimum retained representation and retention period;
- who can access it and how access is audited;
- how users export and delete it;
- what is excluded from logs, analytics, training, and support tooling.

Raw content should be processed ephemerally unless the user explicitly chooses a
feature that requires storage. Derived data can remain sensitive and must not be
treated as anonymous merely because names were removed.

## Product safety

Coaching should help users communicate honestly and respect boundaries. The
product must not optimize for persistence after rejection, conceal identity,
manufacture emotional dependency, or automate pressure. Generated content must
remain a draft and should be framed as one possible response, not the correct
interpretation of another person.

Features involving crisis, abuse, self-harm, threats, stalking, minors, or sexual
coercion require dedicated policy and escalation design before implementation.
The current phase contains no such processing.
