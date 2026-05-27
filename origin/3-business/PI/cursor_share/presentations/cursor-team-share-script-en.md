# Speaking Script (English) — ~10 minutes

> **Title**: From IE Engine to Zero Engine — How I broke down and drove the migration task  
> **Focus**: start with context, then problem-solving steps  
> **Slides**: [`cursor-team-share-outline.md`](cursor-team-share-outline.md)  
> **Vocabulary**: plain English

---

## [0:00–1:20] Opening + 6 quick context lines

Hi everyone. This is not a deep troubleshooting talk. It is about how I handled a migration task from start to finish.

Before the cases, I use six quick lines so everyone is on the same page:

1. PI is our product platform; this task is on its installer build chain.  
2. IE Engine is the old engine capability already inside the installer flow.  
3. Zero Engine is the replacement we want to ship in the installer.  
4. InstallAnywhere is the current cross-OS installer build tool and the main workspace of this migration.  
5. The core task is IE Engine → Zero Engine migration in `taf-core-installer`, with build validation.  
6. So today I focus on solving steps, not low-level fix details.  

---

## [1:20–2:00] My 4-step problem-solving path

I broke the whole task into four steps:

1. Extract installer-related logic from `refactor-pi` and create a dedicated `pi-installer` workspace.  
2. Map the current state: touchpoints, packaging flow, evidence, and validation path.  
3. Execute by phases:  
   - Phase 1: remove old IE Engine content and validate build.  
   - Phase 2: package Zero Engine and validate.  
4. In parallel, research whether we can replace InstallAnywhere for multi-OS packaging in the future.  

The next three cases are checkpoints on this path.

---

## [2:00–3:40] Case #2 (Step 2): read first, then verify hypothesis

The scene: `pom.xml` says JRE 21, but package output is 11.

My approach is not “AI, fix it now.” I do this first:

1. Read build logs myself first.  
2. Form a hypothesis with evidence.  
3. Ask AI to prove or disprove with exact log lines.  
4. Approve edits only after validation.  

What I want the audience to remember: **AI is my fast checker, not my starting point.**

---

## [3:40–5:20] Case #5 (Step 3 / Phase 1): big XML, small safe steps

This case is from IE removal. I was new to InstallAnywhere and the XML was huge.

My rule in this kind of work:

1. Let AI do heavy edits.  
2. Assume mistakes are possible.  
3. Use build/parse failures as feedback signals.  
4. Narrow scope and validate in small steps.  
5. Write lessons into docs for next time.  

The point is not XML tricks. The point is: **process must catch errors**.

---

## [5:20–7:00] Case #10 (Step 3 / Phase 2): strong contrast, Plan first

The scene: build is green, install UI is green, but no `ZESvc`.

When contrast is strong, my sequence is:

1. Align facts from build and install logs first.  
2. Do not jump into root-cause lecture in the sharing.  
3. Switch to Plan mode: compare options, tradeoffs, and constraints.  
4. I choose; Agent executes; I own final validation.  

This is the pattern: **agent → plan → agent**.

---

## [7:00–8:20] Reusable method + boundaries

I keep four prompt habits:

1. Logs + my hypothesis first; ask for verification before edits.  
2. Absolute path + scoped edits only.  
3. If multiple options exist, compare first in Plan mode.  
4. After execution, separate AI-verified checks and my required checks.  

Boundaries stay with me: product scope, permissions, and final sign-off.

---

## [8:20–9:20] Productivity note + long-term direction + close

One honest scale from this project:

- Manual SI-related removal in `taf-core-installer` (without full sign-off): around 4 person-days.  
- Similar edit scope with Cursor: around 30 minutes.  
- Validation is still mine; target is around one person-day total verification effort.  

Long-term: first stabilize IE→ZE delivery; then research replacing InstallAnywhere for multi-OS packaging.

Three closing lines:

1. The title is IE→ZE, but the core sharing is how I solve migration tasks.  
2. Three cases map to three patterns: hypothesis check, small-step validation, and Plan-first selection.  
3. The reusable part is the method, not a specific command.

Thanks, happy to take questions.

---

## Q&A backup

| Question | Short answer |
|----------|----------------|
| Why explain terms first? | Not everyone knows PI/IE/ZE/InstallAnywhere; context first makes the method clear. |
| Why 4-step path? | It turns a complex migration into something trackable and verifiable. |
| What if AI breaks XML? | Small steps, parse/build feedback, and write lessons down. |
| Why keep human validation? | Installer delivery quality is still a human sign-off boundary. |
