---
name: memory-bank-setup
description: >
  Add cross-session long-term memory to an ADK agent using Agent Platform's
  Vertex AI Memory Bank, and wire it into the agent. Use when the user wants to
  "add memory", "add a Memory Bank", "remember facts/preferences across
  sessions", "make my agent remember me between conversations", or asks why
  memories aren't persisting / aren't showing in the Cloud Console. Covers the
  agent-side wiring (PreloadMemoryTool + a memory-generation callback), creating
  the managed Memory Bank instance, pointing the runtime's memory service at it
  (local ADK Web and deployed Agent Runtime), verifying in the Console, and the
  gotcha that `agents-cli deploy` does NOT configure a memory service on its own.
---

# Vertex AI Memory Bank — cross-session memory + ADK integration

**Sessions** remember one conversation. **Memory Bank** remembers facts and
preferences *across* conversations (e.g. "the user is gluten-free", "call me
Dr. Vance", "always answer in metric"). Every turn, Memory Bank reads the
conversation, extracts durable snippets, and stores them keyed by `user_id` so
future sessions can recall them.

This skill adds Memory Bank to an ADK agent (including an `agents-cli`-scaffolded
project) and wires it end to end.

## Mental model (how it works end to end)

```
Write (per turn):  session events ─▶ after_agent_callback ─▶ add_session_to_memory()
                                    ─▶ Memory Bank extracts + stores durable facts

Read  (per turn):  PreloadMemoryTool ─▶ search_memory(user_id) at turn start
                                      ─▶ relevant memories injected into the system instruction
```

Two moving parts:
1. **The agent code** — a memory *tool* (reads) + a *callback* (writes). Same for
   every runtime.
2. **A memory service** pointed at a **Memory Bank instance**. This is the part
   that changes between local and deployed, and the part `agents-cli` does **not**
   set up for you.

## The one thing that trips people up

**A "Memory Bank instance" is just an Agent Engine (Reasoning Engine)
instance.** You create one with `client.agent_engines.create()`; its resource
name is `projects/<p>/locations/<loc>/reasoningEngines/<ID>` and `<ID>` is the
Memory Bank ID you pass everywhere as `agentengine://<ID>`.

Consequences:
- Memory Bank is a **managed cloud resource** — you cannot see real, persisted
  memories with a purely in-memory local run. ADK defaults to
  `InMemoryMemoryService` unless you explicitly point it at a Memory Bank
  instance.
- **`agents-cli deploy` does not wire a memory service.** It configures a
  *session* service on Agent Runtime, but leaves the memory service at ADK's
  default. Adding the tool + callback is necessary but **not sufficient** — you
  must also point a memory service at a Memory Bank instance (steps below).
- Because it's a cloud resource, do memory work **after** (or alongside) a first
  deploy, or create a standalone instance for local testing — not before any
  Agent Engine exists.

## Prerequisites (one-time)

```bash
PROJECT=your-project-id
LOCATION=us-central1          # use a Memory-Bank-supported region
gcloud config set project "$PROJECT"
gcloud services enable aiplatform.googleapis.com --project="$PROJECT"
gcloud auth application-default login   # already done if you logged in via `agy`
```

Memory Bank runs in specific regions — see
https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/agent-locations.
Keep `GOOGLE_CLOUD_LOCATION` consistent with the region you create the instance in.

## Step 1 — wire the agent (tool + callback)

Edit the agent definition (in an `agents-cli` project this is `app/agent.py`).
Add a **memory-generation callback** and a **memory tool**:

```python
from google.adk.agents import Agent
from google.adk.agents.callback_context import CallbackContext
from google.adk.tools.preload_memory_tool import PreloadMemoryTool
# Alternative tool: from google.adk.tools.load_memory_tool import LoadMemoryTool


# WRITE: after each turn, send the session to Memory Bank for extraction.
async def generate_memories_callback(callback_context: CallbackContext):
    await callback_context.add_session_to_memory()
    return None


root_agent = Agent(
    model="gemini-3.6-flash",
    name="root_agent",
    instruction=(
        "You are a helpful assistant. You remember the user's stated "
        "preferences and facts from previous conversations and use them to "
        "personalize your responses."
    ),
    # READ: PreloadMemoryTool retrieves memories at the start of every turn and
    # injects them into the system instruction (no explicit tool call needed).
    # Use LoadMemoryTool() instead if you want the model to fetch on demand.
    tools=[PreloadMemoryTool()],
    after_agent_callback=generate_memories_callback,
)
```

That's the whole agent-side change. It is runtime-agnostic — the same code works
locally and deployed. **`add_session_to_memory()` and the tools are no-ops
against an in-memory service**, so they only produce durable memories once a real
Memory Bank instance is wired in (next steps).

> Only send salient turns to memory. `add_session_to_memory()` at the end of a
> turn is the simplest; for finer control use
> `callback_context.add_events_to_memory(events=...)` with a subset of events.

## Step 2 — create a Memory Bank instance

If you have **already deployed** with `agents-cli`, you already have an Agent
Engine — you can reuse its ID as the Memory Bank ID (skip to Step 3). Otherwise
create a standalone instance (`scripts/create_memory_bank.py`):

```python
import vertexai

PROJECT_ID = "your-project-id"
LOCATION   = "us-central1"

client = vertexai.Client(project=PROJECT_ID, location=LOCATION)

# A Memory Bank instance IS an Agent Engine instance. Default config is fine
# for the lab; it extracts general user facts/preferences automatically.
memory_bank = client.agent_engines.create()

resource_name = memory_bank.api_resource.name       # projects/.../reasoningEngines/NNN
memory_bank_id = resource_name.split("/")[-1]        # NNN  ← use this everywhere
print("MEMORY_BANK_ID:", memory_bank_id)
print("resource name :", resource_name)
```

Save the printed `MEMORY_BANK_ID`. (To customize *which* topics are extracted —
`USER_PERSONAL_INFO`, `USER_PREFERENCES`, `EXPLICIT_INSTRUCTIONS`,
`KEY_CONVERSATION_DETAILS` — see the "Configure your Memory Bank instance"
section of the Set up docs; the default config needs no customization.)

## Step 3 — point a memory service at the instance

The memory service must be given the `agentengine://<MEMORY_BANK_ID>` URI. Pick
the row that matches how the agent runs:

| Runtime | How to wire the memory service |
|---|---|
| **Local ADK Web** (fastest to test) | `adk web --memory_service_uri=agentengine://MEMORY_BANK_ID` |
| **Deployed on Agent Runtime** | Set the memory service in the app (below) so the deployed container uses Memory Bank, not the in-memory default |
| **Local `Runner` / script** | `VertexAiMemoryBankService(project=..., location=..., agent_engine_id=MEMORY_BANK_ID)` passed to `Runner(memory_service=...)` |

### Local test (recommended first)

```bash
export GOOGLE_CLOUD_PROJECT="your-project-id"
export GOOGLE_CLOUD_LOCATION="us-central1"
# Run from the folder that contains the agent package (e.g. the project root
# with app/ inside). This overrides ADK's in-memory default.
adk web --memory_service_uri=agentengine://MEMORY_BANK_ID
```

`agents-cli playground` runs `adk web` but does not forward
`--memory_service_uri`, so for a *real* Memory Bank locally run `adk web`
directly with the flag.

### Deployed on Agent Runtime (agents-cli project)

`agents-cli deploy` will not attach a memory service, so set one explicitly in
the app so the deployed container uses Memory Bank. In the ADK app definition
(the `AdkApp` / `get_fast_api_app` wiring — see the `google-agents-cli-deploy`
and `google-agents-cli-adk-code` skills for the exact file in this project
version), provide a memory-service builder:

```python
from google.adk.memory import VertexAiMemoryBankService

def memory_bank_service_builder():
    return VertexAiMemoryBankService(
        project="your-project-id",
        location="us-central1",
        agent_engine_id="MEMORY_BANK_ID",   # reuse the deployed engine's ID, or a standalone one
    )
# Pass memory_service_builder=memory_bank_service_builder to AdkApp,
# or --memory_service_uri=agentengine://MEMORY_BANK_ID to the ADK deploy command.
```

Then redeploy. Confirm the deployed agent actually persists memories (Step 4) —
don't assume the default did it.

## Step 4 — verify

1. **Talk to the agent** (local ADK Web or the deployed playground): state a
   durable fact, e.g. *"Remember that I'm allergic to penicillin."*
2. **Start a NEW session** and ask something that needs it — the agent should
   recall it without being reminded.
3. **See the stored memory in the Console:**
   https://console.cloud.google.com/agent-platform/memory-bank
   (Vertex AI → Agent Engines → your instance → Memory Bank.) Allow a few
   seconds — extraction runs in the background after the turn.

## Troubleshooting

- **Memories never persist / nothing in the Console** → you're on the default
  `InMemoryMemoryService`. The tool + callback alone don't create a bank; you
  must pass `--memory_service_uri=agentengine://<ID>` (local) or set
  `VertexAiMemoryBankService` in the deployed app. This is the #1 cause.
- **Works locally, not when deployed** → `agents-cli deploy` didn't wire a
  memory service; add the `memory_service_builder` / `memory_service_uri` and
  redeploy (Step 3, deployed row).
- **Recalls in the same session but not across sessions** → you're seeing
  *session state*, not memory. Confirm `PreloadMemoryTool` is in `tools` and the
  `after_agent_callback` is set, and that both sessions use the **same
  `user_id`** (memories are scoped by `user_id` + `app_name`).
- **`NOT_FOUND` / permission errors on the memory service** → the
  `MEMORY_BANK_ID` region must match `GOOGLE_CLOUD_LOCATION`, and it must be a
  Memory-Bank-supported region; the caller/service account needs
  `roles/aiplatform.user`.
- **`'await' outside function`** in a standalone script → wrap async calls in
  `asyncio.run(...)`; ADK is async-first.
