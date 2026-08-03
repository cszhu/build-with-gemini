#!/usr/bin/env python3
"""Minimal reproducer: RAG retrieval + another function tool on Gemini 2.5.

Proves that exposing retrieval as a PLAIN FUNCTION TOOL (`consult_docs`) coexists
with other function tools across a full two-turn (tool-call + follow-up)
conversation, while ADK's built-in `VertexAiRagRetrieval` 400s on the follow-up
turn.

The conflict is NOT specific to A2UI: it's "built-in retrieval grounding tool +
ANY function declaration". So this uses a trivial dummy function tool
(`other_tool`) to stand in for the A2UI toolset — same trigger, fewer deps.

Run it:
    pip install google-adk vertexai
    gcloud auth application-default login          # ADC
    export GOOGLE_GENAI_USE_VERTEXAI=1
    export GOOGLE_CLOUD_PROJECT=your-project-id
    export GOOGLE_CLOUD_LOCATION=global            # where the MODEL runs
    export RAG_CORPUS=projects/.../locations/us-central1/ragCorpora/NNN
    # optional: export CORPUS_REGION=us-central1   # inferred from RAG_CORPUS if omitted
    python test_rag_a2ui_compat.py                 # runs the GOOD (function-tool) path
    RUN_BROKEN=1 python test_rag_a2ui_compat.py    # ALSO runs the broken path to see the 400

Exit code 0 = the good path completed a follow-up turn without a 400.
"""

import asyncio
import os
import sys

MODEL = os.environ.get("MODEL", "gemini-2.5-flash")
PROJECT = os.environ.get("GOOGLE_CLOUD_PROJECT")
RAG_CORPUS = os.environ.get("RAG_CORPUS")


def _corpus_region(corpus_name: str) -> str:
    # projects/<p>/locations/<region>/ragCorpora/<id>
    parts = corpus_name.split("/")
    if "locations" in parts:
        return parts[parts.index("locations") + 1]
    return os.environ.get("CORPUS_REGION", "us-central1")


def _preflight() -> None:
    missing = [
        k
        for k, v in {"GOOGLE_CLOUD_PROJECT": PROJECT, "RAG_CORPUS": RAG_CORPUS}.items()
        if not v
    ]
    if missing:
        sys.exit(f"Set these env vars first: {', '.join(missing)} (see the docstring).")


# ---- tools -----------------------------------------------------------------


def consult_docs(query: str) -> str:
    """Search the knowledge base and return matched passages.

    Args:
        query: What to look up.
    Returns:
        The matched passages, or a note that none was found.
    """
    from vertexai.preview import rag

    try:
        resp = rag.retrieval_query(
            text=query,
            rag_resources=[rag.RagResource(rag_corpus=RAG_CORPUS)],
            rag_retrieval_config=rag.RagRetrievalConfig(top_k=5),
        )
    except Exception as e:  # noqa: BLE001 - surface as tool result, don't crash the turn
        print(
            f"  [tool] consult_docs retrieval error: {type(e).__name__}: {str(e)[:200]}"
        )
        return f"Retrieval failed: {e}"
    contexts = getattr(resp.contexts, "contexts", [])
    passages = [c.text.strip() for c in contexts if getattr(c, "text", "").strip()]
    return "\n\n---\n\n".join(passages) or "No relevant passage found."


def other_tool(note: str) -> str:
    """Record a short note for the user. Stand-in for the A2UI toolset — its only
    job is to add ANOTHER function declaration to the request AND actually get
    called, so the follow-up turn carries a functionResponse (the 400 trigger).

    Args:
        note: Anything to jot down.
    Returns:
        Confirmation string.
    """
    print("  [tool] other_tool called")
    return f"noted: {note}"


# ---- runner ----------------------------------------------------------------


async def _drive(agent, label: str) -> bool:
    """Run one two-turn conversation. Returns True if it completed without error."""
    from google.adk.runners import Runner
    from google.adk.sessions import InMemorySessionService
    from google.genai import types

    svc = InMemorySessionService()
    app, uid, sid = "ragtest", "u1", f"s-{label}"
    await svc.create_session(app_name=app, user_id=uid, session_id=sid)
    runner = Runner(agent=agent, app_name=app, session_service=svc)

    # This prompt forces a retrieval tool call; ADK auto-runs the tool and sends
    # the functionResponse back -> that follow-up turn is where the 400 fires.
    msg = types.Content(
        role="user",
        parts=[
            types.Part(
                text=(
                    "Do these steps in order: (1) call other_tool to log the note "
                    "'user asked about coughs'; (2) then use your document/retrieval tool "
                    "to look up what is good for a cough; (3) then give a one-sentence "
                    "answer. You MUST call other_tool first."
                )
            )
        ],
    )
    try:
        async for event in runner.run_async(
            user_id=uid, session_id=sid, new_message=msg
        ):
            if event.is_final_response() and event.content and event.content.parts:
                final = "".join(p.text or "" for p in event.content.parts)
                print(f"  [{label}] final: {final[:200]}")
        return True
    except Exception as e:  # noqa: BLE001
        print(
            f"  [{label}] FAILED on follow-up turn: {type(e).__name__}: {str(e)[:300]}"
        )
        return False


def _good_agent():
    from google.adk.agents import Agent

    return Agent(
        model=MODEL,
        name="good",
        instruction="Answer using your tools. Call consult_docs before answering.",
        tools=[consult_docs, other_tool],
    )


def _broken_agent():
    from google.adk.agents import Agent
    from google.adk.tools.retrieval import VertexAiRagRetrieval
    from vertexai.preview import rag

    rag_tool = VertexAiRagRetrieval(
        name="retrieve_docs",
        description="Search the corpus for relevant passages.",
        rag_resources=[rag.RagResource(rag_corpus=RAG_CORPUS)],
        similarity_top_k=5,
        vector_distance_threshold=0.5,
    )
    return Agent(
        model=MODEL,
        name="broken",
        instruction="Answer using your tools. Call retrieve_docs before answering.",
        tools=[rag_tool, other_tool],
    )


async def main() -> int:
    _preflight()
    import vertexai

    region = _corpus_region(RAG_CORPUS)
    vertexai.init(project=PROJECT, location=region)  # pin RAG client to corpus region
    print(f"model={MODEL}  corpus_region={region}  corpus={RAG_CORPUS}")

    print("\n== GOOD: consult_docs (plain function tool) + other_tool ==")
    good_ok = await _drive(_good_agent(), "good")
    print(f"  => {'PASS' if good_ok else 'FAIL'}")

    broken_ok = None
    if os.environ.get("RUN_BROKEN") == "1":
        print("\n== BROKEN: VertexAiRagRetrieval (built-in tool) + other_tool ==")
        broken_ok = await _drive(_broken_agent(), "broken")
        print(
            f"  => {'unexpectedly PASSED' if broken_ok else 'FAILED as expected (400)'}"
        )

    print("\n--- verdict ---")
    print(f"good path completed follow-up turn: {good_ok}")
    if broken_ok is not None:
        print(f"broken path completed follow-up turn: {broken_ok} (expected False)")
    return 0 if good_ok else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
