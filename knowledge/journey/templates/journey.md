---
journey: add-income-record
title: Add an income record
user_group: general-user         # which user group walks this
platform: web                    # web | mobile
login: username-password         # the login method this journey uses, or: none
interactive: false               # true when a human must click something (forces desktop mode)
mock_data: mock-data/add-income-record.py
---

# Journey: Add an income record

## What the user is trying to do

One or two sentences, in the user's terms. Not implementation.

## Starting state

What must already exist in the datastore before step 1. This is what the mock data
creates, and it is why the journey can run twice and behave the same both times.

- a registered user `<username>` with a known password
- no accounts belonging to that user

## Steps

Numbered, in the order the user walks them. Include the steps that exist only to make a
later step possible, and say why.

| # | Step | Why this step is here |
|---|---|---|
| 1 | Log in as `<username>` | |
| 2 | Create an account | **Inserted.** Step 4 has nowhere to put a record until an account exists. |
| 3 | Open the account page | |
| 4 | Add an income record | the actual goal |

## What tells us it worked

What is on screen, or in the datastore, once the last step is done. One observable thing
per line.

- the new record appears in the account's list
- the account balance reflects it

## Script

| Platform | File |
|---|---|
| web | `web/add-income-record.spec.ts` |
| mobile | `mobile/add-income-record.yaml` |
