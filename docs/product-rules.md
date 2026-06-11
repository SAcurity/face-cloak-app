# FaceCloak Product Rules

This file records agreed product behavior so UI/API changes stay consistent.

## Image edit mode

- Raw/edit access follows face management permission.
- `can_manage_faces` is the canonical permission for edit/raw UI and raw image access.
- `can_view_raw` should not be used as a separate product permission.
- Delete permission alone must not imply edit/raw access.
- The frontend should tolerate missing `can_manage_faces` by falling back to owner/admin identity.
- Edit mode is an enter/confirm/exit flow: cloak view shows `Edit mode`, raw edit view shows `Done`.

## Face assignment

- An unassigned face must not appear locked.
- An assigned face is assigned if either `assigned_user_id` or assigned username is present.
- Owners/admins can unassign only before the assignee responds.
- Once a face has a response, the assignment cannot be revoked.
- Response state may be inferred from `responded_at` or a `respond` action log when rendering revoke/reminder controls.
- Once a face is self-assigned, that face cannot be reassigned to another user from edit mode.
- A pending assigned face may show a reminder bell.
- A responded face must not show a reminder bell.
- Cloak options in edit mode belong to self-assignment only; assigning another user should only require choosing a user.
- The self-assignment trigger is a `Myself` pill button after the normal assignee input.
- Self-assignment cloak options should be visually separated from the normal assignee input.

## Assignee response

- Assigned users can adjust their cloak choice after responding.
- Decline is only for pending assignments.
- Responded assignments should show the current cloak and remain editable by the assignee.
- Pending assignments must ask "Is this you?" before showing cloak choices.
- The identity confirmation step should show the assignee an original/raw preview of only the assigned face, not the full raw image.
- Assignees can decline from the identity confirmation step.
- Choosing a cloak type should show a loading state while the response is submitted.

## Notifications

- The navbar bell shows pending assignments for the current user.
- Initial assignment creates a visible pending notification through the existing assignment state.
- Header notifications should be calculated from the latest current-account detail payload, not stale login session data.
- Reminder bell re-sends the existing assignment action, but the visible notification source is the pending assignment list.
- Responded assignments are not shown as pending notifications.

## Logs

- Logs are visible only in edit mode for users who can manage the image.
- Logs are shown inside the edit sidebar through an `Assign`/`Logs` tab switch for the selected face.
- Logs aggregate by face record and switch with selected face.
- Switching between `Assign` and `Logs` must not resize the edit sidebar frame.
- Cloak type should show both icon and name on a light gray badge.
- Timestamps should use a unified local display format without timezone suffixes such as `+0800`.

## Settings

- Every account row should show the account identity/role.
- The management tab may show `Admin only`, but the management panel should not repeat the same badge.
- Settings form actions should use compact buttons aligned to their input height.

## Destructive actions

- Delete image/account/user actions require a confirmation dialog before submission.

## Navigation

- Pages opened from header navigation should not show the Back button.
