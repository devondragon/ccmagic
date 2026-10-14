## MODIFIED Requirements

### Requirement: Count display
The system SHALL render a count of 0 as "no items", and otherwise the number followed by "item" when the count is 1 and by "items" otherwise.

#### Scenario: Single item
- **WHEN** the count is 1
- **THEN** the text is "1 item"

#### Scenario: Zero
- **WHEN** the count is 0
- **THEN** the text is "no items"

#### Scenario: Any other count
- **WHEN** the count is neither 0 nor 1
- **THEN** the text is the number followed by " items"
