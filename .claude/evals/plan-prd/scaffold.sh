#!/usr/bin/env bash
# scaffold.sh – seeds a short bookmarks PRD for the plan skill to break down.
set -euo pipefail

mkdir -p docs/prds
cat > docs/prds/prd-bookmarks.md <<'MD'
# PRD: Bookmarks

## Problem Statement

Readers of our recipe site lose recipes they liked, because nothing on the site remembers them.

## Solution

Signed-in readers bookmark a recipe with one click and see their bookmarks on a page of their own.

## User Stories

1. As a reader, I want to bookmark a recipe, so that I find it again later
2. As a reader, I want to remove a bookmark, so that my list stays short
3. As a reader, I want a bookmarks page, so that I see every saved recipe in one place

## Implementation Decisions

- A bookmarks table keyed by user and recipe, unique per pair
- REST endpoints to add, remove and list bookmarks for the signed-in user
- A bookmark toggle on the recipe page and a new bookmarks page

## Testing Decisions

- API tests against a real database; UI tests fake the API client

## Out of Scope

- Sharing bookmarks, folders, and bookmarks for anonymous readers
MD
