## Purpose

Defines how a counter is set back to its starting value so the same counter can count a new batch.

## ADDED Requirements

### Requirement: Reset to zero
The system SHALL set a counter's value to 0 on a reset and return 0, whatever the value was before.

#### Scenario: Reset below the cap
- **WHEN** a counter below the cap is reset
- **THEN** its value is 0

#### Scenario: Reset at the cap
- **WHEN** a counter at the cap is reset
- **THEN** its value is 0 and a later increment makes it 1
