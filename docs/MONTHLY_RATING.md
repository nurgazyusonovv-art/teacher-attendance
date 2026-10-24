# Monthly attendance rating

Approved rule (2026-10-24): each scheduled workday can earn 10 points:
5 for a recorded ON_TIME arrival with zero late minutes, and 5 for a valid
checkout at or after the scheduled end. Late arrival and early departure each
lose their respective 5 points. Overtime earns no extra points. The existing
server-side grace period is retained by using the recorded arrival status.

Approved leave / EXCUSED and days off are excluded from the possible total.
Missing schedules are explicitly unscored. Dates before school attendance start
or teacher creation, and future dates, are excluded. Today's unfinished shift
is pending, not absent; missing checkout becomes final only after shift end.
The current month is provisional. Every month has an independent total.

GET `/api/v1/attendance/my-monthly-score` is authenticated teacher-only.
Optional `year` and `month` must be supplied together; future months are rejected.
Server school time determines the default month and cutoff. Three bounded,
school-and-teacher-scoped reads load attendance, schedules and approved leave.
The report is calculated, not incremented or persisted; retries never add points.
Demo and production records remain isolated by teacher and school.

Important: historical schedules are not versioned in this application. This
report explicitly uses **current schedules**. Changing schedules or audited
attendance corrections can change past totals. This is not a frozen payroll
ledger. Immutable historical scoring would require dated schedule snapshots,
a separate schema migration and an agreed policy for existing historical data.

The mobile screen uses repository → Cubit → presentation and never calculates
points locally. Failed loading displays unavailable/retry, not zero. A backend
deployment is required before the monthly rating is available in mobile releases.
No database migration or attendance reset is required for this feature.
