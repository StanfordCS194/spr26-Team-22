# Eta


## Setting up LLM Suggestions

**NEVER PUSH API KEYS TO GITHUB**

**NEVER PUSH API KEYS TO GITHUB**

**NEVER PUSH API KEYS TO GITHUB**

What the implementation does:                                                                                                                                                           
  - Calls https://api.anthropic.com/v1/messages with claude-haiku-4-5-20251001                                                      
  - Sends systemPrompt as the Anthropic system field and userPrompt as the user message
  - Returns the raw text from the first content block

To set the API key, create a local config file at `Eta/Config.xcconfig` (gitignored, **never hardcode it in source and never push the key to GitHub**):

```
ANTHROPIC_API_KEY = sk-ant-...
```

At runtime, the `LLMRunner` will look for the config file specified in `Info.plist`, and from there find the required API key. If no key is found, generation will fail with an `LLMError.missingAPIKey`.
