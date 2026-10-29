# 12. Testing Results: Service, Repair and Claims Module

## Database tests (service_module/tests.sql)

| Test | What it checks | Expected | Result |
|---|---|---|---|
| T01 | only the owner can raise a service request | ERROR | PASS |
| T02 | an unsold unit cannot get a request | ERROR | PASS |
| T03 | a recall request must be for a unit in that recall | ERROR | PASS |
| T04 | description needs at least 10 characters | ERROR | PASS |
| T05 | RECALL_FIX requires a recall id | ERROR | PASS |
| T06 | a closed request cannot be reopened | ERROR | PASS |
| T07 | technician must belong to the request's center | ERROR | PASS |
| T08 | cannot use more parts than in stock | ERROR | PASS |
| T09 | stock can never be negative | ERROR | PASS |
| T10 | a claim outside the warranty period is refused | ERROR | PASS |
| T11 | setup: physical damage request on an extended plan | OK | PASS |
| T12 | physical damage cannot be claimed on an extended plan (procedure) | ERROR | PASS |
| T13 | same rule enforced on direct insert (trigger) | ERROR | PASS |
| T14 | only one claim per request | ERROR | PASS |
| T15 | a submitted claim cannot jump to SETTLED | ERROR | PASS |
| T16 | a settled claim is final | ERROR | PASS |
| T17 | setup: replacement claim filed and approved | OK | PASS |
| T18 | replacement with a different model is refused | ERROR | PASS |
| T19 | the failed replacement changed nothing | TRUE | PASS |
| T20 | customer login must link to a customer | ERROR | PASS |
| T21 | plain text passwords are rejected | ERROR | PASS |
| T22 | technician auto-assignment works | OK | PASS |
| T23 | assigned technician is from the same center | TRUE | PASS |
| T24 | every status change was logged | TRUE | PASS |
| T25 | repair cost function equals labour plus parts | TRUE | PASS |

Result: 25 of 25 passed.

## Vector search tests (npm run test:vector)

Each query is worded differently from the stored request it should find. PASS means the expected request is in the top 3.

| Test | Query | Expected | Top match (similarity) | Result |
|---|---|---|---|---|
| V01 | phone switches itself off when battery shows 20 percent | 14, 17 or 5 | #14 (0.623) | PASS |
| V02 | fridge is warm inside and the motor is loud | 12 | #12 (0.530) | PASS |
| V03 | coloured stripes running down the television screen | 6 | #6 (0.493) | PASS |
| V04 | laptop lid is wobbly because the hinge is broken | 13 | #13 (0.701) | PASS |
| V05 | television has picture but the speakers are silent | 8 | #8 (0.484) | PASS |
| V06 | dropped my phone and the glass on the back shattered | 4 | #4 (0.644) | PASS |
| V07 | telly will not switch on, red light flashing | 10 | #10 (0.330) | PASS |
| V08 | photos come out blurry, camera cannot focus | 15 | #15 (0.599) | PASS |

Result: 8 of 8 passed. Scores are from our test run and can differ slightly between machines.

## Application tests (API, through the web backend)

| Case | Steps | Expected | Result |
|---|---|---|---|
| B1 | Log in with a wrong password | "Invalid username or password" | PASS |
| B2 | Call any API without a session | 401 "Please log in" | PASS |
| B3 | Customer raises a request for own phone | request created and embedded | PASS |
| B4 | Customer raises a request for someone else's phone | refused by trigger | PASS |
| B5 | Customer raises RECALL_FIX for a unit not under recall | refused | PASS |
| B6 | Whitefield staff opens a Jayanagar request | "Request not found" | PASS |
| B7 | Similar search for the new battery complaint | past iPhone battery repair ranked near the top | PASS |
| B8 | File a claim on an expired warranty | "No valid warranty covers this request" | PASS |
| B9 | Staff auto-assigns the request | technician from the same center | PASS |
| B10 | Technician adds 100 batteries | "Insufficient spare part stock" | PASS |
| B11 | Technician completes the repair | request COMPLETED, 4 status log rows, fix embedded | PASS |
| B12 | Technician tries to restock parts | 403, admin only | PASS |

Add screenshots of the service queue, a request page with similar issues, the technician page and the claims page to `docs/screenshots`.
