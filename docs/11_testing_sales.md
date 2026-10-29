# 11. Testing Results: Sales, Warranty and Recall Module

## Database tests (sales_module/tests.sql)

Run with `mysql -u root -p -t < build_all.sql` from the `database` folder. Each test either expects the database to refuse an operation (ERROR), expects success (OK), or checks a condition (TRUE).

| Test | What it checks | Expected | Result |
|---|---|---|---|
| T01 | customer email format is validated | ERROR | PASS |
| T02 | phone must be a 10 digit Indian mobile | ERROR | PASS |
| T03 | duplicate customer email is rejected | ERROR | PASS |
| T04 | sale price must be positive | ERROR | PASS |
| T05 | plan duration must be 1 to 60 months | ERROR | PASS |
| T06 | recall scope date range must be valid | ERROR | PASS |
| T07 | customer with purchases cannot be deleted | ERROR | PASS |
| T08 | model must reference an existing product | ERROR | PASS |
| T09 | a sold unit cannot be sold again | ERROR | PASS |
| T10 | purchase date cannot be before manufacture date | ERROR | PASS |
| T11 | a unit under active recall cannot be sold | ERROR | PASS |
| T12 | warranty cannot be issued for an unsold unit | ERROR | PASS |
| T13 | overlapping warranty of the same type is blocked | ERROR | PASS |
| T14 | sale with an unknown plan fails | ERROR | PASS |
| T15 | the failed sale was rolled back completely | TRUE | PASS |
| T16 | a valid sale with warranty succeeds | OK | PASS |
| T17 | trigger set owner, invoice total and 24 month end date | TRUE | PASS |
| T18 | recall notification job can be re-run | OK | PASS |
| T19 | re-run created no duplicate notifications | TRUE | PASS |
| T20 | functions report coverage and recall correctly | TRUE | PASS |

Result: 20 of 20 passed.

## Application tests (API, through the web backend)

| Case | Steps | Expected | Result |
|---|---|---|---|
| A1 | Open /dashboard without logging in | redirected to /login | PASS |
| A2 | Customer calls /api/customers | 403 "You do not have access to this" | PASS |
| A3 | Staff registers sale of S24-24A0005 (in recall batch) | refused: unit under active recall | PASS |
| A4 | Staff registers sale of S25-25A0007 | purchase created, unit SOLD, warranty active | PASS |
| A5 | Admin adds customer with email "bad" | refused: chk_customer_email | PASS |
| A6 | Customer looks up own serial IP15-23K0008 | unit, warranties and history shown | PASS |
| A7 | Customer looks up another customer's serial | "No unit found" | PASS |
| A8 | Staff tries to generate recall notifications | 403, admin only | PASS |
| A9 | Admin generates notifications for an already notified recall | 0 created, no duplicates | PASS |

Add screenshots of the dashboard, sale form (with the recall error) and warranty lookup to `docs/screenshots`.
