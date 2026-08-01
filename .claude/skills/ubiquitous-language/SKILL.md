---
name: ubiquitous-language
description: >-
  Extracts a DDD-style ubiquitous language glossary from the current
  conversation, flagging ambiguities and proposing canonical terms. Saves to
  docs/UBIQUITOUS_LANGUAGE.md. Use when user wants to define domain terms, build
  a glossary, harden terminology, create a ubiquitous language, or mentions
  "domain model" or "DDD".
---

# Ubiquitous Language

## Workflow

1. **Scan the conversation** for domain-relevant nouns, verbs, and concepts
2. **Identify problems**:
   - Same word used for different concepts (ambiguity)
   - Different words used for the same concept (synonyms)
   - Vague or overloaded terms
3. **Propose a canonical glossary** with opinionated term choices
4. **Write to `docs/UBIQUITOUS_LANGUAGE.md`** (create the `docs/` directory if it
   doesn't exist) using the format below
5. **Output a summary** inline in the conversation

## Output Format

Write a `docs/UBIQUITOUS_LANGUAGE.md` file with this structure:

```md
# Ubiquitous Language

## Order lifecycle

| Term        | Definition                                              | Aliases to avoid      |
| ----------- | ------------------------------------------------------- | --------------------- |
| **Order**   | A customer's request to purchase one or more items      | Purchase, transaction |
| **Invoice** | A request for payment sent to a customer after delivery | Bill, payment request |

## People

| Term         | Definition                                  | Aliases to avoid       |
| ------------ | ------------------------------------------- | ---------------------- |
| **Customer** | A person or organization that places orders | Client, buyer, account |
| **User**     | An authentication identity in the system    | Login, account         |

## Relationships

- An **Invoice** belongs to exactly one **Customer**
- An **Order** produces one or more **Invoices**

## Example dialogue

> **Dev:** "When a **Customer** places an **Order**, do we create the **Invoice** immediately?"
> **Domain expert:** "No — an **Invoice** is only generated once a **Fulfillment** is confirmed. A single **Order** can produce multiple **Invoices** if items ship in separate **Shipments**."
> **Dev:** "So if a **Shipment** is cancelled before dispatch, no **Invoice** exists for it?"
> **Domain expert:** "Exactly. The **Invoice** lifecycle is tied to the **Fulfillment**, not the **Order**."

## Flagged ambiguities

- "account" was used to mean both **Customer** and **User** — these are distinct concepts: a **Customer** places orders, while a **User** is an authentication identity that may or may not represent a **Customer**.
```

## Constraints

- **Be opinionated.** When multiple words exist for the same concept, pick the
  best one and list the others as aliases to avoid.
- **Flag conflicts explicitly.** If a term is used ambiguously in the
  conversation, call it out in the "Flagged ambiguities" section with a clear
  recommendation.
- **Only include terms relevant for domain experts.** Skip the names of modules
  or classes unless they have meaning in the domain language.
- **Keep definitions tight.** One sentence max. Define what it IS, not what it
  does.

## Quality

- Once the glossary file is written, run the shared
  [self-review checklist](../quality.md) on it. Surface issues in the chat only
  if found.
