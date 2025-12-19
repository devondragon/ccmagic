---
allowed-tools: Write(*), Read(*), LS(*), Glob(*), Bash(mkdir:*)
description: Create a research or investigation task
argument-hint: spike-description (e.g., "evaluate caching strategies")
model: sonnet
---

# Create Spike Task

## Creating a New Spike...

I'll help you create a research or investigation task (spike).

### 1. Checking Context Structure:

```bash
# Ensure context directory exists
if [ ! -d "context" ]; then
    echo "❌ Context directory not found. Run /init first."
    exit 1
fi

# Ensure spike directories exist
mkdir -p context/spikes/todo
mkdir -p context/spikes/current
mkdir -p context/spikes/completed
```

### 2. Determining Spike ID:

```bash
# Find next available spike ID
EXISTING_SPIKES=$(find context/spikes -name "spike-*.md" -type f 2>/dev/null | \
                  grep -oE "spike-[0-9]{3}" | \
                  grep -oE "[0-9]{3}" | \
                  sort -n | tail -1)

if [ -z "$EXISTING_SPIKES" ]; then
    NEXT_ID="001"
else
    NEXT_ID=$(printf "%03d" $((10#$EXISTING_SPIKES + 1)))
fi

echo "📌 Next spike ID: spike-$NEXT_ID"
```

### 3. Spike Type Selection:

```markdown
## Select Spike Type

What type of spike is this?

### 🔬 Research
- Evaluate technologies, libraries, frameworks
- Compare approaches or solutions
- Assess feasibility of features

### 🔍 Investigation  
- Debug complex issues
- Understand system behavior
- Root cause analysis

### 🛠️ POC (Proof of Concept)
- Build working prototype
- Validate technical approach
- Test integration possibilities

### 🔧 Maintenance
- Update dependencies
- Refactor code areas
- Clean up tech debt

### 🚨 Hotfix
- Emergency production fixes
- Critical bug resolution
- Security patches

Select type [1-5]: {{spike_type}}
```

### 4. Gathering Spike Details:

```markdown
## Spike Information

### Description
Brief, clear description (will be used in filename):
> {{spike_description}}

### Context
Why is this spike needed? What problem does it solve?
> {{spike_context}}

### Priority
How urgent is this spike?
- [ ] 🔴 Critical - Block release/production issue
- [ ] 🟠 High - Blocks current feature work
- [ ] 🟡 Medium - Needed soon but not blocking
- [ ] 🟢 Low - Nice to have, when time permits

### Related To
Is this spike related to any epic or feature?
- Epic: {{epic_id}} (optional)
- Feature: {{feature_id}} (optional)
- Task: {{task_id}} (optional)
- Issue: {{issue_reference}} (optional)
```

### 5. Defining Questions & Success Criteria:

```markdown
## Questions to Answer

What specific questions need answers? (Add at least 3)

1. {{question_1}}
2. {{question_2}}
3. {{question_3}}
4. {{question_4}} (optional)
5. {{question_5}} (optional)

## Success Criteria

What defines successful completion of this spike?

### Must Have:
- [ ] {{must_have_1}}
- [ ] {{must_have_2}}
- [ ] {{must_have_3}}

### Nice to Have:
- [ ] {{nice_to_have_1}}
- [ ] {{nice_to_have_2}}

## Deliverables

What will be produced from this spike?

- [ ] Written recommendation/decision
- [ ] Code prototype/example
- [ ] Architecture diagram
- [ ] Performance benchmarks
- [ ] Cost analysis
- [ ] Migration plan
- [ ] Documentation updates
- [ ] Follow-up task list
```

### 6. Risk & Constraints:

```markdown
## Risks & Constraints

### Technical Risks
{{technical_risks}}


### Dependencies
- Needs input from: {{person_or_team}}
- Requires access to: {{systems_or_resources}}
- Blocked by: {{blockers_if_any}}

### Out of Scope
What is explicitly NOT part of this spike:
- {{out_of_scope_1}}
- {{out_of_scope_2}}
```

### 7. Creating Spike File:

Creating `context/spikes/todo/spike-{{id}}-{{description}}.md`:

```markdown
# Spike {{id}}: {{title}}

## Metadata
- **Type**: {{spike_type}}
- **Priority**: {{priority}}
- **Created**: {{current_date}}
- **Owner**: {{assignee}}
- **Status**: TODO

## Context
{{detailed_context}}

## Related Items
- Epic: {{epic_reference}}
- Feature: {{feature_reference}}
- Task: {{task_reference}}
- Issue: {{issue_reference}}

## Questions to Answer

### Primary Questions
- [ ] {{primary_question_1}}
- [ ] {{primary_question_2}}
- [ ] {{primary_question_3}}

### Secondary Questions
- [ ] {{secondary_question_1}}
- [ ] {{secondary_question_2}}

## Success Criteria

### Definition of Done
- [ ] All primary questions have answers (even if partial)
- [ ] Findings are documented below
- [ ] Recommendation is clear and actionable
- [ ] Next steps are defined

### Deliverables
- [ ] {{deliverable_1}}
- [ ] {{deliverable_2}}
- [ ] {{deliverable_3}}

## Investigation Plan

### Approach
1. {{step_1}}
2. {{step_2}}
3. {{step_3}}
4. {{step_4}}

### Resources to Consult
- {{resource_1}}
- {{resource_2}}
- {{resource_3}}

### Tools/Methods
- {{tool_1}}
- {{tool_2}}

---

## 📝 FINDINGS (To be filled during spike)

### Research Notes
<!-- Add findings as you investigate -->

### Data/Metrics Collected
<!-- Add any measurements, benchmarks, or data -->

### Code Examples/Prototypes
<!-- Add any code snippets or prototype references -->

### Comparison Matrix (if applicable)
| Criteria | Option A | Option B | Option C |
|----------|----------|----------|----------|
| {{criterion_1}} | | | |
| {{criterion_2}} | | | |
| {{criterion_3}} | | | |

---

## 🎯 RECOMMENDATION

### Summary
<!-- One paragraph summary of recommendation -->

### Recommended Approach
<!-- Detailed recommendation -->

### Pros
- {{pro_1}}
- {{pro_2}}
- {{pro_3}}

### Cons
- {{con_1}}
- {{con_2}}

### Alternatives Considered
1. {{alternative_1}} - Rejected because: {{reason}}
2. {{alternative_2}} - Rejected because: {{reason}}

---

## 📋 NEXT STEPS

### Immediate Actions
- [ ] {{immediate_action_1}}
- [ ] {{immediate_action_2}}

### Follow-up Tasks to Create
- {{task_description_1}} (Est: {{estimate}})
- {{task_description_2}} (Est: {{estimate}})

### Knowledge Base Updates
- [ ] Update {{knowledge_file}} with findings
- [ ] Add decision to architecture.md
- [ ] Document in relevant feature overview

### Technical Debt Items
- {{tech_debt_1}}
- {{tech_debt_2}}

---

### 8. Updating Working State:

Updating `context/working-state.md`:

```markdown
## Upcoming Spikes

### High Priority
- spike-{{id}}: {{description}}
  - Type: {{type}}
  - Related: {{related_items}}
  - Due: {{due_date_if_any}}

### Backlog
{{other_spikes}}
```

### 9. Creating Quick Templates:

#### For Common Spike Types:

**Technology Evaluation Template:**
```bash
/create-spike --template=tech-eval
# Pre-fills questions about performance, cost, learning curve, support
```

**Bug Investigation Template:**
```bash
/create-spike --template=bug
# Pre-fills questions about reproduction, root cause, impact, fix
```

**Performance Analysis Template:**
```bash
/create-spike --template=perf
# Pre-fills questions about bottlenecks, metrics, optimization options
```

### 10. Validation & Confirmation:

```
📊 Spike Creation Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Spike Created: spike-{{id}}-{{description}}

📝 Details:
   Type: {{type}}
   Priority: {{priority}}
   Questions: {{question_count}} to answer
   
📁 Location:
   context/spikes/todo/spike-{{id}}-{{description}}.md
    
🎯 Success Metrics:
   • Answer {{primary_question_count}} primary questions
   • Deliver {{deliverable_count}} deliverables
   
📅 Scheduling:
   Suggested Start: {{suggested_start}}
   Latest Start: {{latest_start}}
   Expected Completion: {{expected_completion}}

💡 Tips for This Spike:
   {{contextual_tips_based_on_type}}

🚀 Next Actions:
   1. Review spike details in file
   2. Schedule spike in sprint/week
   3. Run `/start-spike spike-{{id}}` when ready
   
Created successfully! The spike is now in your backlog.
```

### 11. Spike Management Commands:

```markdown
## Related Commands

After creating the spike, use:

- `/start-spike spike-{{id}}` - Begin working on spike
```

## Smart Features:

### Auto-Suggestions:
- Suggests related spikes based on description
- Proposes questions based on common patterns
- Links to relevant knowledge base articles

### Integration Points:
- Links to existing epics/features/tasks
- Cross-references with backlog items
- Connects to issue tracking system
- Updates project risk register

### Quality Checks:
- Validates questions are specific and measurable
- Ensures success criteria are clear
- Checks for duplicate spikes

## Best Practices Enforcement:

1. **Clear Questions**: Each question should be answerable
2. **Defined Success**: Clear criteria for completion
3. **Documentation**: Findings must be recorded
4. **Follow-through**: Creates tasks from recommendations

## Error Handling:

- **Duplicate spike**: Show similar spikes and ask to proceed
- **No context directory**: Prompt to run `/init`
- **Missing required fields**: Interactive prompts for completion

The spike creation system ensures research and investigation work is properly planned, and documented!