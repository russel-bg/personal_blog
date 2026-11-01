---
title: "Formal Verification for Beginners: TLA+, Alloy, Dafny and UPPAAL"
date: 2026-10-31
draft: false
description: "An introduction to formal modeling and verification: why specifications matter, how model checking works, and which tools to start with — TLA+, Alloy, Dafny, UPPAAL."
author: "bio"
tags: ["formal verification", "TLA+", "Alloy", "Dafny", "UPPAAL", "software engineering"]
---

## Why would anyone prove programs correct?

Almost everything we know about software quality is empirical: tests, code review, monitoring. Tests answer the question "does the program fail on these examples?" — but not "does it fail at all?". Formal verification is a way to **prove mathematically** that a system satisfies given properties: "two replicas of a database never hold different values for the same key", "the elevator never moves with its doors open", "a sorting function always returns a permutation of its input".

If this sounds like academic exotica, look at the practice: Amazon has used TLA+ for years to check the replication protocols behind DynamoDB and S3 — Leslie Lamport keeps a collection of industrial use cases at https://lamport.azurewebsites.net/tla/industrial-use.html. Microsoft verified whole OS components with machine-checked proofs (https://www.usenix.org/conference/osdi14/technical-sessions/presentation/hawblitzel), security researchers keep finding exploitable bugs that a trivial invariant would have caught, and Anthropic is actively researching how LLMs can help generate formal proofs (https://www.anthropic.com/research/formal-verification). A bug found in a model in an hour is always cheaper than the same bug found in production after a week-long incident.

The key idea: **a model is simpler than the program**. We don't verify millions of lines of implementation — we describe the essence of a protocol or an algorithm in a few dozen lines of specification and check properties of *that*. A bug found in a model almost always means a bug in the design, and design bugs are the most expensive ones: they survive every rewrite and every refactor.

There is also a second, less obvious payoff. Writing a specification forces you to answer questions your design document silently skipped. What happens if a message arrives twice? What if a node crashes between steps A and B? What does "eventually consistent" mean, precisely, in terms of what a client can observe? The act of specification is where most of the learning happens — the machine-checked proof is the bonus.

## Three levels of rigor

It helps to sort the approaches by how much machinery they bring:

1. **Model checking** — you describe the system as a finite state machine and the properties as temporal logic formulas; the tool explores every reachable state and looks for violations. This is how TLA+ and UPPAAL work.
2. **First-order logic + SAT/SMT** — you describe *structures* (entities and relations) and ask the tool to find a counterexample. This is how Alloy works.
3. **Verified programming** — you write ordinary code, but together with annotations (preconditions, postconditions, loop invariants) that an SMT solver proves automatically. This is how Dafny works.

None of these replaces testing; they complement it. Tests check the implementation against examples; verification checks the design against all cases. Let's look at each family through a concrete tool.

## TLA+: specifications for distributed systems

TLA+ (Temporal Logic of Actions) was created by Leslie Lamport — the same person behind LaTeX and the Paxos algorithm. It is a language for describing **concurrent and distributed systems**: steps, messages, failures, reorderings of events.

A minimal specification of "two processes increment a counter" looks like this:

```tla
EXTENDS Integers

VARIABLES pc, x
vars == <<pc, x>>

Init == /\ pc = [p \in {0,1} |-> "a"]
        /\ x  = 0

Increment(p) == /\ pc[p] = "a"
                 /\ pc'   = [pc EXCEPT ![p] = "b"]
                 /\ x'    = x + 1

Next == \E p \in {0,1}: Increment(p)

Spec == Init /\ [][Next]_vars

Invariant == x <= 2
```

TLC — the model checker that ships with TLA+ — enumerates all interleavings of the two processes' steps and checks the invariant. Now replace the atomic `x' = x + 1` with the classic non-atomic read-modify-write, and TLC will instantly find an interleaving in which `x = 1` instead of `2`. That is exactly what a **data race** looks like — and in a specification you can see it in minutes rather than after a flaky integration test at 3 a.m.

For imperative thinkers there is PlusCal, an algorithm language that translates into TLA+, so you can write pseudocode and still get full model checking. The best practical course is Learn TLA+ by Hillel Wayne: https://learntla.com/core/index.html. The tool itself lives at https://github.com/tlaplus/tlaplus. Two excellent write-ups of real bugs found through TLA models are worth your time: https://medium.com/@polyglot_factotum/modelling-a-message-passing-bug-with-tla-baaf090a688d, and there is a thought-provoking piece on using TLA+ together with AI code generation: https://medium.com/@polyglot_factotum/tla-in-support-of-ai-code-generation-9086fc9715c4.

When is TLA+ worth the effort? Whenever the hard part of your system is *concurrency and protocols*: replication, consensus, leader election, queues with at-least-once delivery, caches with invalidation. If the hard part is structure and data invariants, keep reading — Alloy is probably your tool.

## Alloy: model the structure, hunt for counterexamples

Where TLA+ is strong on time and behavior, Alloy is strong on **structure**: entity hierarchies, data invariants, architectural constraints. Alloy is a first-order relational logic, and the Alloy Analyzer reduces the search for counterexamples to a SAT problem — within seconds it either shows you a counterexample as a diagram, or guarantees that none exists within the given scope.

Here is a small access-control model:

```alloy
abstract sig User {}
sig Admin, Guest extends User

sig File {
  owner: one User,
  readers: set User
}

fact {
  all f: File | f.owner in f.readers
  all f: File | Guest in f.readers implies
                f.owner not in Guest
}

assert noOrphanFiles {
  all f: File | some f.owner
}

check noOrphanFiles for 5
```

The `check` asks the analyzer to find a file without an owner among all configurations of up to 5 users and 5 files. If a counterexample exists in that space, you'll see it drawn as a diagram of concrete objects and relations.

Alloy probably has the lowest entry barrier of all verification tools. Official site: https://alloytools.org/, documentation: https://alloy.readthedocs.io/en/latest/, and the best tutorial is Practical Alloy: https://practicalalloy.github.io/chapters/structural-modeling/index.html. The foundational book is "Software Abstractions" by Daniel Jackson (https://mitpress.mit.edu/9780262101141/), and there is a thorough hands-on article in Russian on Habr: https://habr.com/ru/companies/typeable/articles/546356/. Alloy deserves a post of its own — and will get one.

## Dafny: code that proves its own correctness

Dafny is a verification-aware programming language from Microsoft Research (https://github.com/dafny-lang/dafny). You write a program in a C#- or Python-flavored syntax and add contracts:

```dafny
method BinarySearch(a: array<int>, key: int) returns (index: int)
  requires a.Length > 0 && forall i, j | 0 <= i <= j < a.Length :: a[i] <= a[j]
  ensures 0 <= index < a.Length ==> a[index] == key
  ensures index == -1 ==> forall i | 0 <= i < a.Length :: a[i] != key
{
  var lo, hi := 0, a.Length - 1;
  while lo <= hi
    invariant 0 <= lo && hi < a.Length + 1
    invariant forall i | 0 <= i < lo :: a[i] < key
    invariant forall i | hi < i < a.Length :: a[i] > key
    decreases a.Length - lo
  {
    var mid := (lo + hi) / 2;
    if a[mid] < key { lo := mid + 1; }
    else if a[mid] > key { hi := mid - 1; }
    else { return mid; }
  }
  return -1;
}
```

If you forget a loop invariant or get a boundary wrong, Dafny refuses to compile the method and tells you which proof obligation failed. Behind the scenes, Boogie translates your program into verification conditions and the Z3 SMT solver discharges them. This is no longer "a model of the system" — this is verification of **real code**, which is why Dafny is used where the cost of bugs is highest: cryptographic libraries, compilers, runtime components, and safety-critical tooling. Lamport's book "Program Proofs" (https://mitpress.mit.edu/9780262546232/) is an excellent entry into this style of thinking, and the Amazon Science write-up shows how such proofs can be folded into a normal development workflow (https://www.amazon.science/blog/how-to-integrate-formal-proofs-into-software-development).

The mental shift with Dafny is subtle but profound: types and tests tell you what the program *does* on the cases you tried; contracts tell the compiler what the program *means* on all possible inputs — and make it check that your implementation keeps that promise.

## UPPAAL: when timing is part of correctness

UPPAAL (https://uppaal.org/) models **real-time systems** — systems whose correctness depends on timing. Models are timed automata: finite-state machines extended with clocks, guarded transitions (`x <= 5`), and synchronization channels. Classic applications: media access protocols, scheduling with deadlines, embedded controllers where "the door opens after the train stops" must hold not just logically but within milliseconds of budget. UPPAAL's GUI makes it the most visual way to explain model checking to a student: you literally watch the states light up as the checker explores the space, and when a property fails, you get a concrete timed trace you can replay.

If your system has no notion of physical time, UPPAAL is overkill; if it does — there is really nothing else in the same convenience class.

## Where to start

My recommended path for a beginner:

1. Read the legendary "Formal verification: Casually Explained" post (https://medium.com/@ahelwer/formal-verification-casually-explained-3fb4fef2e69a, extended version: https://ahelwer.ca/post/2018-02-12-formal-verification/) — the best twenty-minute explanation of the *why*.
2. Work through the first chapters of Learn TLA+ (https://learntla.com/core/index.html) — write your first specification in an evening.
3. Play with Alloy using Practical Alloy — the feeling of "architecture as an executable artifact" arrives by chapter two.
4. Keep awesome-formal-verification (https://github.com/elniak/awesome-formal-verification) bookmarked — it catalogs tools for every stack, from Coq and Lean to verified compilers.

One more trend worth watching, and it sits at the intersection of everything this blog covers: **LLMs plus formal verification**. Language models are bad at reasoning about concurrency out of the box, but they are excellent at drafting specifications; a verifier provides a strict "proved / not proved" signal, which is a perfect reward channel for a model. Draft the spec with an LLM, check it with TLC or Alloy, iterate on the counterexamples, and only then generate the implementation. Formal methods stop being niche magic and become one more layer of the test pyramid — except this layer checks *all* cases, not just the ones you thought of.

## Toolbox at a glance

Before you pick a first tool, here is the whole family on one screen:

| Tool | Paradigm | Sweet spot | First step |
|---|---|---|---|
| TLA+ / TLC | model checking of state machines | distributed protocols, replication, retries | Learn TLA+ chapters 1–2 |
| Alloy | first-order relational logic + SAT | data invariants, structural design | Practical Alloy, chapter 1 |
| Dafny | verified programming with SMT | algorithms with contracts, crypto, parsers | "Program Proofs", part I |
| UPPAAL | timed automata | real-time and embedded systems | the shipped demo models |
| Coq / Lean | proof assistants | compilers, math-level guarantees | skip until you need them |

Two readings of the table are worth stating out loud. Vertically: the further down, the more expressive the tool and the more expensive each unit of guarantee — start as high as your problem allows. Horizontally: each tool answers a different *question* about the same system, and mature teams eventually keep two of them — one for protocols (TLA+), one for structure or code (Alloy or Dafny) — because the questions barely overlap.

The asterisk on Coq and Lean is deliberate. Fully machine-checked proofs are the strongest guarantee in software engineering, and the recent progress on LLM-assisted proving makes them dramatically cheaper than five years ago — but the learning curve is measured in months, not evenings. Everything in this post was chosen so that the first result arrives in hours. Momentum matters more than rigor ceiling when you are changing how a team thinks.

## What exactly should you verify?


Beginners often stall at the question "what properties do I even write down?" A useful taxonomy comes from temporal logic, and it transfers directly to TLA+ and Alloy 6:

- **Safety properties** — "nothing bad ever happens". No two users hold write access to the same row; the balance never goes negative; a deleted account can never log in. Safety violations have finite counterexamples, which is exactly what model checkers are good at finding.
- **Liveness properties** — "something good eventually happens". Every submitted job eventually completes; every lock that is taken is eventually released. Liveness is where deadlocks and starvation live, and where specification pays the most, because tests almost never run long enough to catch starvation.

A good exercise for any system you maintain: write down its safety properties in a notebook, then its liveness properties. Most teams discover that they can state three safety properties easily, one or two with effort — and that the third category, "properties we *wish* held but would never dare claim", is where the real risks hide. The gap between what you can state and what you can claim is a map of your system's unverified surface.

There is also a pragmatic rule for choosing what to verify first: verify the **protocol**, not the plumbing. The value of a specification is highest where the logic is concurrent, stateful, and hard to test exhaustively — replication, caching, retry and idempotency logic, permission checks. Nobody writes formal models of HTML rendering, and nobody should.

## Common beginner mistakes

Three failure modes account for most abandoned first attempts. First, **modeling too much**: trying to capture the entire system instead of the one protocol that keeps you up at night. A 200-line TLA+ model of a message queue teaches you more than a 2000-line model of "the architecture". Second, **confusing facts with properties** (in Alloy) or invariants with behaviors (in TLA+): if a check always passes, the first hypothesis is that you accidentally *assumed* the property rather than testing it. Deliberately break the system in the model and confirm the checker screams — a verification setup with no observed failure is untrusted. Third, **mistrusting the tool's silence**: "TLC found nothing" does not mean "the system is correct", it means "the system is correct within this model and this scope". Keeping that caveat visible is what separates engineers who use formal methods from those who worship them.

None of these are arguments against the practice — they are the ordinary learning curve of a tool that changes how you think. The teams that get value from TLA+ and friends are not the ones with verification PhDs; they are the ones that kept the models small, the properties sharp, and the counterexamples explained in plain words.

If this post gets you to write a single Alloy model and find a counterexample in it, it has done its job.

