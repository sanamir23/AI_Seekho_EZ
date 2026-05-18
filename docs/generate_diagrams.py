"""Generate agent-graph and backend-architecture PNGs using pure matplotlib."""
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch
import matplotlib.patheffects as pe

# ── colour palette ──────────────────────────────────────────────────────────
C = {
    "llm":    "#7C3AED",   # purple  – LLM calls
    "tool":   "#0EA5E9",   # sky     – tool / ToolNode
    "db":     "#059669",   # emerald – DB / Supabase
    "sched":  "#D97706",   # amber   – APScheduler
    "ctrl":   "#DC2626",   # red     – clarifier / give-up
    "io":     "#1D4ED8",   # blue    – start / end / HTTP
    "plain":  "#374151",   # gray    – plain nodes
    "bg":     "#F9FAFB",
    "edge":   "#6B7280",
    "white":  "#FFFFFF",
}


# ════════════════════════════════════════════════════════════════════════════
# Helper – draw a rounded box with centred text
# ════════════════════════════════════════════════════════════════════════════
def box(ax, x, y, w, h, label, sublabel=None, color=C["plain"],
        fontsize=9, text_color="white", alpha=1.0, zorder=3):
    rect = FancyBboxPatch((x - w/2, y - h/2), w, h,
                           boxstyle="round,pad=0.04",
                           linewidth=1.4,
                           edgecolor="white",
                           facecolor=color,
                           alpha=alpha,
                           zorder=zorder)
    ax.add_patch(rect)
    if sublabel:
        ax.text(x, y + 0.08, label, ha="center", va="center",
                fontsize=fontsize, fontweight="bold",
                color=text_color, zorder=zorder+1)
        ax.text(x, y - 0.14, sublabel, ha="center", va="center",
                fontsize=fontsize - 1.5,
                color=text_color, alpha=0.85, zorder=zorder+1)
    else:
        ax.text(x, y, label, ha="center", va="center",
                fontsize=fontsize, fontweight="bold",
                color=text_color, zorder=zorder+1)
    return (x, y)


def arrow(ax, x0, y0, x1, y1, label="", color=C["edge"],
          style="arc3,rad=0", lw=1.4, zorder=2):
    ax.annotate("",
                xy=(x1, y1), xytext=(x0, y0),
                arrowprops=dict(arrowstyle="-|>",
                                color=color,
                                lw=lw,
                                connectionstyle=style),
                zorder=zorder)
    if label:
        mx, my = (x0+x1)/2, (y0+y1)/2
        ax.text(mx + 0.04, my, label, fontsize=7.5,
                color=color, va="center", zorder=zorder+1,
                bbox=dict(fc=C["bg"], ec="none", pad=1))


# ════════════════════════════════════════════════════════════════════════════
# DIAGRAM 1 – Agent execution graph
# ════════════════════════════════════════════════════════════════════════════
def draw_agent_graph():
    fig, ax = plt.subplots(figsize=(13, 17))
    fig.patch.set_facecolor(C["bg"])
    ax.set_facecolor(C["bg"])
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 17)
    ax.axis("off")
    ax.set_aspect("equal")

    fig.suptitle("Agent Execution Graph", fontsize=16, fontweight="bold",
                 color=C["plain"], y=0.97)

    W, H = 2.6, 0.55   # default box size

    # ── nodes (x, y) ────────────────────────────────────────────────────────
    nodes = {
        "START":            (5,    16.2),
        "intent_parser":    (5,    15.0),
        "provider_caller":  (5,    13.2),
        "tool_executor":    (5,    11.8),
        "ranking":          (5,    10.4),
        "decision":         (5,     9.0),
        "booking_step":     (5,     7.6),
        "followup_step":    (5,     6.2),
        "END_happy":        (5,     4.8),
        "clarifier":        (8.2,  12.5),
        "give_up":          (8.2,   9.5),
        "END_giveup":       (8.2,   8.3),
    }

    colors = {
        "START":            C["io"],
        "intent_parser":    C["llm"],
        "provider_caller":  C["llm"],
        "tool_executor":    C["tool"],
        "ranking":          C["tool"],
        "decision":         C["llm"],
        "booking_step":     C["db"],
        "followup_step":    C["sched"],
        "END_happy":        C["io"],
        "clarifier":        C["ctrl"],
        "give_up":          C["ctrl"],
        "END_giveup":       C["io"],
    }

    labels = {
        "START":            "START",
        "intent_parser":    "intent_parser",
        "provider_caller":  "provider_caller",
        "tool_executor":    "tool_executor  ← ToolNode",
        "ranking":          "ranking",
        "decision":         "decision",
        "booking_step":     "booking_step",
        "followup_step":    "followup_step",
        "END_happy":        "END",
        "clarifier":        "clarifier",
        "give_up":          "give_up",
        "END_giveup":       "END",
    }

    sublabels = {
        "intent_parser":    "Gemini · structured output",
        "provider_caller":  "Gemini · bind_tools([find_providers])",
        "tool_executor":    "executes find_providers via ToolNode",
        "ranking":          "rank_providers.invoke() · pure Python",
        "decision":         "Gemini · picks top + reasoning",
        "booking_step":     "insert_agent_trace + insert_booking",
        "followup_step":    "insert_notification + APScheduler job",
        "clarifier":        "Gemini · ask question · interrupt()",
        "give_up":          "status = abandoned",
    }

    for key, (x, y) in nodes.items():
        w = 3.2 if key in ("tool_executor", "provider_caller") else W
        h = 0.65 if key in sublabels else 0.45
        box(ax, x, y, w, h,
            labels[key],
            sublabels.get(key),
            color=colors[key],
            fontsize=8.5 if key == "tool_executor" else 9)

    # ── happy-path edges (main column) ──────────────────────────────────────
    main = ["START","intent_parser","provider_caller",
            "tool_executor","ranking","decision",
            "booking_step","followup_step","END_happy"]
    for a_, b_ in zip(main, main[1:]):
        ax.annotate("",
                    xy=(nodes[b_][0], nodes[b_][1]+0.33),
                    xytext=(nodes[a_][0], nodes[a_][1]-0.33),
                    arrowprops=dict(arrowstyle="-|>", color=C["edge"], lw=1.6),
                    zorder=2)

    # ── intent_parser → clarifier ───────────────────────────────────────────
    arrow(ax, 6.3, 15.0, 6.9, 13.2,
          "missing / low conf", color=C["ctrl"],
          style="arc3,rad=-0.25")

    # ── tool_executor → clarifier (0 results) ───────────────────────────────
    arrow(ax, 6.3, 11.8, 6.9, 12.2,
          "0 results", color=C["ctrl"],
          style="arc3,rad=0.15")

    # ── clarifier loop back to intent_parser ────────────────────────────────
    ax.annotate("",
                xy=(6.3, 14.7),
                xytext=(8.2, 11.75),
                arrowprops=dict(arrowstyle="-|>", color=C["ctrl"], lw=1.4,
                                connectionstyle="arc3,rad=0.35"),
                zorder=2)
    ax.text(8.9, 13.2, "resume +\nclarify_rounds++\n(≤ 2 rounds)",
            fontsize=7.5, color=C["ctrl"], ha="center", va="center")

    # ── clarifier → give_up ─────────────────────────────────────────────────
    arrow(ax, 8.2, 11.17, 8.2, 10.1,
          "rounds > 2", color=C["ctrl"])

    # ── give_up → END ───────────────────────────────────────────────────────
    arrow(ax, 8.2, 9.17, 8.2, 8.6,
          "", color=C["ctrl"])

    # ── interrupt bubble ────────────────────────────────────────────────────
    bub = FancyBboxPatch((6.5, 11.95), 1.5, 0.45,
                          boxstyle="round,pad=0.05",
                          linewidth=1, edgecolor=C["ctrl"],
                          facecolor="#FEE2E2", zorder=3)
    ax.add_patch(bub)
    ax.text(7.25, 12.17, "interrupt() →\nHTTP returns question",
            fontsize=7, color=C["ctrl"], ha="center", va="center", zorder=4)

    # ── legend ──────────────────────────────────────────────────────────────
    legend_items = [
        mpatches.Patch(color=C["llm"],   label="LLM call (Gemini)"),
        mpatches.Patch(color=C["tool"],  label="Tool / ToolNode"),
        mpatches.Patch(color=C["db"],    label="DB write (Supabase)"),
        mpatches.Patch(color=C["sched"], label="APScheduler"),
        mpatches.Patch(color=C["ctrl"],  label="Clarifier / control"),
        mpatches.Patch(color=C["io"],    label="Start / End"),
    ]
    ax.legend(handles=legend_items, loc="lower left",
              fontsize=8, framealpha=0.9,
              bbox_to_anchor=(0.01, 0.01))

    plt.tight_layout()
    out = "docs/agent_graph.png"
    fig.savefig(out, dpi=150, bbox_inches="tight", facecolor=C["bg"])
    plt.close()
    print(f"saved → {out}")


# ════════════════════════════════════════════════════════════════════════════
# DIAGRAM 2 – Backend system architecture
# ════════════════════════════════════════════════════════════════════════════
def draw_backend_arch():
    fig, ax = plt.subplots(figsize=(16, 11))
    fig.patch.set_facecolor(C["bg"])
    ax.set_facecolor(C["bg"])
    ax.set_xlim(0, 16)
    ax.set_ylim(0, 11)
    ax.axis("off")

    fig.suptitle("Backend System Architecture", fontsize=16, fontweight="bold",
                 color=C["plain"], y=0.97)

    # ── group backgrounds ────────────────────────────────────────────────────
    def group_bg(ax, x, y, w, h, label, color):
        rect = FancyBboxPatch((x, y), w, h,
                               boxstyle="round,pad=0.1",
                               linewidth=1.5,
                               edgecolor=color,
                               facecolor=color,
                               alpha=0.08,
                               zorder=1)
        ax.add_patch(rect)
        ax.text(x + 0.15, y + h - 0.18, label,
                fontsize=8, color=color, fontweight="bold",
                va="top", zorder=2)

    group_bg(ax, 0.2, 1.0, 3.4, 9.0,  "Flask UI  :5000",        C["io"])
    group_bg(ax, 4.0, 1.0, 7.8, 9.0,  "FastAPI Backend  :8000", C["plain"])
    group_bg(ax, 12.2, 5.5, 3.4, 4.5, "Supabase",               C["db"])
    group_bg(ax, 12.2, 1.0, 3.4, 4.2, "External APIs",          C["llm"])

    # ── Flask UI ─────────────────────────────────────────────────────────────
    box(ax, 1.9, 8.8, 2.8, 0.5,  "Browser / JS",         color=C["io"],   fontsize=8.5)
    box(ax, 1.9, 7.6, 2.8, 0.5,  "Flask routes",         color=C["io"],   fontsize=8.5)
    box(ax, 1.9, 6.5, 2.8, 0.5,  "Jinja2 templates",     color=C["io"],   fontsize=8.5)
    box(ax, 1.9, 5.4, 2.8, 0.5,  "app.js  (fetch + JWT)",color=C["io"],   fontsize=8.5)

    # ── FastAPI routers ──────────────────────────────────────────────────────
    box(ax, 6.0, 9.2, 2.6, 0.5,  "POST /auth/*",             color=C["plain"], fontsize=8.5)
    box(ax, 6.0, 8.2, 2.6, 0.5,  "POST /service-requests",   color=C["plain"], fontsize=8.5)
    box(ax, 6.0, 7.2, 2.6, 0.5,  "GET /bookings",            color=C["plain"], fontsize=8.5)
    box(ax, 6.0, 6.2, 2.6, 0.5,  "POST /bookings/{id}/cancel",color=C["plain"],fontsize=8.2)

    # ── LangGraph agent ──────────────────────────────────────────────────────
    group_bg(ax, 8.5, 4.8, 2.9, 5.0, "LangGraph agent", C["llm"])
    box(ax, 9.95, 9.2,  2.5, 0.45, "intent_parser",    color=C["llm"],  fontsize=8)
    box(ax, 9.95, 8.4,  2.5, 0.45, "provider_caller",  color=C["llm"],  fontsize=8)
    box(ax, 9.95, 7.6,  2.5, 0.45, "tool_executor",    color=C["tool"], fontsize=8)
    box(ax, 9.95, 6.8,  2.5, 0.45, "ranking",          color=C["tool"], fontsize=8)
    box(ax, 9.95, 6.0,  2.5, 0.45, "decision",         color=C["llm"],  fontsize=8)
    box(ax, 9.95, 5.2,  2.5, 0.45, "booking_step",     color=C["db"],   fontsize=8)

    # ── APScheduler ──────────────────────────────────────────────────────────
    box(ax, 6.0, 4.5, 2.6, 0.7, "APScheduler", "AsyncIOScheduler\n(in-process)",
        color=C["sched"], fontsize=8.5)

    # ── PostgresSaver ────────────────────────────────────────────────────────
    box(ax, 6.0, 3.2, 2.6, 0.6, "PostgresSaver",
        "LangGraph checkpointer", color=C["tool"], fontsize=8.5)

    # ── Supabase group ───────────────────────────────────────────────────────
    box(ax, 13.9, 9.0,  2.6, 0.5,  "Supabase Auth",       color=C["db"],  fontsize=8.2)
    box(ax, 13.9, 7.9,  2.6, 0.8,  "Supabase Postgres",
        "public schema\n(bookings, providers…)", color=C["db"], fontsize=8)
    box(ax, 13.9, 6.6,  2.6, 0.7,  "langgraph schema",
        "checkpoint tables",                     color=C["db"], fontsize=8)

    # ── External APIs ────────────────────────────────────────────────────────
    box(ax, 13.9, 4.5,  2.6, 0.5,  "Google Gemini",       color=C["llm"], fontsize=8.2)
    box(ax, 13.9, 3.3,  2.6, 0.7,  "Google Places API",
        "(seed_providers.py only)",              color=C["llm"], fontsize=8)
    box(ax, 13.9, 2.0,  2.6, 0.5,  "Supabase Auth SDK",   color=C["db"],  fontsize=8.2)

    # ── arrows ───────────────────────────────────────────────────────────────
    # Flask → FastAPI
    arrow(ax, 3.6, 7.6, 4.0, 7.6, "HTTPS + Bearer JWT", color=C["io"])

    # FastAPI → LangGraph
    arrow(ax, 7.3, 8.2, 8.5, 8.5, "invoke() / Command(resume)", color=C["plain"])

    # LangGraph nodes → Gemini
    arrow(ax, 11.2, 8.5, 12.2, 4.75, "", color=C["llm"], style="arc3,rad=0.3")

    # LangGraph → Supabase Postgres
    arrow(ax, 11.2, 6.0, 12.2, 7.9, "", color=C["db"], style="arc3,rad=-0.2")

    # FastAPI auth → Supabase Auth
    arrow(ax, 7.3, 9.2, 12.2, 9.0, "", color=C["db"])

    # FastAPI → PostgresSaver → langgraph schema
    arrow(ax, 7.3, 3.2, 12.2, 6.6, "", color=C["tool"], style="arc3,rad=0.15")

    # APScheduler → Supabase (notifications)
    arrow(ax, 7.3, 4.5, 12.2, 7.6, "", color=C["sched"], style="arc3,rad=0.1")

    # FastAPI → APScheduler
    arrow(ax, 7.3, 6.2, 4.35, 4.8, "add_job / cancel", color=C["sched"],
          style="arc3,rad=0.25")

    # ── legend ───────────────────────────────────────────────────────────────
    legend_items = [
        mpatches.Patch(color=C["io"],    label="Flask UI / HTTP"),
        mpatches.Patch(color=C["plain"], label="FastAPI routers"),
        mpatches.Patch(color=C["llm"],   label="LLM / Gemini"),
        mpatches.Patch(color=C["tool"],  label="ToolNode / checkpointer"),
        mpatches.Patch(color=C["db"],    label="Supabase DB / Auth"),
        mpatches.Patch(color=C["sched"], label="APScheduler"),
    ]
    ax.legend(handles=legend_items, loc="lower left",
              fontsize=8, framealpha=0.9,
              bbox_to_anchor=(0.01, 0.01))

    plt.tight_layout()
    out = "docs/backend_architecture.png"
    fig.savefig(out, dpi=150, bbox_inches="tight", facecolor=C["bg"])
    plt.close()
    print(f"saved → {out}")


if __name__ == "__main__":
    draw_agent_graph()
    draw_backend_arch()
