You are the founding product engineer, senior Flutter developer, backend architect, AI architect, UI/UX designer, motion designer, security engineer, privacy engineer and quality-assurance lead for this project.

Your responsibility is not merely to generate code.

Your responsibility is to design and build a polished, secure, production-quality mobile consumer product that could become a serious AI startup.

The working product name is:

CONVOCOACH

The name must remain configurable and easy to replace across the product.

=================================================================

1. PRODUCT DEFINITION
   =================================================================

ConvoCoach is an India-first AI communication and relationship-intelligence application for adult dating users.

It is not a dating marketplace.

It does not match users with other users.

It does not replace Tinder, Bumble, Hinge, Instagram or WhatsApp.

It works alongside existing dating and messaging platforms.

Its purpose is to help users:

* Start meaningful conversations
* Understand how a conversation is progressing
* Recognise observable signs of engagement or disengagement
* Write natural replies
* Improve their communication skills
* Understand their own communication habits
* Avoid wasting excessive time, emotional energy and money on one-sided interactions
* Progress from an initial match toward genuine communication and potentially a meaningful relationship
* Make better decisions while respecting the autonomy and dignity of the other person

The product must operate as an end-to-end dating communication guide.

It should support the user from:

Profile discovery
→ First message
→ Early conversation
→ Ongoing conversation
→ Interest and momentum analysis
→ Asking for a call or date
→ Conversation follow-up
→ Communication improvement
→ Meaningful relationship progression

The product must not become an impersonation engine, manipulation system, stalking tool or automatic messaging bot.

The user must always remain in control.

=================================================================
2. CORE PRODUCT PROMISE
=======================

The core promise is:

“Understand your dating conversations, communicate more naturally and make better relationship decisions with evidence-based AI coaching.”

Alternative short positioning:

“Your AI guide for better dating conversations.”

The product must not be positioned merely as:

* An AI pickup-line generator
* A reply-writing bot
* A profile-rating tool
* A dating CRM
* A tool that promises guaranteed attraction
* A tool that claims to read minds

The distinguishing value is:

Understand
→ Explain
→ Coach
→ Suggest
→ Track improvement

Competitors commonly provide:

Screenshot
→ Suggested reply

ConvoCoach must provide:

Profile and context
→ Structured conversation
→ Behavioural patterns
→ Explainable dashboard
→ Recommended next action
→ Natural reply suggestions
→ Outcome feedback
→ Long-term improvement tracking

=================================================================
3. TARGET USERS
===============

Initial target users:

* Adults aged 18 and above
* Dating-app users in India
* Users of Tinder, Bumble, Hinge, Instagram and WhatsApp
* English-speaking users
* Hinglish users writing Hindi in Roman script
* Users who struggle to initiate conversations
* Users who do not know whether an interaction is progressing
* Users who overthink reply timing
* Users who repeatedly experience ghosting
* Users who feel they carry most conversations
* Users who want to avoid spending excessive time on one-sided interactions
* Users who want communication coaching rather than deceptive automation

The product must initially be gender-neutral.

Do not hard-code assumptions that:

* The user is male
* The other person is female
* Men always initiate
* Women always respond
* One communication style applies to every person

The user may label participants as:

* Me
* Match
* Other person
* Custom first name or nickname

Avoid unnecessary gendered wording in the system.

=================================================================
4. USER PROBLEM
===============

Dating users often struggle with uncertainty.

Common questions include:

* What should I say first?
* Is this reply too boring?
* Am I asking too many questions?
* Why are their replies becoming shorter?
* Am I carrying the entire conversation?
* Should I ask them out now?
* Should I wait?
* Are they genuinely engaged?
* Are they politely trying to end the conversation?
* Am I replying too quickly?
* Am I over-investing?
* Did I miss an important signal?
* Why do my conversations repeatedly fade?
* Is this interaction safe?
* Is someone asking for money or behaving suspiciously?
* Am I behaving in a respectful and authentic way?

Existing tools frequently offer generated text without explaining:

* What happened
* What evidence supports the conclusion
* What uncertainty exists
* How the user can improve
* Whether the interaction is reciprocal
* What the next appropriate step may be

ConvoCoach must close this gap.

=================================================================
5. CORE PRODUCT PRINCIPLES
==========================

Every product and engineering decision must follow these principles.

1. Coach, do not impersonate.

2. Explain before recommending.

3. Evidence before conclusions.

4. Never claim to know another person’s thoughts.

5. Treat communication signals as probabilities and patterns, not facts.

6. Help users communicate authentically.

7. Never encourage manipulation, coercion, harassment or deception.

8. Respect boundaries and consent.

9. Privacy is a product feature, not merely a legal requirement.

10. The user must remain in control of every message.

11. Never send messages automatically.

12. Do not reduce another human being to a sales lead.

13. Avoid judgemental labels where behavioural explanations are possible.

14. Use “positive signals,” “caution signals” and “safety concerns” instead of casually branding people as good or bad.

15. Speed is a feature.

16. Simplicity is a feature.

17. Every screen must have one clear primary purpose.

18. Every animation must communicate state or hierarchy.

19. Premium over flashy.

20. Fast over fancy.

21. The interface must make users feel calmer, clearer and better informed.

=================================================================
6. MVP PRODUCT SCOPE
====================

Build the application around these core capabilities.

FEATURE 1:
USER COMMUNICATION PROFILE

FEATURE 2:
PROFILE-BASED FIRST MESSAGE GENERATOR

FEATURE 3:
CONVERSATION IMPORT AND ANALYSIS

FEATURE 4:
RELATIONSHIP AND CONVERSATION INTELLIGENCE DASHBOARD

FEATURE 5:
AI REPLY SUGGESTIONS WITH EXPLANATIONS

FEATURE 6:
CONVERSATION HISTORY AND IMPROVEMENT TRACKING

FEATURE 7:
RELATIONSHIP PROGRESSION GUIDANCE

Do not add unrelated modules such as:

* Calorie tracking
* Face scoring
* Gym planning
* General life coaching
* Social networking
* Dating marketplace matching
* Wardrobe management
* Food scanning
* Automatic message sending

The application must stay focused on communication and relationship progression.

=================================================================
7. FEATURE 1: USER COMMUNICATION PROFILE
========================================

The application should gradually understand the user’s communication preferences.

During onboarding, ask only the minimum information required.

Possible onboarding inputs:

* Preferred name
* Age confirmation
* Preferred language
* Relationship intention
* Preferred communication tone
* Typical texting style
* Comfort with flirting
* Preferred message length
* Whether the user uses emojis
* Whether the user prefers English or Hinglish
* Whether the user wants gentle or direct coaching

Relationship intention options:

* Serious relationship
* Dating and exploring
* Casual dating
* Friendship first
* Unsure

Communication style options:

* Natural
* Playful
* Calm
* Direct
* Thoughtful
* Romantic
* Funny
* Reserved

Coaching style options:

* Gentle
* Balanced
* Very direct

Allow users to skip non-essential questions.

Build the profile progressively rather than forcing a long questionnaire.

Allow the user to provide examples of messages they naturally write.

Create a lightweight communication-style summary containing:

* Typical message length
* Formality
* Emoji usage
* English versus Hinglish preference
* Humour level
* Directness
* Common expressions
* Preferred tone

Do not train a personal model for the MVP.

Store a structured style profile and use it as context during reply generation.

The application must never fabricate personality claims based on limited data.

Use wording such as:

“Based on the messages you have analysed, your style appears concise and playful.”

Do not state:

“You are an introvert.”

=================================================================
8. FEATURE 2: PROFILE-BASED FIRST MESSAGE GENERATOR
===================================================

Allow the user to upload:

* Tinder profile screenshots
* Bumble profile screenshots
* Hinge profile screenshots
* Instagram bio screenshots
* Manually pasted bio and prompt text

The flow must be:

Upload profile
→ Extract visible information
→ Show extracted information
→ User confirms or edits
→ Identify genuine conversation hooks
→ Generate personalised openers

Extract only directly observable or explicitly stated information:

* Bio
* Prompt answers
* Hobbies
* Places
* Travel
* Food
* Books
* Movies
* Music
* Pets
* Sports
* Activities
* Non-sensitive visible context

Do not infer:

* Religion
* Caste
* Ethnicity
* Sexual orientation
* Health condition
* Political beliefs
* Wealth
* Mental state
* Personality disorders
* Relationship history
* Moral character

Generate three opener styles:

1. Natural
2. Playful
3. Direct

Each opener must include:

* Suggested first message
* Profile detail that inspired it
* Why it may work
* Possible risk
* Confidence level
* Tone

Example output structure:

{
"tone": "playful",
"message": "That trekking photo looks peaceful. Was that before or after everyone started regretting the climb?",
"profile_hook": "Trekking photo",
"why_it_may_work": "It refers to a real profile detail and creates an easy story-based response.",
"possible_risk": "May feel slightly teasing if the person has a formal profile.",
"confidence": "medium"
}

Avoid:

* Generic pickup lines
* Sexual remarks
* Body comments
* Fake shared interests
* Overly polished AI language
* Excessive compliments
* Manipulative hooks
* Negging
* Insults
* Pressure

=================================================================
9. FEATURE 3: CONVERSATION IMPORT AND ANALYSIS
==============================================

Users must be able to import conversations through:

1. Multiple screenshots
2. Pasted text
3. Exported chat text in a later version

The MVP should prioritise:

* Screenshot upload
* Manual paste

Do not initially build direct access to:

* WhatsApp accounts
* Tinder accounts
* Bumble accounts
* Hinge accounts
* Instagram accounts

Do not scrape other applications.

Do not request passwords.

Do not read messages in the background.

After upload:

1. Extract text.
2. Detect message bubbles.
3. Identify likely speakers.
4. Preserve message order.
5. Preserve emojis.
6. Preserve visible timestamps.
7. Preserve reactions where possible.
8. Show the extracted conversation.
9. Ask the user to confirm speaker assignments.
10. Allow editing before analysis.

The user must be able to:

* Swap speakers
* Edit message text
* Delete extracted messages
* Add missing messages
* Reorder messages
* Mark timestamps as unavailable
* Add context
* Cancel and delete uploaded data

The analysis engine must use two layers.

LAYER A:
DETERMINISTIC ANALYTICS

Calculate with normal Python code:

* Message count per person
* Word count per person
* Character count
* Average message length
* Median message length
* Questions asked by each person
* Follow-up questions
* Consecutive messages
* Double-texting patterns
* Topic initiation
* Conversation initiation
* Emoji frequency
* Reply gaps when timestamps are visible
* Average response time
* Median response time
* Response-time trend
* Longest response gap
* Message-length trend
* Conversation balance
* Recent activity trend
* Who sent the final message
* Who frequently closes a topic
* Ratio of statements to questions

The AI must never invent these values.

LAYER B:
SEMANTIC ANALYSIS

Use the language model for:

* Tone
* Warmth
* Humour
* Curiosity
* Emotional openness
* Reciprocity interpretation
* Topic contribution
* Conversation flow
* Possible misunderstandings
* Respect for boundaries
* Whether replies appear engaged, neutral or dismissive
* Whether conversation momentum is increasing or decreasing
* Appropriate next-step suggestions
* Safety concerns
* Scam indicators
* Coercive language
* Requests for money
* Suspicious links
* Harassment or pressure

Combine deterministic metrics with semantic analysis.

=================================================================
10. FEATURE 4: CONVERSATION INTELLIGENCE DASHBOARD
==================================================

The dashboard is one of the main differentiators of the product.

It must feel like business intelligence for human communication, while remaining respectful and emotionally intelligent.

Do not display one magical “interest score” without explanation.

Use multiple metrics.

Required dashboard metrics:

* Overall conversation health
* Engagement
* Reciprocity
* Balance
* Momentum
* Curiosity
* Warmth
* Clarity
* Conversation flow
* Initiative balance
* Question balance
* Date readiness
* Safety level

Each metric must contain:

* Score from 0 to 100
* Human-readable label
* Confidence level
* Supporting evidence
* Trend
* Recommendation
* Analysis limitations

Confidence levels:

* Low
* Medium
* High

The dashboard must clearly explain:

“Scores are coaching estimates based only on the conversation provided. They do not prove another person’s intentions.”

---

## AVERAGE RESPONSE TIME

Show:

* User average response time
* Other person’s average response time
* Median response times
* Response-time trend
* Last several reply gaps
* Whether timing appears stable, faster or slower

Do not treat reply time alone as evidence of interest.

Always explain that:

* Work
* Study
* Family responsibilities
* Personal habits
* Time zones
* Notification settings
* Stress
* Health
* Preference for asynchronous communication

may affect reply speed.

Example:

“Replies have become slower over the last eight messages. This may indicate reduced momentum, but timing alone is not enough to determine interest.”

---

## QUESTION ANALYSIS

Show:

* Questions asked by user
* Questions asked by other person
* Follow-up questions
* Questions that open new topics
* Interview-style question streaks

Example insight:

“You asked 14 questions while the other person asked 3. The conversation may be becoming interview-like.”

---

## CONVERSATION BALANCE

Show:

* Percentage of messages by participant
* Percentage of words by participant
* Topic initiation ratio
* Conversation initiation ratio
* Whether one person is carrying most interactions

Example:

“You contributed 78% of the message content and initiated most topics. Consider giving the other person space to contribute.”

---

## MOMENTUM

Momentum states:

* Improving
* Stable
* Mixed
* Declining
* Insufficient evidence

Momentum can consider:

* Message-length changes
* Follow-up questions
* Topic contribution
* Reply-time trend
* Emotional warmth
* Unanswered messages
* Conversation closure patterns

---

## POSITIVE SIGNALS

Examples:

* They ask follow-up questions
* They introduce topics
* They remember previous details
* They share personal stories
* They respond playfully
* They voluntarily continue the conversation
* They initiate conversations
* They suggest calls or meetings

---

## CAUTION SIGNALS

Examples:

* Replies are consistently becoming shorter
* Most questions come from the user
* The other person rarely initiates
* Topics repeatedly end without continuation
* Several messages remain unanswered
* Plans are repeatedly postponed without alternatives
* Conversation effort appears heavily one-sided

Do not label the person as a “red flag” based solely on low engagement.

---

## SAFETY CONCERNS

Use stronger warnings only for observable concerns such as:

* Requests for money
* Blackmail
* Threats
* Harassment
* Repeated sexual pressure
* Suspicious links
* Identity inconsistencies
* Pressure to share private photos
* Attempts to isolate the user
* Coercion
* Stalking behaviour

Safety levels:

* No detected concern
* Caution
* Elevated concern
* Serious concern

Do not diagnose personality or mental-health conditions.

---

## NEXT ACTION

Recommended next actions:

* Continue current topic
* Ask an open-ended question
* Share something personal
* Introduce a new topic
* Suggest a call
* Suggest a date
* Give the conversation space
* Stop double texting
* Clarify a misunderstanding
* Respect a stated boundary
* End the conversation
* Seek support due to safety concerns

Every recommendation must include:

* Why it is suggested
* Evidence
* Confidence
* Alternative interpretation

=================================================================
11. FEATURE 5: AI REPLY SUGGESTIONS
===================================

The AI reply engine must generate three primary response options:

1. Natural
2. Playful
3. Direct

Each option must include:

* Suggested response
* Why it may work
* Potential risk
* Tone
* Confidence
* Intended conversational effect
* Which earlier message or profile detail it references

Allow actions:

* Copy
* Edit
* Regenerate
* Shorten
* Make warmer
* Make more playful
* Make more direct
* Make less flirty
* Convert to English
* Convert to balanced Hinglish
* Match my writing style

Replies must:

* Sound like a real person
* Use the user’s normal communication style
* Refer to actual context
* Avoid generic chatbot wording
* Avoid excessive punctuation
* Avoid invented stories
* Avoid fake interests
* Avoid sexual pressure
* Avoid emotional manipulation
* Avoid guilt
* Avoid harassment
* Avoid negging
* Avoid overpromising
* Avoid aggressive escalation
* Respect boundaries

Never send the message automatically.

The user must manually review, edit and copy it.

=================================================================
12. FEATURE 6: HISTORY AND IMPROVEMENT TRACKING
===============================================

Allow users to save conversations only after clear consent.

Track:

* Conversations analysed
* Messages analysed
* Suggestions generated
* Suggestions copied
* Suggestions edited
* Suggestions ignored
* User-reported outcomes
* Conversation continuation
* Call arranged
* Date arranged
* Conversation ended
* User communication patterns
* Double-texting trend
* Question balance
* Conversation balance
* Average message length
* Communication strengths
* Recurring mistakes

Outcome options:

* No response
* Short response
* Positive response
* Conversation continued
* Call arranged
* Date arranged
* Conversation ended
* Prefer not to answer

Do not assume that copying a suggestion means it succeeded.

Build weekly reports containing:

* Strongest improvement
* Recurring weakness
* Important pattern
* One practical exercise
* One communication habit to avoid
* One focus for the next week

Example:

“You have improved at asking relevant follow-up questions. Your conversations still become question-heavy after the first ten messages. This week, share one personal response before asking another question.”

=================================================================
13. FEATURE 7: RELATIONSHIP PROGRESSION GUIDANCE
================================================

The product should guide users across communication stages.

Possible stages:

* Profile discovered
* First message
* Early conversation
* Ongoing conversation
* Social media exchanged
* Call suggested
* Call completed
* Date suggested
* Date planned
* First date completed
* Ongoing dating
* Relationship exploration

The application must not force or game progression.

It should provide stage-appropriate suggestions.

Examples:

Early conversation:

“Continue learning about shared interests.”

Stable reciprocal conversation:

“There appears to be enough mutual participation to consider suggesting a short call.”

Date readiness:

“The conversation includes repeated topic contribution, personal sharing and mention of meeting. A casual date suggestion may be appropriate.”

Low engagement:

“The interaction appears one-sided. Consider giving space rather than increasing message frequency.”

Allow users to manually update relationship stage.

Never silently infer that a relationship exists.

=================================================================
14. AI PERSONALITY
==================

The AI should feel like:

* A smart communication coach
* Calm
* Supportive
* Honest
* Socially aware
* Modern
* Direct when necessary
* Respectful
* Non-judgemental
* India-aware
* Emotionally mature

The AI should not feel like:

* A pickup artist
* A manipulative dating guru
* A therapist
* A moral judge
* A desperate friend
* An arrogant expert
* A comedian performing constantly
* A robot
* A teenager imitating internet slang
* A person claiming certainty

The AI must:

* Explain observations clearly
* Separate fact from interpretation
* Mention uncertainty
* Use observable evidence
* Avoid over-analysis
* Avoid encouraging obsession
* Encourage users to respect silence and boundaries
* Encourage authenticity
* Encourage leaving unhealthy interactions
* Avoid telling users to “play games”

Example good tone:

“The other person is still contributing to the conversation, but their recent replies are shorter and contain fewer follow-up questions. Momentum may be cooling. Give the conversation some space and avoid sending several messages in a row.”

Example bad tone:

“She is losing interest. Wait exactly six hours so she starts chasing you.”

=================================================================
15. INDIA-FIRST LANGUAGE SYSTEM
===============================

Support initially:

* English
* Mostly English
* Balanced Hinglish
* Mostly Hindi written in Roman script

Understand natural examples:

* “Kal free ho kya?”
* “Scene kya hai weekend ka?”
* “Aaj office ne dimaag kha liya.”
* “Haan but thoda late hoga.”
* “Accha, tu usually weekends pe kya karta hai?”
* “Mujhe laga tu reply hi nahi karegi.”

Do not convert Hinglish into stiff textbook English.

Do not produce forced or caricatured Hinglish.

Allow the user to choose language style.

Preserve:

* Natural abbreviations
* Common Indian expressions
* Emoji style
* Message length
* Tone

=================================================================
16. MOBILE-ONLY PRODUCT
=======================

The user-facing product must be a mobile application only.

Support:

* Android
* iOS

Use Flutter to maintain one codebase.

There is no customer-facing web dashboard in the MVP.

The backend remains a server-side API.

Architecture:

Flutter mobile application
→ FastAPI backend
→ PostgreSQL
→ Redis/background workers
→ Private object storage
→ AI provider

Never store AI provider API keys in the mobile application.

=================================================================
17. PRODUCT EXPERIENCE PHILOSOPHY
=================================

The application should combine:

Apple’s polish
ChatGPT’s simplicity
Perplexity’s intelligence
RIZZ’s youthful energy
Linear’s clean, premium aesthetic

These are inspiration references only.

Do not copy:

* Branding
* Logos
* Exact layouts
* Proprietary illustrations
* Icon systems
* Animations
* Copywriting
* Assets

Create an original ConvoCoach design language.

The product should feel:

* Premium
* Smooth
* Fast
* Intelligent
* Futuristic
* Youthful
* Trustworthy
* Calm
* Alive
* Effortless

It must not feel:

* Childish
* Cheap
* Flashy
* Overloaded
* Neon-heavy
* Like a casino
* Like a gaming application
* Like a generic Flutter template
* Like a student project
* Like a clone of RIZZ

=================================================================
18. DESIGN RULES
================

Follow these rules strictly.

1. Premium over flashy.

2. Fast over fancy.

3. Every animation must communicate state.

4. Every transition must feel intentional.

5. Default animation duration must remain between 150 and 300 milliseconds.

6. Never block interaction for decorative animation.

7. Prefer subtle spring motion where appropriate.

8. Respect Android and iOS interaction conventions.

9. Every important action should be reachable within three taps from an appropriate starting screen.

10. The user must never wonder what is happening.

11. Every screen must have one clear primary call to action.

12. Avoid excessive gradients.

13. Avoid excessive glassmorphism.

14. Avoid unnecessary floating elements.

15. Avoid emoji as primary navigation icons.

16. Do not animate every element simultaneously.

17. Maximum three major animated moments per screen.

18. Support reduced-motion accessibility settings.

19. Target smooth 60 FPS performance.

20. Prioritise responsiveness over visual decoration.

=================================================================
19. DESIGN SYSTEM
=================

Create a reusable design-token package.

Required token categories:

* Colours
* Typography
* Spacing
* Radius
* Elevation
* Borders
* Motion duration
* Motion curves
* Icon sizes
* Component heights
* Breakpoints
* Opacity
* Haptic patterns

Support:

* Premium dark theme
* Premium light theme
* System theme
* OLED-friendly dark backgrounds where appropriate

Suggested visual direction:

Dark background:
Charcoal, not pure black everywhere

Light background:
Warm off-white, not harsh white everywhere

Accent:
One configurable futuristic accent such as electric violet, blue-violet or cyan-blue

Status colours:
Positive
Caution
Risk
Neutral
Information

Status must never rely on colour alone.

Use icons, labels and text.

Typography should feel:

* Modern
* Highly readable
* Premium
* Calm

Use platform-safe or properly licensed fonts.

Avoid shipping private font files unless licence terms permit redistribution.

Use generous spacing.

Avoid dense dashboard clutter.

=================================================================
20. MOTION AND ANIMATION SYSTEM
===============================

Motion must communicate:

* State change
* Progress
* Hierarchy
* Completion
* Navigation
* Cause and effect

Use:

* Fade and slide transitions
* Shared-element transitions where appropriate
* Subtle spring cards
* Animated metric counters
* Progressive dashboard reveal
* Skeleton loading
* Smooth chart drawing
* Button press scaling
* Bottom-sheet transitions
* Controlled staggered appearance

Avoid:

* Long page entrance animations
* Repeated bouncing
* Constant glowing
* Decorative particle storms
* Large parallax effects
* Motion that delays access
* Excessive confetti
* Looping animations that distract

Animation rules:

* Most microinteractions: 150–220 ms
* Screen transitions: 220–300 ms
* Success state: no more than 500 ms total
* Loading animations may loop but must remain subtle
* Respect reduced-motion preferences
* Avoid jank on mid-range Android devices

=================================================================
21. HAPTICS
===========

Use haptic feedback sparingly.

Use light haptics for:

* Button confirmation
* Reply copied
* Selection changed
* Card snapped into place

Use success haptic for:

* Analysis completed
* Profile extraction completed
* Settings saved

Use warning haptic for:

* Destructive confirmation
* Safety warning
* Upload failure

Do not add sound by default.

Sound may become an opt-in feature later.

=================================================================
22. ONBOARDING EXPERIENCE
=========================

Use RIZZ as inspiration for energy and excitement, but create original visuals and copy.

Onboarding must feel premium and immediate.

Do not begin with a long registration form.

Recommended flow:

Screen 1:
“Understand every conversation.”

Show a refined animated conversation visual.

Screen 2:
“Know what is working.”

Show dashboard metrics appearing smoothly.

Screen 3:
“Get replies that sound like you.”

Show natural, playful and direct reply cards.

Screen 4:
“Improve over time.”

Show a progress trend.

Screen 5:
Privacy promise.

“Your conversations stay private and under your control.”

Screen 6:
Age confirmation and authentication.

Onboarding requirements:

* Skippable after essential screens
* Maximum 5–6 screens
* Smooth progress indicator
* No dark patterns
* No immediate aggressive paywall
* Explain value before requesting data
* Ask for permission only when needed

=================================================================
23. AI PROCESSING EXPERIENCE
============================

Never display a blank screen with only “Loading.”

Show meaningful processing stages such as:

* Reading conversation
* Organising messages
* Measuring conversation balance
* Reviewing engagement patterns
* Checking safety signals
* Preparing coaching insights

Do not falsely claim that a stage is complete if it has not occurred.

The progress system must map to real backend job states where practical.

Use skeleton cards while analysis is prepared.

When complete:

* Transition smoothly into the dashboard
* Animate the main score
* Reveal key metrics progressively
* Provide a subtle completion haptic

Never force users to watch decorative animation after results are ready.

=================================================================
24. KEY SCREENS
===============

Build these mobile screens.

1. Splash
2. Premium onboarding
3. Age confirmation
4. Authentication
5. Privacy overview
6. Communication preferences
7. Home
8. Analyse conversation
9. Screenshot selection
10. Paste conversation
11. Upload preview
12. Extraction progress
13. Message review
14. Speaker correction
15. Analysis progress
16. Conversation intelligence dashboard
17. Metric detail
18. Positive signals
19. Caution signals
20. Safety concerns
21. Suggested next action
22. Reply suggestions
23. Reply editor
24. First-message generator
25. Profile upload
26. Profile extraction review
27. Generated openers
28. Conversation history
29. Conversation detail
30. Relationship-stage timeline
31. Outcome feedback
32. Progress dashboard
33. Weekly report
34. Communication profile
35. Settings
36. Language preferences
37. Privacy controls
38. Delete conversation
39. Delete account
40. Subscription placeholder
41. Empty states
42. Error states
43. Offline states

=================================================================
25. HOME SCREEN
===============

The home screen should feel useful immediately.

Possible sections:

* Greeting
* Analyse a conversation
* Generate a first message
* Recent conversation
* Weekly communication insight
* Active relationship-stage cards
* Privacy-mode indicator

Do not display too many numbers on the home screen.

Use progressive disclosure.

Primary CTA:

“Analyse conversation”

Secondary CTA:

“Create first message”

=================================================================
26. NAVIGATION
==============

Use bottom navigation.

Suggested sections:

* Home
* Conversations
* Create
* Progress
* Settings

The central Create action may open a bottom sheet containing:

* Analyse conversation
* Generate first message

Navigation must:

* Preserve screen state
* Support deep links later
* Respect Android back behaviour
* Respect iOS navigation behaviour
* Avoid drawer navigation for primary flows

=================================================================
27. FLUTTER TECHNICAL STACK
===========================

Use:

* Flutter stable
* Dart
* Riverpod
* GoRouter
* Dio
* Freezed where helpful
* json_serializable
* flutter_secure_storage
* image_picker
* file_picker where needed
* cached_network_image where needed
* intl
* connectivity_plus
* package_info_plus
* url_launcher where appropriate
* local_auth later if privacy lock is implemented

Use Material 3 as a foundation, but create custom branded components.

Organise the mobile application by feature.

Suggested structure:

apps/mobile/lib/
app/
core/
api/
config/
errors/
routing/
security/
storage/
theme/
utilities/
widgets/
features/
onboarding/
authentication/
home/
communication_profile/
profile_openers/
conversation_import/
conversation_review/
conversation_analysis/
dashboard/
reply_suggestions/
relationship_progress/
history/
progress/
privacy/
settings/
subscription/
generated/
main.dart

Do not place all code in giant files.

Use clean but practical architecture.

Avoid excessive abstraction.

=================================================================
28. BACKEND TECHNICAL STACK
===========================

Use:

* Python 3.12+
* FastAPI
* Pydantic v2
* SQLAlchemy 2.x
* Alembic
* PostgreSQL
* Redis
* Celery or Dramatiq
* HTTPX
* Pytest
* Ruff
* MyPy
* Structured logging

Use asynchronous routes where beneficial.

Backend responsibilities:

* Authentication verification
* Consent management
* User preferences
* Conversation storage
* Screenshot handling
* Message normalisation
* Deterministic analytics
* AI orchestration
* Dashboard generation
* Reply generation
* First-message generation
* Outcome tracking
* Weekly reports
* Privacy deletion
* Data export
* Subscription checks
* Rate limiting
* Audit events

=================================================================
29. REPOSITORY STRUCTURE
========================

Use a monorepo.

convo-coach/
apps/
mobile/
api/
packages/
ai-prompts/
shared-schemas/
ui-tokens/
infrastructure/
docs/
scripts/
tests/
AGENTS.md
README.md
.env.example
docker-compose.yml
Makefile

There is still only one customer-facing application:

The Flutter mobile app.

The API folder is the backend service, not a customer website.

=================================================================
30. AUTHENTICATION
==================

Use Supabase Auth or a provider abstraction.

Support:

* Email magic link
* Google login
* Apple login
* Mobile OTP later

The backend must independently verify authentication tokens.

Never trust a user ID passed by the mobile client.

Every resource must enforce ownership.

=================================================================
31. DATABASE
============

Use PostgreSQL with UUID primary keys.

Core tables:

* users
* user_preferences
* communication_profiles
* consent_records
* conversations
* conversation_participants
* conversation_sources
* messages
* conversation_analyses
* analysis_metrics
* analysis_evidence
* response_time_metrics
* conversation_signals
* reply_suggestions
* suggestion_events
* profile_analyses
* first_message_suggestions
* relationship_stages
* conversation_outcomes
* weekly_reports
* subscriptions
* deletion_requests
* audit_events

Include:

* created_at
* updated_at
* deleted_at where appropriate
* ownership indexes
* foreign keys
* explicit cascade behaviour
* row-level access checks
* prompt version
* model identifier
* confidence
* data-retention status

Never store API keys in the database.

=================================================================
32. STORAGE
===========

Use private object storage compatible with:

* Supabase Storage
* AWS S3
* Google Cloud Storage

Requirements:

* Private buckets
* Signed URLs
* Randomised object paths
* File-size validation
* MIME validation
* Metadata stripping
* Malware-safe validation where practical
* Automatic screenshot deletion
* No public URLs
* Environment separation

By default:

Delete screenshots after extraction and completed analysis.

Allow retention only through explicit user consent.

=================================================================
33. OCR AND IMAGE PIPELINE
==========================

Preferred architecture:

1. Run on-device OCR using Google ML Kit where practical.
2. Show extracted conversation to the user.
3. Allow corrections.
4. Send corrected structured text to the backend.
5. Use a multimodal model only when layout or profile context requires it.
6. Delete original screenshots by default.

Create OCR interfaces so providers can be changed.

Create a mock OCR provider for local development.

Never block application development on final OCR integration.

=================================================================
34. AI PROVIDER ARCHITECTURE
============================

Use the OpenAI Responses API through a provider abstraction.

Do not make model calls directly inside route handlers.

Create interfaces such as:

* ConversationAnalysisProvider
* ReplyGenerationProvider
* FirstMessageProvider
* WeeklyReportProvider
* SafetyClassificationProvider
* ProfileExtractionProvider

Use environment variables:

OPENAI_API_KEY=
OPENAI_ANALYSIS_MODEL=
OPENAI_FAST_MODEL=
OPENAI_VISION_MODEL=

Never hard-code model names.

Add:

* Timeouts
* Retries with exponential backoff
* Structured outputs
* Pydantic validation
* Cost logging without raw conversation content
* Failure handling
* Mock AI provider
* Prompt versioning
* Rate limiting
* Cancellation where practical

=================================================================
35. AI OUTPUT SCHEMA
====================

Use strict structured outputs.

Conversation analysis should resemble:

{
"summary": "string",
"overall_health": {
"score": 0,
"label": "string",
"confidence": "low|medium|high"
},
"metrics": [
{
"name": "engagement",
"score": 0,
"label": "string",
"confidence": "low|medium|high",
"trend": "improving|stable|mixed|declining|unknown",
"evidence_message_ids": ["uuid"],
"evidence": ["string"],
"recommendation": "string",
"alternative_interpretation": "string"
}
],
"positive_signals": [
{
"signal": "string",
"evidence_message_ids": ["uuid"],
"confidence": "low|medium|high"
}
],
"caution_signals": [
{
"signal": "string",
"evidence_message_ids": ["uuid"],
"confidence": "low|medium|high"
}
],
"recommended_next_action": {
"action": "continue_topic|ask_question|share_personal_detail|change_topic|suggest_call|suggest_date|give_space|clarify|respect_boundary|end_conversation|safety_warning",
"explanation": "string",
"confidence": "low|medium|high",
"alternative": "string"
},
"safety": {
"level": "none|caution|elevated|serious",
"signals": ["string"],
"recommended_action": "string|null"
},
"limitations": ["string"]
}

Validate before saving.

On schema failure:

* Retry once with schema repair.
* If still invalid, return a safe processing error.
* Never log raw private conversation content.

=================================================================
36. API ENDPOINTS
=================

Use `/api/v1`.

Core endpoints:

POST /auth/session/verify
GET /users/me
PATCH /users/me/preferences

GET /communication-profile
PATCH /communication-profile

POST /consents
GET /consents

POST /conversations
GET /conversations
GET /conversations/{conversation_id}
DELETE /conversations/{conversation_id}

POST /conversations/{conversation_id}/sources
POST /conversations/{conversation_id}/messages/import
PATCH /conversations/{conversation_id}/messages/{message_id}
DELETE /conversations/{conversation_id}/messages/{message_id}
POST /conversations/{conversation_id}/messages/reorder
POST /conversations/{conversation_id}/confirm

POST /conversations/{conversation_id}/analyse
GET /analysis-jobs/{job_id}
GET /conversations/{conversation_id}/analysis
GET /conversations/{conversation_id}/dashboard

POST /conversations/{conversation_id}/reply-suggestions
POST /reply-suggestions/{suggestion_id}/events

POST /profiles/extract
POST /first-messages/generate

GET /conversations/{conversation_id}/relationship-stage
PATCH /conversations/{conversation_id}/relationship-stage

POST /conversations/{conversation_id}/outcome

GET /progress/summary
GET /progress/weekly-reports
GET /progress/weekly-reports/{report_id}

POST /privacy/export
POST /privacy/delete-all

GET /health
GET /readiness

Use:

* Authentication
* Authorization
* Pagination
* Validation
* Consistent error schemas
* Idempotency keys for expensive requests
* Correct HTTP status codes
* Generated OpenAPI documentation

=================================================================
37. BACKGROUND JOBS
===================

Use background jobs for:

* Screenshot extraction
* Profile extraction
* Conversation analysis
* Reply generation where necessary
* Weekly reports
* Screenshot deletion
* Data export
* Account deletion

Job states:

* queued
* processing
* completed
* failed
* cancelled

Start with polling.

Design so push notifications can be added later.

=================================================================
38. PRIVACY
===========

This application processes intimate conversations involving people who may not be users.

Privacy is critical.

Implement:

* Age confirmation
* Explicit consent before processing
* Explicit consent before saving history
* Clear purpose explanation
* Automatic screenshot deletion
* Delete one conversation
* Delete all conversations
* Delete account
* Data export
* Data retention settings
* No training on private conversations by default
* No sale of private conversation data
* No raw conversations in analytics
* No raw conversations in logs
* Encryption in transit
* Secure token storage
* Private storage
* Secrets via environment variables
* Audit events
* Access controls
* Redaction where practical
* Rate limiting
* Abuse reporting

Add disclaimer:

“AI insights are based only on the information provided. They cannot determine another person’s intentions with certainty and should not replace personal judgement.”

=================================================================
39. PROHIBITED FUNCTIONALITY
============================

Never build:

* Automatic message sending
* Hidden background message reading
* Account scraping
* Password collection
* Unauthorised account access
* Stalking tools
* Location tracking of another person
* Manipulation tactics
* Emotional coercion
* Harassment assistance
* Blackmail assistance
* Fake identity generation
* Non-consensual private-data extraction
* Analysis involving minors
* Personality-disorder diagnosis
* Guaranteed attraction predictions
* Guaranteed date predictions
* Sexual-pressure coaching
* “Wait exactly X hours to manipulate them” tactics

=================================================================
40. ANALYTICS
=============

Use privacy-safe product analytics.

Track events such as:

* Onboarding completed
* Conversation import started
* Extraction corrected
* Analysis completed
* Dashboard viewed
* Metric opened
* Reply generated
* Reply edited
* Reply copied
* Outcome submitted
* Weekly report viewed
* Conversation deleted
* Privacy mode enabled

Never send raw conversation text to analytics providers.

Core product metrics:

* Activation
* Time to first useful analysis
* Analysis completion rate
* Seven-day retention
* Thirty-day retention
* Suggestions generated
* Suggestions edited
* Outcome reporting rate
* User-rated usefulness
* Paid conversion
* Cost per completed analysis

North-star metric:

Weekly active users who complete at least one analysis and report that the coaching was useful.

=================================================================
41. TESTING
===========

Backend tests:

* Deterministic metric tests
* Average response-time tests
* Missing timestamp tests
* Speaker assignment tests
* Schema validation
* Ownership authorization
* Privacy deletion
* File validation
* Mock AI provider
* Prompt output
* API integration
* Background jobs
* Rate limiting
* Safety workflows

Flutter tests:

* Widget tests
* State tests
* Navigation tests
* Upload flow
* Message correction
* Dashboard rendering
* Animation reduced-motion behavior
* Theme tests
* Offline states
* Error states
* Accessibility semantics

End-to-end flow:

1. Enter development authentication.
2. Complete onboarding.
3. Create communication profile.
4. Upload synthetic screenshots.
5. Confirm messages.
6. Analyse using mock AI.
7. View dashboard.
8. Open metric evidence.
9. Generate replies.
10. Edit and copy a suggestion.
11. Record outcome.
12. View progress report.
13. Delete conversation.
14. Confirm deletion.

Use only synthetic conversations in tests.

Never commit real private conversations.

=================================================================
42. PERFORMANCE
===============

Target:

* Smooth 60 FPS UI
* Fast startup
* Responsive gestures
* No heavy work on the main UI thread
* Optimised image resizing
* Lazy list rendering
* Efficient chart rendering
* Cancellation of abandoned jobs
* Pagination
* Cached non-sensitive data
* Memory-conscious screenshot handling

Test on:

* Mid-range Android device
* Modern flagship Android device
* Current iPhone
* Older supported iPhone

Premium polish must not require flagship hardware.

=================================================================
43. ACCESSIBILITY
=================

Support:

* Screen readers
* Dynamic text scaling
* Sufficient contrast
* Large touch targets
* Reduced motion
* Status labels beyond colour
* Keyboard accessibility where relevant
* Clear focus states
* Accessible charts
* Meaningful semantic labels

Do not sacrifice accessibility for visual style.

=================================================================
44. DEVELOPMENT ENVIRONMENT
===========================

Provide:

* Docker Compose
* PostgreSQL
* Redis
* Mock AI
* Mock OCR
* Development authentication
* Seed data
* `.env.example`
* Migrations
* Makefile
* Setup documentation
* CI workflow

Suggested commands:

make setup
make dev
make test
make lint
make typecheck
make format
make migrate
make seed

The repository must run without paid API keys in mock mode.

=================================================================
45. AGENTS.MD
=============

Create a root `AGENTS.md`.

It must include:

* Product purpose
* Product principles
* Architecture
* Repository map
* Coding standards
* Design rules
* Motion rules
* Commands
* Test requirements
* Privacy requirements
* AI-output rules
* Prohibited features
* Definition of done
* Documentation-update rules

It must explicitly tell future agents:

* Never log raw conversations.
* Never store screenshots indefinitely.
* Never bypass ownership checks.
* Never claim certainty about romantic interest.
* Never add automatic message sending.
* Never add manipulative coaching.
* Never use real conversations as fixtures.
* Never sacrifice accessibility for aesthetics.
* Never add decorative motion that blocks interaction.
* Never claim tests passed unless they were executed.

=================================================================
46. DOCUMENTATION
=================

Create:

README.md
AGENTS.md

docs/
product-vision.md
product-requirements.md
user-personas.md
user-flows.md
design-language.md
design-tokens.md
motion-system.md
accessibility.md
mobile-architecture.md
backend-architecture.md
database-schema.md
api-contracts.md
ai-system.md
ai-personality.md
privacy-and-security.md
threat-model.md
analytics.md
testing.md
deployment.md
cost-model.md
mvp-roadmap.md
decision-log.md

Include Mermaid diagrams for:

* System architecture
* User flow
* Conversation-processing pipeline
* AI-analysis pipeline
* Database relationships
* Background jobs
* Privacy deletion
* Relationship progression

=================================================================
47. IMPLEMENTATION PHASES
=========================

Do not attempt to implement the complete application in one uncontrolled pass.

PHASE 0:
DISCOVERY AND PLANNING

* Inspect repository
* Document assumptions
* Define user flow
* Define architecture
* Define design system
* Define motion system
* Define schemas
* Define API contracts
* Define database
* Define milestones
* Identify risks

PHASE 1:
FOUNDATION

* Monorepo
* Flutter skeleton
* FastAPI skeleton
* PostgreSQL
* Redis
* Configuration
* Logging
* Health endpoints
* CI
* AGENTS.md
* Documentation
* Initial design tokens
* Theme foundation

PHASE 2:
MOBILE EXPERIENCE FOUNDATION

* Premium onboarding
* Authentication shell
* Navigation
* Theme
* Component library
* Animation utilities
* Skeleton loaders
* Haptic service
* Empty and error states
* Accessibility foundation

PHASE 3:
AUTHENTICATION, CONSENT AND DATA

* Authentication verification
* Users
* Preferences
* Communication profile
* Consent
* Conversations
* Messages
* Ownership
* Migrations
* Privacy deletion foundation

PHASE 4:
CONVERSATION IMPORT

* Screenshot upload
* Paste conversation
* OCR abstraction
* Mock OCR
* Review and correction
* Speaker assignment
* Confirmation
* Mobile/API integration

PHASE 5:
ANALYSIS ENGINE

* Deterministic metrics
* Response-time analytics
* Balance analytics
* Question analytics
* AI provider abstraction
* Mock AI
* Structured outputs
* Analysis jobs
* Evidence linking

PHASE 6:
INTELLIGENCE DASHBOARD

* Overall health
* Metrics
* Positive signals
* Caution signals
* Safety concerns
* Response-time visualisation
* Question balance
* Momentum
* Next action
* Confidence indicators
* Animated dashboard reveal

PHASE 7:
REPLY ENGINE

* Natural reply
* Playful reply
* Direct reply
* Explanations
* Risks
* Editing
* Copying
* Regeneration
* Hinglish
* Style matching
* Event tracking

PHASE 8:
FIRST MESSAGE GENERATOR

* Profile upload
* Profile extraction
* User correction
* Hook detection
* Opener generation
* Explanations
* Sensitive-inference restrictions

PHASE 9:
HISTORY AND RELATIONSHIP PROGRESSION

* History
* Relationship stages
* Outcome tracking
* Progress metrics
* Weekly reports
* Improvement coaching

PHASE 10:
PRIVACY, SECURITY AND HARDENING

* Threat review
* Authorization review
* Privacy review
* Data deletion
* Export
* Rate limiting
* Performance
* Accessibility
* Dependency audit
* Full testing
* Self-review

=================================================================
48. DEFINITION OF DONE
======================

A phase is complete only when:

* Code is implemented
* Tests pass
* Lint passes
* Type checks pass
* Migrations work
* Relevant mobile screens function
* Error states exist
* Empty states exist
* Loading states exist
* Accessibility is reviewed
* Performance is reviewed
* Privacy rules are respected
* Documentation is updated
* No raw private content is logged
* Diff is self-reviewed
* Known limitations are documented

=================================================================
49. CODEX WORKING METHOD
========================

For every phase:

1. Inspect the repository before editing.
2. Read `AGENTS.md`.
3. Read relevant documentation.
4. State the objective.
5. Identify assumptions.
6. Implement the smallest coherent vertical slice.
7. Run formatting.
8. Run linting.
9. Run type checks.
10. Run tests.
11. Fix failures.
12. Review the diff.
13. Review privacy and security.
14. Review accessibility.
15. Review mobile performance.
16. Update documentation.
17. Summarise:

    * What was implemented
    * Files changed
    * Commands executed
    * Test results
    * Limitations
    * Recommended next phase

Do not merely output code snippets.

Create and modify actual repository files.

Do not claim that anything works unless it was tested.

Do not claim tests passed unless they were run.

Do not silently skip unavailable tools.

If Flutter is not installed:

* Do not invent generated Flutter files.
* Create setup documentation.
* Prepare the intended structure.
* Continue with components that can be verified.

Do not proceed across several major phases without review.

=================================================================
50. INITIAL TASK
================

Begin with Phase 0 and Phase 1 only.

Perform these tasks now:

1. Inspect the current repository.

2. Create the complete planning documentation.

3. Create the root `AGENTS.md`.

4. Establish the monorepo structure.

5. Create the FastAPI skeleton.

6. Create the Flutter skeleton if Flutter is installed.

7. If Flutter is unavailable, document exact setup requirements and create only safe non-generated scaffolding.

8. Add Docker Compose for PostgreSQL and Redis.

9. Add `.env.example`.

10. Add backend configuration.

11. Add structured logging without private-message content.

12. Add `/health` and `/readiness`.

13. Add initial tests.

14. Add CI for lint, type checks and tests.

15. Create the initial ConvoCoach design-token system.

16. Create premium light and dark theme specifications.

17. Create motion-token specifications.

18. Create a reusable haptic-service interface.

19. Create architecture and user-flow diagrams.

20. Run every available check.

21. Review the implementation.

22. Report:

    * Repository structure
    * Architecture decisions
    * UI/UX decisions
    * Commands run
    * Tests run
    * Failures or unavailable tools
    * Outstanding limitations
    * Recommended Phase 2 tasks

Do not proceed to Phase 2 until Phase 1 has been verified.

=================================================================
51. FINAL STANDARD
==================

The final product must not look or behave like AI-generated prototype software.

It must feel like a carefully designed consumer application.

The experience should combine:

* Apple-level polish
* ChatGPT-level simplicity
* Perplexity-level intelligence
* RIZZ-level onboarding energy
* Linear-level clarity and premium restraint

The result must remain original.

The application should be memorable because it feels:

* Fast
* Calm
* Intelligent
* Smooth
* Trustworthy
* Useful

Not because it contains excessive visual effects.

Build the smallest version that genuinely delivers this experience.

Quality is more important than feature quantity.
