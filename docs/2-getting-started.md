--8<-- "snippets/getting-started.js"
--8<-- "snippets/grail-requirements.md"

## Prerequisites before launching the Codespace

### Generate a Dynatrace Token 

To create a Dynatrace token

1.  In Dynatrace, go to **Access Tokens**.  
    To find **Access Tokens**, press **Ctrl/Cmd+K** to search for and select **Access Tokens**.
2.  In **Access Tokens**, select **Generate new token**.
3.  Enter a **Token name** for your new token.
4.  Give your new token the following permissions:
5.  Search for and select all of the following scopes.
    -  **Ingest metrics** (`metrics.ingest`)
    -  **Ingest logs** (`logs.ingest`)
    -  **Ingest events** (`events.ingest`)
    -  **Ingest OpenTelemetry traces** (`openTelemetryTrace.ingest`)
    -  **Read metrics** (`metrics.read`)
    -  **Write settings** (`settings.write`)
6.  Select **Generate token**.
7.  Copy the generated token to the clipboard and be ready to use it in the next step.
   
!!! warning "You can only access your token once upon creation. You can't reveal it afterward."

!!! tip "Let's launch the Codespace"
    Now we are ready to launch the Codespace!


<div class="grid cards" markdown>
- [Let's launch Codespaces:octicons-arrow-right-24:](3-codespaces.md)
</div>
