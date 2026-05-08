# GrowTogether

GrowTogether is a couple growth app where two bound partners create plans, check in daily, and send gentle reminders to support shared progress.

## Language

**User**:
An authenticated person using the app.
_Avoid_: Account, member

**User Profile**:
The app-facing identity for a **User**, including nickname, avatar, invite code, and partner binding state.
_Avoid_: Auth user, account profile

**Invite Code**:
A permanent unique code on a **User Profile** that another **User** can enter to request a **Couple Relationship**.
_Avoid_: Invite token, referral code

**Couple Invitation**:
A pending request from one **User** to another **User** to create a **Couple Relationship**.
_Avoid_: Direct binding, friend request

**Partner**:
The other **User** in the same active **Couple Relationship**.
_Avoid_: Friend, teammate

**Couple Relationship**:
The binding between exactly two **Users** that creates their shared growth space.
_Avoid_: Couple account, group

**Relationship Ending**:
The act of closing an active **Couple Relationship** without deleting its historical data.
_Avoid_: Delete relationship, clear partner

**Plan**:
A growth commitment in a **Couple Relationship** with a daily task and a date range.
_Avoid_: Todo, task

**Personal Plan**:
A **Plan** created by one **User** where only the creator can check in.
_Avoid_: My plan, partner plan

**Shared Plan**:
A **Plan** for both **Partners** where each partner can check in independently.
_Avoid_: Together task, group plan

**Plan Creator**:
The **User** who created a **Plan** and owns its editable details.
_Avoid_: Owner

**Ended Plan**:
A **Plan** that has been closed by its **Plan Creator** but remains readable in history.
_Avoid_: Deleted plan

**Reminder**:
An in-app message one **User** sends to their **Partner**, usually to encourage or prompt progress on a **Plan**.
_Avoid_: Push notification, scheduled alarm

**Supervision**:
A **Plan** setting that allows the **Partner** to send prompt-style **Reminders** for that plan.
_Avoid_: Permission, notification setting

**Plan Reminder Time**:
The configured time-of-day associated with a **Plan** for reminder display or future local notification behavior.
_Avoid_: Reminder message

**Growth Record**:
A derived view of progress history calculated from **Plans** and **Checkins**.
_Avoid_: Stored record, analytics event

**Checkin**:
A **User**'s daily record for a **Plan**, including completion status, mood, and note.
_Avoid_: Punch, task completion

**Checkin Day**:
The Asia/Shanghai calendar day a **Checkin** belongs to.
_Avoid_: Timestamp day

**Shared Completion Day**:
A calendar day where both **Partners** completed the same **Shared Plan**.
_Avoid_: Any-user completion

## Relationships

- A **User** has exactly one **User Profile**
- A **User Profile** has exactly one permanent **Invite Code**
- Entering an **Invite Code** creates a **Couple Invitation**, not a **Couple Relationship**
- A **Couple Invitation** must be accepted by its receiver before a **Couple Relationship** is created
- A **User** can send or receive **Couple Invitations** only while they do not have an active **Partner**
- A **User** can have at most one active **Partner**
- A **Couple Relationship** has exactly two **Users**
- A **Couple Relationship** can be active or ended
- A **Relationship Ending** makes the historical data for that **Couple Relationship** unavailable in the app to both former partners
- Either **User** in an active **Couple Relationship** can perform a **Relationship Ending** after confirmation
- A **Plan** belongs to exactly one **Couple Relationship**
- A **Plan** has exactly one **Plan Creator**
- A **Personal Plan** can be checked in only by its **Plan Creator**
- A **Shared Plan** is checkable by both **Partners**
- A **Plan Creator** can edit a plan's content and reminder settings while the plan is active
- A **Plan**'s type, creator, and couple relationship do not change after creation
- A **Plan**'s dates can be changed freely before any **Checkins** exist; after checkins exist, only the end date can be extended
- An **Ended Plan** cannot be edited, checked in, or reminded
- A **Reminder** is sent from one **User** to their **Partner**
- A **Reminder** can be read by its sender and receiver
- A **Reminder** linked to the same plan can be sent at most three times per **Checkin Day** by the same sender
- Prompt-style **Reminders** require **Supervision** to be enabled and the receiver's checkin to be incomplete
- A **Plan Reminder Time** does not automatically create a **Reminder** in MVP
- A **Growth Record** is not a separate source of truth in MVP
- A **Checkin** belongs to exactly one **Plan** and exactly one **User**
- A **User** has at most one **Checkin** per **Plan** per **Checkin Day**
- A **Checkin** can be changed only during its own **Checkin Day**
- A **Shared Completion Day** requires completed **Checkins** from both **Partners** on the same date

## Example Dialogue

> **Dev:** "Should the invite code belong to the Supabase auth user?"
> **Domain expert:** "No, auth gives us the **User**. The invite code belongs to the **User Profile** because it is part of the app identity."
>
> **Dev:** "If two users stop being partners, do we delete their couple row?"
> **Domain expert:** "No. The **Couple Relationship** ends, but its historical plans and checkins remain attached to it."
>
> **Dev:** "After a relationship ends, can the former partners still see old plans and checkins?"
> **Domain expert:** "No. The historical data remains stored, but the app no longer exposes it to either former partner."
>
> **Dev:** "Does ending a relationship require both partners to approve?"
> **Domain expert:** "No. Either partner can end the **Couple Relationship** after confirming the action."
>
> **Dev:** "Does an invite code expire after binding?"
> **Domain expert:** "No. The **Invite Code** stays on the **User Profile**; binding rules prevent duplicate active relationships."
>
> **Dev:** "Does entering someone's invite code immediately bind them?"
> **Domain expert:** "No. Entering an **Invite Code** creates a **Couple Invitation**. The receiver must accept it before a **Couple Relationship** exists."
>
> **Dev:** "Should the backend store whether a plan is 'mine' or 'TA's'?"
> **Domain expert:** "No. A **Personal Plan** stores its creator; 'mine' and 'TA's' are display perspectives."
>
> **Dev:** "Can either partner edit a shared plan?"
> **Domain expert:** "No. A **Shared Plan** involves both partners, but only its **Plan Creator** edits the plan details in MVP."
>
> **Dev:** "When someone ends a plan, should we delete it?"
> **Domain expert:** "No. It becomes an **Ended Plan** so historical checkins and growth records remain readable."
>
> **Dev:** "Is a reminder the same thing as a phone push notification?"
> **Domain expert:** "No. A **Reminder** is an in-app message in MVP; remote push notification is a future delivery channel."
>
> **Dev:** "Can I keep nudging my partner after they finish today's plan?"
> **Domain expert:** "No prompt-style **Reminders** after completion; encouragement-style **Reminders** are still allowed within the daily limit."
>
> **Dev:** "Do we save a growth record whenever someone checks in?"
> **Domain expert:** "No. A **Growth Record** is calculated from **Plans** and **Checkins** when displayed."
>
> **Dev:** "Does a shared plan count as completed if only one partner checks in?"
> **Domain expert:** "No. A **Shared Completion Day** only exists when both **Partners** complete that **Shared Plan** on the same date."
>
> **Dev:** "Can someone fix a checkin mistake?"
> **Domain expert:** "Yes, but only during the same **Checkin Day**. Once that day has passed, the **Checkin** is locked."

## Flagged Ambiguities

- "account" is avoided because authentication identity and product profile are distinct concepts: use **User** for the signed-in person and **User Profile** for app-visible profile data.
- "my plan" and "partner plan" are UI perspectives, not stored plan types; use **Personal Plan** or **Shared Plan** in the domain model.
- "one checkin per day" means one mutable **Checkin** during the same **Checkin Day**, not multiple historical submissions.
- "reminder" means an in-app **Reminder** message unless explicitly discussing remote push notifications.
- The Dart `PlanOwner` enum (`me`/`partner`/`together`) is a display-time derivation computed at the repository layer from `plan_type + creator_id` against the current user, not a stored field.
- The Dart `Reminder` model maps directly to the `reminders` table; `title`/`icon`/`color` are display derivations from `ReminderType`, not stored fields. `sentByMe` is derived from `fromUserId` against current user.
- The `Store` abstract class (with `Provider<Store>` DI) is the single data entry point for all UI pages. Pages use `context.watch<Store>()` / `context.read<Store>()` and never touch repositories or data sources directly.
- `createPlan` takes `bool isShared` (not `PlanOwner`), matching the database `plan_type` column.
- Supabase Realtime subscriptions (plans + checkins) are included in MVP so partner updates propagate to the other user automatically.
- Repository implementation order: PlanRepository → CheckinRepository → ReminderRepository.
- MVP uses anonymous auth only; no login/registration UI.
