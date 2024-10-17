The user interacts with the demo app (travel advisor) on port `30100`. The app is monitored either via native OpenTelemetry.

The user enters a destination (eg. `Sydney`):

* The application first checks the cache.
    * If a response for `Sydney` is found, the response is returned from the cache.
    * If a cached response is not available, the application requests advice from the LLM (OpenAI's ChatGPT).
* The response is returned and cached so that subsequent calls for the same destination (eg. `Sydney`) are served from the cache. This saves roundtrips to ChatGPT and thus `$`.

## [>> Click here to continue with the exercise](how-it-works-rag.md)