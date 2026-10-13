# counting Specification

## Purpose
Defines how a counter starts, how it advances, where it stops, and how a count is shown to a reader. It describes the behavior of the current code, not intended behavior.

## Requirements

### Requirement: Counter start
The system SHALL start a counter at the given value, or at 0 when none is given, limited to the cap of 100 (a fixed value).

#### Scenario: No start value
- **WHEN** a counter is created without a start value
- **THEN** its value is 0

#### Scenario: Start value above the cap
- **WHEN** a counter is created with a start value above the cap
- **THEN** its value is the cap

### Requirement: Increment
The system SHALL add one to a counter on each increment and return the new value, and SHALL leave a counter at the cap of 100 (a fixed value) unchanged.

#### Scenario: Below the cap
- **WHEN** a counter below the cap is incremented
- **THEN** its value grows by one and the new value is returned

#### Scenario: At the cap
- **WHEN** a counter at the cap is incremented
- **THEN** its value stays at the cap and that value is returned

### Requirement: Count display
The system SHALL render a count as the number followed by "item" when the count is 1 and by "items" otherwise.

#### Scenario: Single item
- **WHEN** the count is 1
- **THEN** the text is "1 item"

#### Scenario: Any other count
- **WHEN** the count is not 1
- **THEN** the text is the number followed by " items"
