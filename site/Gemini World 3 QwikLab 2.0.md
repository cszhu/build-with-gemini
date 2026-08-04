# Introduction

In this lab, you'll learn how to build an entire production-ready agentic application using Google Cloud tools.

You will:

- Prototype an agent using `agents-cli`
- Equip your agent with an enterprise-ready harness that includes Memory, Sessions, Tools, Persistent Storage, and code execution
- Evaluate and improve the quality of your agent's responses
- Deploy your agent to Agent Platform
- Equip your agent with the power to use Google's Generative Models
- Build an agent-first frontend, hosted on Cloud Run and powered by A2UI

# Set Up Your Environment

For this lab, you'll be given access to a temporary GCP environment with ephemeral credentials. You can find your temporary username, password, and project ID here:

![](images/findcreds.png)

Noting your credentials, right click "Open Lab Console" and select "Open Link in Incognito Window":

![](images/incognito.png)

When prompted, enter your provided credentials. You should be taken to the GCP console, which looks like this:

![](images/gcp-console.png)

Today, we'll be developing in a [Workstation](https://cloud.google.com/workstations)--a fully managed development environment that runs on a Virtual Machine. To access your workstation, search "Workstation" in the top search bar:
![](images/search_workstation.png)


You should have a workstation pre-provisioned. Just click launch!
![](images/launch_workstation.png)

 We'll do all our development here, in what's called "Code OSS" (i.e. the Editor within a Workstation):
![](images/workstation_developer_interface.png)

> **Important** Make sure you are using Code OSS from within a Workstation. If you try to use the terminal outside of a Workstation, you'll quickly run out of resources.

Click the button in the upper right hand corner to open a terminal:
![](images/open-terminal.png)

## Authenticate

In the terminal, run the following commands to set up authentication using your provided credentials. Do NOT use your personal credentials.

```bash
gcloud auth login --update-adc
```

## Installing Skills and MCPs
In this lab, we'll generate code with **Antigravity CLI** (AGY for short), Google's command-line-based agentic development environment that makes it easy to use coding agents.

But before we launch Antigravity, we'll download a starter repo from Github that contains various skills and configurations that will make this lab easier to complete:

```bash
git clone https://github.com/cszhu/build-with-gemini
cd build-with-gemini
```

Inside this repo, you'll find an `.agents` directory with some pre-written skills and MCP configuration. 
![](images/hidden-skills.png)

When we load Antigravity in the next step, it will automatically check this folder and load the skills and MCP into its environment.

> **What is a skill?** A bundle of instructions that teaches your coding agent how to do a specific task well. It loads automatically when it's relevant, so you get expert behavior without spelling out every step yourself.

> **What's an MCP?** Model Context Protocol (MCP) is a standard way to plug external tools and data sources into your coding agent. An MCP *server* gives the agent a new ability — e.g. searching Google's official documentation, working with databases.

The skills you just downloaded are specific to this Lab, but to help us develop agents more generally, we'll install skills using **[agents-cli](https://google.github.io/agents-cli/guide/getting-started/)**--a toolkit designed to make building agents on Google Cloud easy:

```bash
agents-cli setup --skip-auth
```

> **What is agents-cli?** Google's CLI for the full agent development lifecycle (scaffold, deploy, evaluate, and publish), built on the [Agent Development Kit (ADK)](https://google.github.io/adk-docs/).

Now that you have cloned the repo, you can open the repo you just cloned by clicking the button that says "Open Folder" in your workstation and then selecting `build-with-gemini`. This should show you the repo you just cloned:

![](images/open_folder.png)

## Launching Antigravity
Next we'll launch Antigravity:

```bash
agy
```

When asked, **choose option 2 to authenticate with a Google Cloud project** and complete the sign in flow with the provided credentials.
![](images/agy-cloud-login.png)

> **Avoid agent confusion!** In this workshop, we'll be _building_ an agent with the help of an _additional_ agent--specifically, with the coding agent Antigravity (AGY). It's helpful to keep this distinction in mind as we go through the lab.

Let's check that the skills and MCP we configured in the last step have been picked up by Antigravity. We can view skills by running the `/skills` command **in Antigravity**:

![](images/verify-skills.png)

> **Why skills matter:** by packaging the right steps and context up front, skills save tokens and time and improve accuracy — the agent completes a task in fewer steps, instead of rediscovering (and sometimes getting wrong) the workflow every time.

Next let's verify our MCPs are installed by running `/mcp` in Antigravity:

![](images/verify-developer-mcp.png)

You should find (at least) two MCPs configured:
- **[Developer Knowledge MCP](https://codelabs.developers.google.com/developer-knowledge-mcp-antigravity)** — gives AGY **grounded, current knowledge of Google's official docs** (Google Cloud, Firebase, ADK, and the Agent Platform products you'll use later) instead of guessing commands, which keeps the later modules out of trial-and-error spirals.
- **[Firebase MCP](https://firebase.google.com/docs/ai-assistance/mcp-server)** — lets AGY work directly with Firebase services like Firestore, which you'll use for persistent storage.

We're almost ready to start building, but first, let's check to make sure everything is set up correctly. Tell Antigravity to:

```text
Verify my setup.
```

![](images/verify-setup2.png)

Your output might look a little different than the screenshot above, but as long as it says you're good to go, you're probably good to go.

This invokes the `troubleshoot-lab-setup` skill we downloaded earlier from Github to confirm your environment is set up correctly. If anything is misconfigured, Antigravity should be able to resolve it on its own, or give you instructions to fix the setup.

Your setup is complete--let's start building! 🎊

# Build Your First Agent

Later in this lab, you'll design your own bespoke agentic application. But for now, let's build and test a basic agent together. Tell AGY to build a basic agent and run it locally.

```
Use agents-cli to build a simple agent I can test and run it locally.
```

When it's done, AGY should produce something like:

![Antigravity scaffolding your first agent — the agents-cli output showing the agent has been created](images/scaffold.png)

Behind the scenes, `agents-cli` scaffolds a complete ADK project for you: a Python agent definition, its configuration, and the local run/playground setup — all the boilerplate you'd otherwise write by hand — so you can go straight to shaping your agent's behavior.

We can then tell AGY to test our agent from the command line:

```
Test my agent with the message, "What's the weather in New York?"
```

We can find the logic for our agent in the file `app/agent.py`:
![](images/cloud-shell-editor.png)

> Tip: If you navigate away from your terminal and AGY exits, you can always access past sessions by opening AGY again and running `/resume`.

## The Playground

We can also test our agent in the **Playground** — a local, browser-based chat interface. Beyond just chatting, it gives us visibility into how our agent actually works: we can inspect **sessions**, step through the **traces** of each turn, and debug the tool calls and responses behind every answer. Tell AGY to:

```
Launch agent playground for me.
```

Antigravity will launch Playground on a local port. Access it by clicking the "Open Preview" button in the lower right hand side of the screen:

![](images/playground-port.png)

Here you can chat with our agent from a UI. On the left hand side of the screen, we can see what tools our agent has access to. Depending on how you told AGY to create an agent, your agent may have some basic tools (in this case, `get_weather`). These are blocks of deterministic, functional code your agent can call to complete tasks. We'll add more later.

![](images/playground-simple.png)

In the `Traces` tab, we can see the exact sequence of actions our agent took before producing a reply:
![](images/playground-trace.png)

On the top bar of the screen, we can view our existing sessions and create new ones. 
![](images/playground-session.png)

**Sessions** consist of the log of messages in a current conversation, as well as a scratchpad of temporary state which can view in the state tab:
![](images/playground-state.png)

## Deploy to Agent Platform

Deploying our agent to Google Cloud is as simple as telling Antigravity to deploy our agent to Agent Platform:

```
Deploy my agent to agent platform.
```

![](images/agent-deploy.png)

This could take a minute. When your agent is finally deployed, you'll be able to view it in Agent Platform:

![](images/view-deployment-1.png)
![](images/view-deployment-2.png)
![](images/view-deployment-3.png)

Clicking in, we can see the extended tool suite available for monitoring our agent in production:
![](images/view-deployment-4.png)


# Design Your App

So far we've built and deployed an extremely simple agent--basically, a chatbot. In this next section, we'll evolve **that same agent** into an application of your own design, augmenting it with capabilities like:
- Calling tools (i.e. running code, calling an API, interacting with a database)
- Conversation Memory (for storing information about a user between sessions)
- Database/blob storage access for external application data (i.e. users, product inventory, images)
- The ability to generate images
- A snazzy frontend

Now's a good spot to pause and decide what kind of agentic application you'd like to build. It doesn't have to be complicated — a good workshop project is one narrow task with a bit of data behind it. For example:

- A **recipe assistant** that suggests meals from ingredients you have on hand and saves your favorites.
- A **book concierge** that recommends titles, tracks your reading list, and generates cover art.
- A **workout coach** that builds a plan, logs your sessions, and charts your progress.
- A **travel planner** that assembles an itinerary and illustrates each destination.
- A **plant-care helper** that tracks your plants, reminds you when to water, and diagnoses problems from a photo.

Notice these all share the same shape you'll build here: a conversation, some stored data, a tool or two, and generated media. Whatever you pick, it'll use those same ingredients.

Once you have a basic idea (or if you need help coming up with one), ask AGY for help designing your agentic application.
This will invoke the `pick-your-agent-project` skill. In AGY, describe whatever you'd like to build, or swap in your own idea:

```
Help me design my agentic application. I need help brainstorming what specific agent to build.
```

When you're done, AGY will output a `project_brief.md` file for your review. Edit it yourself or with AGY until you have something you like:
![](images/designbrief.png)

Our agent will use this for reference as we continue development.

## Rename your agent

Now that you have a brief, rename your existing agent project to match the app you're building:

```
Use the newly created project_brief.md to rename my existing agent project to match it: rename the project folder and update the name in agents-cli-manifest.yaml and pyproject.toml. Keep the code in app/ unchanged, and don't deploy or change any agent logic yet.
```

# Add Memory

While **sessions** store information about a current conversation, sometimes we want to remember facts _between_ sessions. Example: if a customer tells a shopping agent he hates the color red, that fact should be present across _all_ future sessions.

We can enable this cross-session remembering with Agent Platform's [Memory Bank](https://docs.cloud.google.com/gemini-enterprise-agent-platform/scale/memory-bank). Every time the user sends the agent a message, Memory Bank analyzes the conversation and automatically extracts and remembers factual snippets that might be useful to future conversations.

Let's tell AGY to set up memory using its skill:

```
Use the memory-bank-setup skill to add memory to my agent using a Vertex AI Memory Bank instance. Then rewrite my agent to use the new memory service and redeploy.
```

Depending on your application, you can be more specific about what to remember:

```
Configure memory so that all user allergies are remembered.
```

To try it out, chat with your **deployed** agent (in the browser) and tell it a durable fact about yourself (for example, a preference). Memory Bank extracts memories in the background after the turn. You can then see the stored memories in the Agent Platform UI [here](https://console.cloud.google.com/agent-platform/memory-bank):

![A memory stored in the Agent Platform Memory Bank UI](images/apothecary-memory.png)

If you don't see any memories logged here, you may need ask Antigravity to redeploy your agent.

# Add Persistent Storage

Memory Bank is perfect for remembering conversational facts about a *user* — their preferences, details they've mentioned, how they like to be addressed. But it's not a general-purpose database. For your app's actual *data* — the things it looks up and writes to, that aren't tied to one user's conversation (a product catalog, a booking, an inventory count, generated images) — you'll want dedicated persistent storage.

Depending on your application, you may require an external data store, like:

- **Structured data** (inventory, orders, user records) → a database like **Firestore** (serverless, simple).
- **Raw files/blobs** (bulk images, static assets) → **Cloud Storage (GCS)**.

Let's start by implementing structured data in Firestore. Antigravity is already equipped with the [Firebase MCP](https://firebase.google.com/docs/ai-assistance/mcp-server) (pre-configured back in [Installing Skills and MCPs](#installing-skills-and-mcps)), so it can work with the Firestore API directly.

Ask AGY to give your agent a Firestore backend. Describe a collection that fits whatever you're building. AGY can look at your project_brief.md and pick sensible fields. Adapt this prompt to your own domain:

```
Give my agent a Firestore backend: a collection that fits my app (look at my project_brief.md) with a few sensible fields, function tools to read and write it, and a few seeded items. Important: hardcode my project ID as a string for the Firestore client and the seed script (find it with `gcloud config get-value project`). Don't read it from `google.auth.default()` or `GOOGLE_CLOUD_PROJECT`; on Agent Platform those return the project number, which breaks Firestore after you deploy.
```

For example, a store/marketplace agent might use an "inventory" collection with name, description, price, and stock; a travel agent might use a "destinations" collection; a recipe agent a "recipes" collection. 

In the Playground, we can verify this worked by asking the agent something it can only answer by querying the database — adapt it to your domain (for a store: *"What items do you have in stock?"*; for a travel agent: *"What destinations do you know about?"*).

You can watch the data live in your Firestore database [here](https://console.cloud.google.com/firestore/databases/-default-). A nice property of Firestore is that it's **real-time**: as your agent writes (say, an action that updates a record), the document updates instantly in the browser. What's more, you can edit entries in the browser and see them reflected immediately in the agent.

![The Firestore data viewer in the Firebase console shows your seeded collection.](images/firestore.png)

## Store Files in Cloud Storage

Firestore is great for structured records, but for raw files — images, audio, video — you'll want **Cloud Storage**. This is handy when your agent generates media that you want to persist and serve publicly, for example so your frontend can embed it as an image.

Ask AGY to create a bucket. Adapt the name to your app:

```
Create a Cloud Storage bucket for this project. Give it a name that fits my app (look at my project_brief.md; add a short random suffix if the name is taken), and set the permissions so objects can be viewed publicly (i.e. embedded in a web page as images).
```

To confirm your bucket was created, find it here: [https://console.cloud.google.com/storage](https://console.cloud.google.com/storage).

In the image-generation step below, your agent uploads each generated image to this bucket and gets back a public URL. A public URL is a plain `https` link that any browser can load, so the image can appear inside your agent's A2UI cards and in your custom frontend. You can also save that URL on the item's Firestore record so it shows whenever the item is looked up.

# Add Tools

Right now, your agent can only talk. Tools are functions that your agent can use to actually do things and execute. Some tool examples are: looking up data from a database, taking an action (like sending an email), creating something. This is when your agent stops just being a chatbot and starts actually doing things.

Every agent is different, so start by asking your coding AI assistant for tools that fit the agent you've decided to build:

```bash
Look at my project_brief.md and the agent I'm building. Suggest 2-3 tools it could call to take real action or fetch real data, then recommend the simplest one to implement first.
```
After discussing and planning with your agent, pick one to implement. 

```bash
Implement the tool we just discussed as a function tool and add it to my agent. Keep the implementation minimal.
```

Test it in the agent playground or debug screen. Ask it to do something that the tool is able to do, and the agent should be able to call the tool. You should be able to confirm this trace in the logs. 

# Ground Your Agent with RAG

Sometimes your agent needs to answer from a reference document — a product manual, a policy handbook, a collection of recipes, a set of research papers — that's too large to paste into a prompt. **RAG (Retrieval-Augmented Generation)** solves this: you index your documents into a **corpus**, and at runtime your agent retrieves only the most relevant passages and grounds its answer on them, instead of guessing.

Under the hood, the corpus is built once — your documents are chunked, embedded, and stored in a managed vector database. Your agent then reaches the corpus through a **retrieval tool**, the same kind of tool you just added, but backed by semantic search over your own documents.

To try this out, find or create a reference document. A .txt file is simplest. We'll use an [old-timey medical guide](https://www.gutenberg.org/cache/epub/49513/pg49513.txt) from Project Gutenberg. First upload your document:

![Uploading the reference document](images/upload_file.png)

Now ask AGY to build the corpus and wire retrieval into your agent. This uses the `rag-engine-setup` skill, which creates a **serverless** RAG corpus (the cheapest, no-allowlist option) and adds the retrieval tool for you:

```
Use the rag-engine-setup skill to ground my agent on the document <your_document_path_here>: create a serverless Vertex AI RAG corpus, import and index the file, then add a retrieval tool so my agent answers from the corpus.
```

Building the corpus takes a few minutes — the files are parsed, chunked, and embedded before the index is ready. When it's done, test it in the Playground by asking something that can only be answered from your documents. Adapt the question to your domain (for a recipe agent: *"What's a good remedy for a cough?"*; for a policy bot: *"What's the refund window?"*). The agent should call the retrieval tool and answer from the retrieved passages rather than making something up.

You can watch this happen in the Playground's trace: the retrieval tool fires, returns the top matching chunks, and the model composes a grounded answer from them.

You can also inspect your corpus and its indexed files in the console [here](https://console.cloud.google.com/agent-platform/rag):

![The Vertex AI RAG Engine showing your corpus and its indexed documents](images/culpeper-retreival.png)

# Generate Images
Tools can also give your agent the power of Google's generative AI models. A great one to reach for is image generation with `gemini-3.1-flash-lite-image` (Nano Banana 2 Lite), Google's fastest image model, which turns a short text prompt into an image so your agent can create visuals on demand. It runs in the `global` region. You can read about it here: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/3-1-flash-lite-image

```
Add a tool that generates an image for an item in my agent's domain (look at my project_brief.md) using the gemini-3.1-flash-lite-image model in the global region. Do two things with the generated image: (1) save it with tool_context.save_artifact so it shows up in the Playground's Artifacts panel, and (2) upload the same image bytes to the public Cloud Storage bucket I created earlier and return its public https URL (https://storage.googleapis.com/<bucket>/<object>) from the tool. Hardcode the bucket name as a string, the same way we hardcoded the Firestore project. Do not write the image to a local file and return a path. Use the Developer Knowledge MCP to confirm the API if you're unsure.
```

The tool does two things because each output has a different use. The saved artifact shows in the Playground's Artifacts panel, which is a quick way to see the image while you develop. The public URL is what you use later: your agent can put it in an A2UI Image component to show the picture inside a card, and your frontend can load it. The Artifacts panel only works inside the Playground, so the public URL is what makes the image visible elsewhere.

Now ask your agent to generate an image for one of the items in your domain. You should get back a real image, which appears in the Artifacts panel.
![](images/image-generation-food.png)

# Run Code in a Sandbox

Some agents need to execute code, whether that's for quick API calls, data analysis, or just doing math. Agent Platform offers code execution in an isolated sandbox, so your agent is able to code safely. Since the state persists across sessions and it doesn't touch your host, it is a very safe way to run model-generated code, even in enterprise settings.

Prereqs: the Agent Platform API enabled, and your agent's identity has roles/aiplatform.user.

```bash
Add Agent Platform code execution to my agent using AgentEngineSandboxCodeExecutor so it can safely run Python in a sandbox. If I don't already have a sandbox, create one from my agent engine resource.
```

Test it by asking a question that requires real computation or analysis, like fizzbuzz, and confirm the agent runs code in the sandbox and answers from the result.

Of course, you are able to update your tool instructions from the last section to use the sandbox as well. For folks who are building agents for things like auto-trading or coding, this is a super useful feature to incorporate into your agent.

# Enrich Responses with A2UI

So far your agent replies in plain text. A2UI lets it reply with real UI instead: cards and tables. Your agent writes a small description of the UI as JSON, and a renderer turns that JSON into components on screen. A2UI is open source and works with any agent built with ADK. (In the ADK dev UI the cards are **display-only** — buttons and forms show but don't do anything; keep your UI to cards and tables built from rows and columns.)

There are two pieces to set up, and you need both, or you will just see raw JSON:

1. A system prompt that teaches the model to output valid A2UI JSON. The a2ui-agent-sdk builds this for you with `A2uiSchemaManager`.
2. A small callback (`a2ui_utils.py`) that wraps the model's JSON in the format the ADK dev UI's built-in renderer expects. You add it to your agent as an `after_model_callback`.

Ask AGY to set up both. This uses the `enable-a2ui` skill, which ships the callback file for you:

```bash
Use the enable-a2ui skill to add A2UI to my agent: build the system prompt with A2uiSchemaManager (version 0.8) and the Basic Catalog, copy in a2ui_utils.py, and wire it up as an after_model_callback.
```

One thing to watch: pin A2UI to version 0.8. The callback recognizes v0.8 messages, so if the schema manager emits v0.9 the callback never fires and you are back to raw JSON.

Now test it in the same Playground you have been using. The Playground is really the ADK dev UI (`agents-cli playground` runs `adk web` for you), and it comes with a built-in A2UI renderer. It only renders A2UI once the callback is in place, so restart the Playground to pick up your changes:

```bash
Restart the agent playground so it picks up my latest changes.
```

Start a new session, then ask for something that fits a card or table. For a store agent, "Show me what's in stock" might render a table, and "Tell me about this item" might render a card. Adapt the question to whatever your agent knows about. You should see real UI instead of JSON.
![](images/a2ui-in-adk-playground.png)

A card can also show an image. Add an `Image` component and set its URL to the public URL your image tool returns, and the picture appears inside the card instead of only in the Artifacts panel. Ask your agent to generate an image for an item and show it, and you should get a card with the picture in it. The URL must be a public `https` link. A bare artifact filename cannot be loaded by the renderer and shows as a broken image.

One important setting: **turn Token Streaming OFF** in the Playground (the toggle in its settings). With streaming on, the dev UI shows the raw streamed JSON and never swaps in the card. If you still see raw JSON after that, check that the callback is wired up and that you are on version 0.8, then hard-refresh and start a new session. (If the Playground in your environment still won't render it, you can run the dev UI directly with `uv run adk web --port 8080 --allow_origins "*" --reload_agents`.)

# Build a Frontend

Up to now you've tested everything in the ADK playground, and that's been your agent's "face" while you built out storage, tools, media, and A2UI. Now, let's give your agent a shareable web face and ship it to the cloud.

## Redeploy your finished agent

Your agent has grown a lot since you first deployed it: it now has storage, tools, media generation, a sandbox, and A2UI, none of which are in that original deployment. Before wiring up a frontend, push the latest version to Agent Platform so the frontend talks to the fully-featured agent:

```bash
Redeploy my agent to Agent Platform.
```

Do this next if your agent uses Firestore or Cloud Storage. The deployed agent runs as its own service account, which has no access to your data by default. It worked in the Playground because you ran as yourself. On the deployed agent a Firestore query comes back empty, and an image upload to Cloud Storage fails and no image appears. Grant the roles the deployed agent needs:

```bash
Grant my deployed agent's service account the roles it needs: roles/datastore.user for Firestore, and roles/storage.objectAdmin on my image bucket if it generates images.
```

This uses the `troubleshoot-lab-setup` skill to grant those roles to your agent's runtime service account.

Grab the resource name from the fresh `deployment_metadata.json`. You'll point the frontend at it in a moment.

## Build the frontend

We don't hand you a pre-built frontend. Instead, ask AGY to build a minimal one for you. This invokes the `build-agent-frontend` skill, which copies a small FastAPI proxy and chat UI into a `frontend/` folder. The browser only ever talks to the proxy (same origin, no CORS), and the proxy authenticates to your deployed agent with Application Default Credentials.

The chat shows your agent's text replies and renders its A2UI cards. The same cards you saw in the ADK dev UI now show up in your own web app, including any generated images (the card's `Image` points at the public URL from your Cloud Storage bucket). The template ships a small built-in renderer, so it works whether or not your agent uses A2UI (anything it can't render falls back to plain text).

```bash
Using the build-agent-frontend skill, copy its minimal FastAPI proxy and chat UI template into ./frontend and wire it to my deployed agent using AGENT_ENGINE_RESOURCE_NAME and AGENT_DIRECTORY (my agent_directory from agents-cli-manifest.yaml). Keep it a plain chat UI. Do not build a React app or pull in a large sample frontend.
```

(If your project already has a web frontend you'd rather keep, tell AGY to adapt that one to the same proxy pattern instead of creating a new one.)

## Test Locally

Before deploying the frontend, confirm that your code can reach your agent that is currently deployed on Agent Platform. Running locally means the frontend server runs on your machine instead of Cloud Run, but it talks to the same deployed agent. This catches wiring issues before you ship to Cloud Run.

Ask AGY to install the frontend and start it locally, pointed at your deployed agent:

```bash
Run my frontend locally from the frontend/ folder: install its dependencies, set AGENT_ENGINE_RESOURCE_NAME to the resource name in deployment_metadata.json and AGENT_DIRECTORY to my agent_directory from agents-cli-manifest.yaml, then start the server on http://localhost:8080.
```

If you would rather run it yourself, from the `frontend/` folder:

```bash
pip install -r requirements.txt
export AGENT_ENGINE_RESOURCE_NAME="<paste the resource name from deployment_metadata.json>"
export AGENT_DIRECTORY="app"
python main.py
```

Then test it in your browser:

1. Open http://localhost:8080 and you should see your chat UI.
![](images/frontend-skeleton-demo.png)
2. Send a message and wait for a reply. Then, in the same chat, ask "What did I just ask?" to confirm the session is wired up correctly. If it can't remember, the frontend is not reaching your deployed agent, so recheck the resource name from the earlier step.

## Deploy to Cloud Run
Finally, ship the frontend so anyone can use it.

Note that the frontend that we are shipping deploys differently from the agent. You used agents-cli to deploy the agent to Agent Platform, the frontend is a separate custom web app, so you need to ship that to Cloud Run with gcloud. Essentially, the agent lives in Agent Platform while the frontend lives in Cloud Run and talks to the agent. This is the recommended pattern for a custom UI.

The Cloud Run service runs as a different service identity than you did locally, so its service account needs roles/aiplatform.user or /chat will error out.

```bash
Deploy the frontend to Cloud Run pointing at my AGENT_ENGINE_RESOURCE_NAME and AGENT_DIRECTORY, and grant the Cloud Run service account roles/aiplatform.user so it can reach the agent.
```

Or run it directly:

```bash
gcloud run deploy <your-frontend-name> \
  --source . \
  --region <your-region> \
  --allow-unauthenticated \
  --set-env-vars="AGENT_ENGINE_RESOURCE_NAME=$AGENT_ENGINE_RESOURCE_NAME,AGENT_DIRECTORY=$AGENT_DIRECTORY"
```

Open the Cloud Run URL and chat with your deployed agent. That's the full loop: agent on Agent Platform, frontend on Cloud Run, talking to each other.

# Customize Your Frontend

Your whole UI lives in one file, `frontend/static/index.html`: a chat page with a title, a header, and an accent color. Ask AGY to restyle it. A few things to try:

```
Rebrand my frontend: set the title and header to my app's name and change the accent color.
```

```
Add a row of 3 clickable example prompts above the input, tailored to my agent (look at my project_brief.md).
```

```
Create a nice dialogue layout for my app that matches my theme.
```

```
Suggest some UI improvements we can make to the frontend.
```

![](images/updated-layout-frontend.png)

# Stretch Goals

You've built the full loop. To take it further, pick from the stretch menu in your project_brief.md. A few ideas:

- Video previews with Omni: generate a short video clip instead of a still image.
- More tools, richer A2UI cards, or session memory that remembers a returning user.
- Keep customizing the frontend to match your brand.

To try video generation:

```
Add a tool that generates a short video for an item in my agent's domain (look at my project_brief.md) using Google's Omni model (gemini-omni-flash-preview) in the global region. Save the video as an artifact. Use the Developer Knowledge MCP to confirm the API.
```

# Share What You Built

You've gone from an empty folder to a deployed, agent-first application. The last step is the fun one: capture it and show it off. Your repo ships a **`record-demo`** skill that films your agent in action and produces a polished, branded video clip — perfect for a tweet, a Slack message, or the top of a README.

## Record a demo clip

The `record-demo` skill drives your chat UI in a headless browser: it opens the page, types real prompts, waits for each reply, and saves a short **`.webm`** with a "Gemini World Tour" frame around it. It works against either face of your agent — your custom frontend (`localhost:8080`) or the Playground.

First, make sure the UI you want to film is running (your frontend from the last section, or the Playground). Then tell AGY what to show off — pick 2–3 prompts that exercise your agent's best features (a tool call, a Firestore lookup, a generated image, an A2UI card):

```
Record a demo video of my agent. Show it doing the thing my app does best, then ask a second, richer prompt that shows off a tool call, a database lookup, or a generated image.
```

For example, a store agent might use: *"Record a demo of my agent. Ask it what's in stock, then ask it to generate a picture of the first item."* A great clip is short and snappy — **2–3 turns, roughly 20–40 seconds**.

> **Add a soundtrack (optional).** The recorder can score your clip with AI-generated instrumental music using Google's Lyria model, matched to the video's length. Just describe the vibe:
> ```
> Record a demo of my agent and add some upbeat lo-fi background music.
> ```

If you'd rather run it yourself, call the recorder directly from your project root (bump `--wait` to `30000`+ for turns that generate an image or video):

```bash
node .agents/skills/record-demo/record-agent.js \
  -q "First demo prompt" \
  -q "Second demo prompt" \
  -o agent_demo.webm
```

On success it prints `SUCCESS: Recording saved to <path>`, leaving a branded `.webm` in your project — ready to share.

## Turn it into a shareable README

A demo is even better with a landing page. Ask AGY to generate a README that tells the story of your app and shows the clip you just recorded — as a **GIF**, which is the no-fuss way to get a demo playing in a README:

```
Generate a README.md for my project that describes what my agent does (use my project_brief.md) and lists its key features and the Google Cloud tools it uses (Memory Bank, Firestore, Cloud Storage, RAG, image generation, A2UI). Convert my demo recording to an optimized, looping GIF and embed it near the top with a relative path so it plays inline.
```

Why a GIF? Committed alongside your code and referenced with a plain relative path (`![demo](demo.gif)`), it renders and loops automatically on GitHub — no uploads, no special links. Keep the original `.webm` as your high-quality **social asset**: X, LinkedIn, and Slack all play an uploaded video natively.

> **Prefer a real video player in the README?** GitHub only renders an inline player for videos uploaded through its web editor (`.webm` committed to the repo and linked by path stays a download link). If you want the player rather than a GIF, drag the `.webm` into the README on github.com and it inserts a working embed.

Now your repo has a proper front door: a clear description, a feature list, and a looping demo of your agent in action — the perfect thing to link when someone asks *"what did you build?"*

# Publish to GitHub & Submit for Swag

Everything you've built so far lives in this workstation, and the workstation is temporary. When the lab ends, it goes away, and your code with it. So the last step is to push your project to **your own personal GitHub** so you keep it, can share it, and can submit it for **swag** (a crewneck) and a shot at the **Build with Gemini** project gallery.

This uses the `publish-to-github` skill, which creates a repo on *your* GitHub account and pushes your project to it. Tell AGY:

```
Publish my project to GitHub and submit it for swag.
```

What happens, and where you stay in control:

1. **You sign in to your own GitHub.** AGY runs the GitHub CLI, which prints a **one-time code** and the URL [github.com/login/device](https://github.com/login/device). Open that on *any* device (your laptop or phone), sign in to **your personal GitHub**, and enter the code. This keeps your GitHub identity separate from the lab's Google Cloud credentials.

   > **Note:** sign in with *your own* GitHub account, not the Qwiklabs lab account. The repo lands on your personal profile so it's yours to keep after the lab.

2. **AGY asks before it pushes.** Before creating the repo or pushing anything, AGY confirms the repo name and shows you what it's about to do. **Nothing is pushed to your account without your say-so.** Don't blindly approve; check the repo name and that it's your account first.

3. **Your repo goes public.** The repo is created **public** so it can be featured in the gallery and shared on social. AGY writes a `.gitignore` and scans for secrets before committing, so credentials don't get pushed.

When it's done, AGY prints your new repo's URL and a **pre-filled submission form** with your repo link already filled in. Open it, add the details only you know (your registration name/email, whether you've claimed your GDP badge, and whether you consent to be featured), and submit:

- **Everyone who submits** is eligible for the swag (crewneck) and GDP badge redemption.
- **Standout projects** get hand-picked by the team and featured (with a link to your repo) in the **Build with Gemini track 3 GitHub gallery**.

Congratulations! You've designed, built, equipped, evaluated, deployed, shared, *and* published a complete agentic application.
