# Smart Sabha development plan

The core civic modules have local implementations. Prioritise focused feature
deliveries alongside staging verification; local tests alone do not establish
production readiness. See ROADMAP.md and TODO.md for the full inventory.

## Delivered locally: consultation question editor and aggregate results

- Allow officers to combine written answers and single-choice questions.
- Add and remove questions, retaining at least one and allowing at most 20.
- Validate question text and 2–20 distinct choices with backend-compatible limits.
- Keep question identifiers stable when removing questions.
- Preserve the exact publication request after a network failure for safe retries.
- Verify publication, invalid choices, retries, narrow layouts and enlarged text.

The question editor uses the existing participation migration. Officer aggregate
results require `202610090001_consultation_results.sql` after notification refresh.
Results show choice counts/percentages and written-answer totals without exposing
respondent identities or written content. Refresh, retry and session isolation are supported.
Choice consultation publication and results still need verification against live staging.

## Next deliveries, in priority order

1. **Connected staging verification.** Provision authorities and test real Auth
   callbacks, session restoration, report submission through resident notification,
   project following/uploads, targeted announcements and consultation answers.
   Verify access isolation between authorities and roles. Record reproducible
   results and failures before release. Requires a configured staging project.
2. **Participation completeness.** Verify the implemented aggregate consultation
   results in staging, then deliver proposal attachments and proposal-to-project
   conversion. Each feature should include database permission tests and Flutter
   workflow tests. Add server pagination for participation lists and comments.
3. **Administration and reference data.** Replace demo ward/division options with
   authority-managed records, implement authority transfers and use unique officer
   IDs for assignment. Verify department lifecycle across administrator sessions.
4. **Usability and resilience.** Complete Sinhala/Tamil/English translations,
   audit keyboard and screen-reader access, verify devices and enlarged text,
   add recoverable drafts and notification refresh without losing edits.
5. **Production readiness.** Configure separate environments, release identity
   and signing, monitoring, backups and restore checks, upload retention,
   privacy disclosures, rollback and operational ownership. Validate iOS on macOS.

## Delivery workflow

Create a feature branch from the latest main for each focused delivery. Implement
and document the behavior, run formatting, analysis and relevant workflow checks,
then push and open a pull request describing validation and remaining limitations.
Apply database migrations only to an explicitly selected environment. Keep
credentials and local editor configuration out of commits.
