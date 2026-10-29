# 1. Objectives and Functional Requirements

## Problem

Retailers and service networks lose track of individual product units after they are sold. They often cannot answer basic questions: who owns this serial number, is it still under warranty, is it part of a recall batch, and what has already been repaired or replaced. The result is wrong warranty decisions, recalled units being resold, and repeated diagnosis of problems that were already solved before.

## Objectives

1. Track every serial-numbered unit from manufacture to sale, service and replacement.
2. Decide warranty eligibility automatically, using the plan type, the request date and claim limits.
3. Target recalls by model and manufacturing batch and notify current owners.
4. Run the service workflow (request, technician assignment, repair, parts, claim, replacement) with rules enforced inside the database.
5. Help technicians by finding similar past problems by meaning, using vector search.
6. Provide a role-based web application for admins, service staff, technicians and customers.

## Functional requirements

### Sales, warranty and recall (sales module)

| ID | Requirement |
|---|---|
| FR-S1 | Staff can add customers; email and phone formats are validated by the database. |
| FR-S2 | Staff can register a sale. The invoice, the sold unit and its warranty are created in one transaction. |
| FR-S3 | A unit that is already sold, made after the purchase date, or under an active recall cannot be sold. |
| FR-S4 | The warranty end date is calculated from the plan, and two active warranties of the same type cannot overlap. |
| FR-S5 | Anyone logged in can look up a serial number to see coverage, recall status and service history. Customers see only their own units. |
| FR-S6 | Admins can generate recall notifications for all current owners of affected units, without duplicates. |
| FR-S7 | Customers can see their products, warranties and recall notices. |
| FR-S8 | Admin and staff see a dashboard with revenue by brand, monthly sales and warranties about to expire. |

### Service, repair and claims (service module)

| ID | Requirement |
|---|---|
| FR-V1 | Users log in with a username and password; the backend issues a signed session token. |
| FR-V2 | Four roles (ADMIN, SERVICE_STAFF, TECHNICIAN, CUSTOMER) see different pages and data. |
| FR-V3 | Customers can raise a service request only for units they own. |
| FR-V4 | Staff can auto-assign the best technician at their center. |
| FR-V5 | Technicians can start a repair, add parts (stock is checked and reduced) and complete it. |
| FR-V6 | Staff can file a warranty claim; the database picks the right warranty or refuses the claim. |
| FR-V7 | Approved repair claims settle automatically with the final repair cost when the repair completes. |
| FR-V8 | Approved replacement claims swap the unit, move the remaining warranty and close the request in one transaction. |
| FR-V9 | Every request status change is recorded in an audit log. |
| FR-V10 | Staff and technicians can find the five most similar past requests to a new complaint. |

## Non-functional requirements

1. Database credentials are read from environment variables, never from source code.
2. Passwords are stored only as bcrypt hashes.
3. Validation happens in the database (CHECK, UNIQUE, FOREIGN KEY, triggers), so no client can bypass it.
4. All software used is free; the embedding model runs locally without an API key.
