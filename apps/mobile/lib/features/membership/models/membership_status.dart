/// True when a membership [status] grants gym-member privileges (forum, DMs,
/// member-only content, class RSVP).
///
/// This is the single Dart copy of the predicate; it must stay in step with
/// `hasMemberPrivileges` in `@bjj/contract` (TypeScript), which is the source
/// of truth. `active` and `hidden` keep privileges — `hidden` only removes a
/// member from the public roster, it does not revoke access. `inactive` and
/// `pending` (and any unrecognised value) do not have privileges.
bool hasMemberPrivileges(String status) => status == 'active' || status == 'hidden';
