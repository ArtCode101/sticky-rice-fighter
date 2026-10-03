# Mobile Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/mobile/`

and governs the content of the workspace's `mobile` repositories.

## Purpose

Mobile is the third kind of application the framework builds, after backend and
frontend. One codebase produces both iOS and Android.

## The stack

Every version comes from the `mobile` section of `knowledge/tech-stack.yaml`, unchanged.

| Piece | Choice |
|---|---|
| Framework | **React Native**, on the Node.js already pinned for the frontend |
| Toolkit | **Expo**, not bare React Native |
| Build | **Expo EAS Build** |
| Navigation | React Navigation |
| State | **Zustand.** Redux Toolkit does the same job and is deliberately not used |
| Server state | TanStack Query, with Axios — the same pins as the frontend |
| Forms | React Hook Form — the same pin as the frontend |
| On-device storage | react-native-mmkv |
| UI components | React Native Paper |
| Journey tests | **Maestro**, see `knowledge/journey/AGENTS.md` |

**React Native and Expo move together.** Expo SDK 57 declares react-native 0.86.3 as
its bundled version. An agent that bumps one without the other has broken the pair, and
neither may be bumped at all — they are pinned.

React Native Paper renders Material design on **both** platforms. It does not become an
iOS-native look on iOS. That was accepted when it was chosen; it is not a defect to fix.

## Repository layout

One `mobile` repository per user group, the same split as frontends: an admin app and a
general-user app are two repositories, never one with a role switch.

```text
<workspace>-mobile-<user-group>/
├── app/                     # screens, navigation
├── src/
│   ├── api/                 # TanStack Query + Axios against the gateway
│   ├── store/               # Zustand
│   └── storage/             # MMKV
├── app.config.ts            # from templates/app.config.ts
├── eas.json                 # from templates/eas.json
├── package.json             # from templates/package.json
└── README.md
```

| Template | Copy to |
|---|---|
| `templates/package.json` | `package.json` |
| `templates/app.config.ts` | `app.config.ts` |
| `templates/eas.json` | `eas.json` |

## Device APIs

iOS and Android have different native APIs for the same thing. Expo covers the
difference: one call, and it reaches the right platform API underneath.

| Need | Use |
|---|---|
| Camera | `expo-camera` |
| Photos on the device | `expo-image-picker` |
| On-device storage | `react-native-mmkv` |
| Push notifications | `expo-notifications`, **only if the project asked for push** |
| Permission prompts | Expo's own permission handling |

A feature Expo does not cover may need native code. Everything above is covered; reach
for native code only when something genuinely is not.

## Configuration is embedded at build time

A mobile app cannot fetch configuration at runtime the way a server can — it is built
into a file and installed on a device.

- At build time, for each environment, values are pulled from the workspace's `config`
  repository and **embedded into that build**, through Expo's app config and EAS
  environments.
- One build per environment. A single build does not switch environments.

**No secret is ever embedded in a mobile build.** A user can unpack the file and read
it. A mobile build carries only public values — the API URL and the like. Anything
secret stays on the backend.

AI agents must not:

- Put a client secret, a private key, a datastore credential or any other secret in a
  mobile build, in `app.config.ts`, in an EAS environment variable or in the source.
- Have the app read configuration from anywhere but what was embedded at build time.

## Push notifications are per project

Push is **not** in the stack by default. The Requirement Analysis Agent asks, through
`knowledge/questions/AGENTS.md`, whether this project needs it.

| Answer | Result |
|---|---|
| No | `expo-notifications` is not added and nothing push-related is written. |
| Yes | `expo-notifications` is added, the code is written, and the agent hands the human a numbered menu of what to click in **both** the Android and the iOS portal to set up the provider credentials. |

That second half follows the same shape as the login providers in
`knowledge/auth/AGENTS.md`: the agent does what it can, the human does the portal.

## Emulators, simulators and what the agent can drive

| Platform | Device | Agent controls it with |
|---|---|---|
| Android | Android Emulator, from Android Studio | `adb` |
| iOS | iOS Simulator, from Xcode — **macOS only** | `simctl` |

The agent does not see the screen the way it sees a browser. When it needs to look, it
takes a screenshot and reads the image. For a real test it writes a Maestro flow rather
than driving the device by hand.

Both tools are free. iOS Simulator exists only on macOS, so a non-macOS machine can
build and test Android only.

## Build and signing

Mobile is unlike web: an app must be signed before it installs on a device or reaches a
store.

| Platform | Needs |
|---|---|
| iOS | A certificate and provisioning profile from the Apple Developer Program, which costs money per year |
| Android | A keystore, which is generated locally at no cost |

Builds go through **Expo EAS Build**, which handles most of the signing, including iOS
without a Mac. Building locally instead was considered and the decision landed on EAS.

Store submissions carry a real, increasing version number on every submission in both
repository layouts, because the stores enforce it. See `knowledge/versioning/AGENTS.md`.

## Traffic

A mobile app reaches the backend the same way everything else does: **through Nginx
only**, at the gateway address from the `config` repository. Never a backend port.

See `knowledge/nginx/AGENTS.md`.

## Must not

- Modify the knowledge files in this directory during normal project generation.
- Change a version pinned in `knowledge/tech-stack.yaml`, or move React Native and Expo
  apart.
- Add Redux Toolkit, or a second state library beside Zustand.
- Add `expo-notifications` to a project that did not ask for push.
- Embed any secret in a build.
- Put two user groups in one mobile repository.
- Point the app at a backend port instead of the gateway.
- Reuse a store version number.
