## MODIFIED Requirements

### Requirement: Increment
The system SHALL add one to a counter on each increment and return the new value with a capped flag, and SHALL leave a counter at the cap of 100 (a fixed value) unchanged, returning the cap with the capped flag set.

#### Scenario: Below the cap
- **WHEN** a counter below the cap is incremented
- **THEN** its value grows by one and the new value is returned with the capped flag clear

#### Scenario: At the cap
- **WHEN** a counter at the cap is incremented
- **THEN** its value stays at the cap and that value is returned with the capped flag set
