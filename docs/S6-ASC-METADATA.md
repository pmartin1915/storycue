# S6 — App Store Connect metadata, privacy label, age rating (draft)

_Drafted 2026-10-04 against main `e0122f9`. Opus drafts; Perry edits and enters it in ASC.
Every factual claim was checked against the code (see "Verified against"). Character counts
are measured, not estimated._

## Before entering anything

1. **Merge storycue PR #11** (privacy manifest now declares the file-timestamp and disk-space
   APIs the code calls, and drops the UserDefaults entry no code uses).
2. **Publish the two pages** on martinapps.dev: branch `storycue-pages` in `martinapps-site`
   (`cd10b5d`), files `storycue/privacy-policy.html` and `storycue/support.html`. Merging that
   branch to `main` publishes them. Read the policy first: it is the legal text.
3. **Pricing is still undecided** (free + one-time unlock was deferred). Nothing below mentions
   price. The "Price" and in-app purchase fields wait on that decision.

## URLs

| Field | Value |
|---|---|
| Privacy Policy URL | `https://martinapps.dev/storycue/privacy-policy.html` |
| Support URL | `https://martinapps.dev/storycue/support.html` |
| Marketing URL | leave empty |

## Text fields

**Name** (30 max): `StoryCue` (8). The name is "for now" per STATE; once the ASC record
exists a rename is possible but the bundle ID is not.

**Subtitle** (30 max): `Record your family's stories` (28)

**Promotional text** (170 max, editable without review):
> Five question decks, one question at a time. Sit down with a grandparent, a parent or your
> partner and record the answers before the stories are lost. (150)

**Description** (4,000 max):
> StoryCue turns your iPhone into a gentle interviewer. Pick a question deck, prop up your
> phone, and record the people you love answering one question at a time.
>
> FIVE QUESTION DECKS
> • Grandparents: childhood, first jobs, and the years that shaped them
> • Parents: the day you were born, and what parenting taught them
> • Kids Ask the Grownups: toys, school, old fears
> • Couples: how you met, and the life you've built since
> • Holiday Table: pass the phone around the table and take turns
>
> MADE FOR REAL CONVERSATIONS
> • One question on screen at a time, in large type
> • Pause, skip, or move on whenever the answer is done
> • A consent card to read aloud before you start, so everyone on camera agrees
> • Interrupted by a call or a crash? StoryCue finds the recording next time you open it
>
> YOURS, AND ONLY YOURS
> • Recordings stay on your iPhone. No account, no cloud, no ads, no tracking
> • StoryCue makes no network requests at all
> • Export a whole session as one video or one video per answer, to Photos or Files
> • See how much space your recordings use, with a warning before your iPhone fills up

(Count when entered; it is far under the limit.)

**Keywords** (100 max, comma-separated, no spaces):
`interview,family,history,grandparents,oral,storytelling,memories,questions,video,legacy,parents`
(95). Don't repeat the name or a category word; avoid other companies' trademarks.

**Copyright**: `2026 Martin Apps LLC`

## Categories

- Primary: **Lifestyle**
- Secondary: **Photo & Video**

## App Privacy (nutrition label)

Answer **"No, we do not collect data from this app."** The label becomes **Data Not Collected**.

Apple counts data as "collected" only when it is transmitted off the device. StoryCue has no
network code, no third-party SDKs, and stores recordings only in its own container; exports go
where the user sends them through Photos (add-only) or the system share sheet, which is the
user's action, not collection by the app. This matches `PrivacyInfo.xcprivacy`
(`NSPrivacyCollectedDataTypes` empty, `NSPrivacyTracking` false).

## Age rating questionnaire

Every content question: **None**. Feature questions:

| Question | Answer | Why |
|---|---|---|
| Unrestricted web access | No | No web view, no browser |
| User-generated content shared with others | No | Recordings never leave the app except by the user's own export |
| Messaging / chat | No | — |
| Advertising | No | — |
| Parental controls / age assurance | No | — |
| Gambling, contests | No | — |

Expected result: **4+**. The "Kids Ask the Grownups" deck is for kids to use with an adult; it
does not make StoryCue a Kids Category app. Do **not** opt into the Kids Category (it would add
requirements for no benefit).

## Export compliance

`ITSAppUsesNonExemptEncryption = false` is already in the Info.plist (`project.yml`), so ASC
does not ask per build.

## Still open in S6

- Screenshots: re-shoot the 6.9" set from the S2d build (CI `asc-screenshots-6.9` artifact)
  after Perry's device checks, then upload.
- Featuring nomination (~10-09): drafted separately, filed by Perry in ASC.
- Review notes for App Review: one line, "No account or sign-in. Camera and microphone are
  used only to record the interview; recordings stay on device."

## Verified against

- No network: no `URLSession` or web URL in `StoryCue/`; the only `URL(string:)` is
  `UIApplication.openSettingsURLString` (`RecorderView.swift`).
- No third-party SDKs: `project.yml` targets depend only on `StoryCue`.
- Storage: `SegmentFiles.swift` (Application Support, deliberately backup-eligible).
- Photos add-only: `NSPhotoLibraryAddUsageDescription` is the only Photos key.
- Export modes and labels: `UICopy` (`exportEachAnswer`, `exportOneVideo`, `exportToFiles`,
  `exportToPhotos`).
- Deck titles and teasers: `Decks.swift`, `UICopy.deckTeaser`.
- Recovery: `Library.load` steps 4-5 and the launch sweep's adoption.
