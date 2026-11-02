---
name: fpga-audio-reproduce
description: Reproduce and inspect Vivado RTL streaming-audio projects with optional host-side recognition and display feedback. Use for build/report checks and evidence-based board acceptance; adapt the target part, clocks and pin map before applying to a different board.
---

# FPGA audio reproduction

Identify the requested mode and the actual implementation boundary: RTL/PL, HLS, PS application, or host software. Do not invent unused components or move a host algorithm into claims of standalone FPGA execution.

- For build reproduction and evidence handoff, read [workflow.md](references/workflow.md). Prefer relative paths and regenerate vendor IP from configuration; keep generated projects and licensed tool installations outside the source package.
- For resource/timing checks, use [check_reports.py](scripts/check_reports.py) with a project-specific JSON configuration. Report setup and hold separately, together with budgets and unconstrained endpoints. Missing evidence is a failed check, not a zero.
- For board, display, stream or identity failures, read the relevant entry in [pitfalls.md](references/pitfalls.md). Inspect the part, image identity and current session before changing logic. A working JTAG downloader does not establish a working board connection.
- For a new project, adapt [prompts.md](references/prompts.md) and [acceptance-template.json](assets/acceptance-template.json). Keep captured-sample progress separate from wall-clock progress when validating identity tracking.

Separate simulation, saved-recording replay, live serial evidence and physical observation. A returned display ACK establishes receipt, not the visual correctness of the screen or LED ring. Acquisition success does not establish title stability or a completed endurance test. Preserve failed observations and mark the affected acceptance item pending.

Use the user's stated task scope for hardware actions. Reproduction and packaging do not require opening a serial port, downloading an image, uploading audio or changing Flash. When board operation is requested, verify the actual target and use the project's explicit volatile-programming entrypoint; do not infer Flash programming from a request to run a test.
