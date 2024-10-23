## Accessing and Using Demo

In the codespace, switch to the `Ports` tab. Right click port `30100` and choose `Open in Browser`

![ports open in browser](images/ports-open-in-browser.png)

A new browser tab will open and you should see the demo.

![application user interface](images/screenshot.png)

## Using LLM-based Destination Search

Type the name of a destination (eg. `Vienna`) into the search bar and click the `Advise` button.

### What Happens Next?

- The application will request information for your destination from OpenAI using ChatGPT 4o mini.
- A result will be returned from OpenAI
- The result is cached in the weviate vector cache

If you search for `Vienna` again, this time, the re1sult will be served from the cache - saving you the roundtrip (time and $) to OpenAI / ChatGPT.

## Customer Feedback

Click the 👍 and / or 👎 buttons to indicate your satisfaction level of the result.

Clicking these icons will [log a message](https://github.com/dynatrace-perfclinics/obslab-llm-observability/blob/905b38cf85adaafd87f83ff1f40c640206abdb82/app.py#L151){target="_blank"}. This log line is then retrieved and processed using DQL in the "User Sentiment Analysis" section of the dashboard.

<div class="grid cards" markdown>
- [Click Here to Continue :octicons-arrow-right-24:](visualise-dt.md)
</div>