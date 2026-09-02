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

## Output Format

Write `docs/UBIQUITOUS_LANGUAGE.md` (create `docs/` if missing) in this shape:

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

- **Be opinionated.** Pick the best word per concept and list synonyms as aliases to avoid.
- **Flag conflicts explicitly.** Flag ambiguous conversation terms in "Flagged ambiguities" with a clear recommendation.
- **Only include terms relevant for domain experts.** Skip module or class names unless they carry domain meaning.
- **Keep definitions tight.** One sentence max. Define what it IS, not what it does.

## Quality

- Run the shared [self-review checklist](../quality.md) on the glossary file, and format the chat summary per [output style](../output-style.md).
