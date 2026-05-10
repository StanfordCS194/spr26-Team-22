# Eta


## Setting up LLM Suggestions

**NEVER PUSH API KEYS TO REMOTE**

**NEVER PUSH API KEYS TO REMOTE**

**NEVER PUSH API KEYS TO REMOTE**

What the implementation does:                                                                                                                                                           
  - Calls https://api.anthropic.com/v1/messages with claude-haiku-4-5-20251001                                                      
  - Sends systemPrompt as the Anthropic system field and userPrompt as the user message
  - Returns the raw text from the first content block

To use the LLM-driven features, we need to provide an Anthropic API key. For development, we do so by setting a key in our local `Config.xcconfig` file. The current `Config.xcconfig` file is set up to have an empty `ANTHROPIC_API_KEY` key which the `Info.plist` looks for. By default, this field is empty. To add a key, modify the local `Config.xcconfig` file by adding your key:

```
ANTHROPIC_API_KEY = sk-ant-...
```

At runtime, the `LLMRunner` will look for the config file specified in `Info.plist`, and from there find the required API key. If no key is found (as is the default behavior), generation will fallback to the pre-LLM behavior of picking a random activity from the `Activity` enum.

To avoid accidentally pushing keys to remote, the `Config.xcconfig` file is currently set to be ignored by source control in `.gitignore`. To make changes to `Config.xcconfig`, temporarily remove it from the `.gitignore`, add any changes, commit, and then return the `.gitignore` to the previous state. Be cautious when doing this, and **NEVER PUSH API KEYS TO REMOTE**.
