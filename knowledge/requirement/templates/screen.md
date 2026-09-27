---
screen: login
title: Login
release: 1
user_group: general-user     # which user group reaches this screen
requires_auth: false
---

# Screen: Login

## Purpose

One or two lines on what the user accomplishes here.

## Layout

A rough ASCII wireframe. It does not need to be pretty, only unambiguous about
what sits where.

```text
+--------------------------------------------------+
| [logo]                                  [locale] |
+--------------------------------------------------+
|                                                  |
|            +------------------------+            |
|            |  Username              |            |
|            +------------------------+            |
|            +------------------------+            |
|            |  Password              |            |
|            +------------------------+            |
|                                                  |
|            [ Sign in ]                           |
|                                                  |
|            error message area                    |
+--------------------------------------------------+
```

## Menu

Menu entries reachable from this screen, and where each one goes.

| Entry | Destination |
|---|---|
| ... | ... |

Leave empty if the screen has no menu.

## Display

Every value the screen shows, and where it comes from.

| Element | Source |
|---|---|
| ... | static text / backend `<repo>` `<endpoint>` / database `<table>.<column>` |

## Inputs

Every input the user can interact with. `Type` must be explicit.

| Field | Type | Required | Options / source |
|---|---|---|---|
| Username | text | yes | — |
| Password | password | yes | — |
| ... | dropdown | no | options from backend `<repo>` `<endpoint>` |
| ... | image upload | no | — |

Allowed types: `text`, `password`, `number`, `date`, `textarea`, `checkbox`,
`radio`, `dropdown`, `multi-select`, `image upload`, `file upload`.

For `dropdown`, `multi-select`, `radio` and `checkbox`, state whether the options
are a fixed list (give the values) or fetched from a backend or database (give the
repository, endpoint, table and column).

## Actions

| Action | Effect |
|---|---|
| Sign in | Calls backend `<repo>` `<endpoint>`, stores the JWT, goes to `<screen>` |
