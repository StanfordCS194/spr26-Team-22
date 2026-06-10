# Eta

Eta is a lightweight iOS app that helps you maintain friendships by reducing friction around scheduling in-person hangouts. It monitors your calendar for open time slots, identifies friends you haven't seen recently, and surfaces a time-specific suggestion — making it easy to send an invite with one tap.

The core loop: **detect a free slot + identify an overdue friend → surface a time-specific suggestion → send an invite via iMessage.**

### Features

- **Smart suggestions** — combines calendar availability and relationship health scores to recommend who to hang out with and when
- **LLM-powered activity ideas** — uses GitHub Models (llama-3.1-8b-instruct) to suggest personalized activity ideas; falls back to a curated activity list when no API key is configured
- **Invite system** — send hangout invites to other Eta users via Supabase, or fall back to pre-filled iMessage for contacts not on the app
- **Weekly check-in** — a weekly summary of friendship activity, overdue friends, and a priority contact picker
- **Activity photos** — capture and surface photos from past hangouts on future suggestion cards
- **Nudge notifications** — daily nudge encouraging you to reach out to the friend who needs the most attention

### Tech stack

- iOS 26+, Swift 5.0, SwiftUI, SwiftData
- EventKit for calendar access, Contacts framework for contact picker
- Supabase (raw URLSession REST) for backend invite routing
- GitHub Models API for LLM inference

---

## Setting up LLM Suggestions

**NEVER PUSH API KEYS TO REMOTE**

**NEVER PUSH API KEYS TO REMOTE**

**NEVER PUSH API KEYS TO REMOTE**

The current iteration of Eta uses the free and open source [GitHub Models](https://github.com/marketplace?type=models) platform to serve LLM inference using `llama-3.1-8b-instruct`. To use the LLM-driven features, we need to provide an API key. For GitHub Models, we just need to create a Personal Access Token (PAT) with `read-only` permissions for `Models`. This is how you do it:

1. Sign in to GitHub and navigate to `Settings/Developer settings/Personal access tokens/Fine-grained tokens`.
2. Select `Generate new token`.
3. Add a name (e.g. `cs194-llm`), and optionally a description. Feel free to keep the other settings default.
4. Under `Permissions`, select `Add permissions`, search for `Models`, and select `Models`. You should see a new permissions entry for `Models` with `Access:read-only`.
5. Select `Generate token`, and make sure to copy the token to a secure place before leaving the page as this is the only time the token will be accessible.

Once you generate a token, we need to let Eta know what it is. For development, we do so by setting a key in our local `Config.xcconfig` file. The current `Config.xcconfig` file is set up to have an empty `LLM_API_KEY` key which the `Info.plist` looks for. By default, this field is empty. To add a key, modify the local `Config.xcconfig` file by pasting your key (as is, no quotes or anything necessary):

```
LLM_API_KEY = abcd...
```

At runtime, the `LLMRunner` will look for the config file specified in `Info.plist`, and from there find the required API key. If no key is found (as is the default behavior), generation will fallback to the pre-LLM behavior of picking a random activity from the `Activity` enum.

To avoid accidentally pushing keys to remote, the `Config.xcconfig` file is currently set to be ignored by source control in `.gitignore`. However, to make setup easier in this collaborative codebase, we track an empty `Config.xcconfig`. This means that changes will still be tracked dispite the `.gitignore`. To solve this, either be extra careful when managing local changes to the `Config.xcconfig` file so that you don't commit changes that include the personal access token (again, **NEVER PUSH API KEYS TO REMOTE**), or tell git to ignore the tracked file by running the following command at the root directory:

```
git update-index --assume-unchanged Eta/Config.xcconfig
```

Feel free to use whichever method is most convenient. One more time, **NEVER PUSH API KEYS TO REMOTE**.
