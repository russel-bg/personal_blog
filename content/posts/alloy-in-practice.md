---
title: "Alloy in Practice: Your First Formal Model in One Evening"
date: 2026-10-31
draft: false
description: "A hands-on introduction to Alloy for beginners: structural modeling with sig, fact, assert and check — learn to find design bugs before writing any code."
author: "bio"
tags: ["Alloy", "formal verification", "modeling", "software design"]
---

## Why Alloy is the best gateway into formal methods

In the previous post we walked the map of formal verification. Now let's get our hands dirty with Alloy, because it has the shortest path from "never heard of it" to "I just found a bug in my own architecture". The entire language fits on a cheat sheet, and the analyzer requires nothing but a browser (there is an online Alloy Playground) or a small local binary from https://alloytools.org/. No build system, no runtime, no dependencies — open the tool, type a model, press a button.

The philosophy behind Alloy is spelled out in Daniel Jackson's "Software Abstractions" (https://mitpress.mit.edu/9780262101141/): **software design is a collection of abstract structures, and almost all the expensive bugs live in those structures, not in individual lines of code**. Alloy lets you "execute" a design the way you execute code: write down claims about it and ask the analyzer to find counterexamples.

The documentation comes in two layers: the quick reference at https://alloy.readthedocs.io/en/latest/ and the systematic Practical Alloy tutorial (https://practicalalloy.github.io/chapters/about-alloy/index.html). Its chapters on structural (https://practicalalloy.github.io/chapters/structural-modeling/index.html) and behavioral modeling (https://practicalalloy.github.io/chapters/behavioral-modeling/index.html#behavioral-modeling) cover everything you'll need for years. There is also a detailed case study in Russian on Habr: https://habr.com/ru/companies/typeable/articles/546356/.

## The language in ten minutes: sigs, fields, facts

A world in Alloy is described with signatures (`sig`) — sets of atoms with fields that are relations:

```alloy
sig Directory {
  entries: set Name -> File
}

sig File {}
sig Name {}
```

`Directory` and `File` are sets of atoms; `entries` is a relation "directory → name → file". Inheritance works as you'd expect:

```alloy
abstract sig Resource {}
sig Folder extends Resource {
  children: set Resource
}
sig Document extends Resource {
  parent: lone Folder
}
```

An `abstract sig` creates no atoms of its own — only via its extensions. Multiplicity modifiers: `one` (exactly one), `lone` (zero or one), `some` (one or more), `set` (any number). That alone is enough to express half the invariants of real database schemas: "every order has exactly one customer" is `orders: Customer one -> Order`-style constraints, written almost as you'd say them aloud.

**Facts** (`fact`) are statements that hold by definition of the world:

```alloy
fact treeStructure {
  all r: Resource | r not in r.^children
  all d: Document | lone d.parent
  some Root and
    all f: Folder - Root | f in Root.^children
}
```

Here `^children` is the transitive closure of the relation. If you have ever written a recursive CTE in SQL to check a graph for cycles, you will recognize what Alloy is doing — the same check, but declaratively, and with automatic search for violations instead of a query that only inspects the rows you happen to have.

A subtlety worth internalizing early: `fact` means "the world is defined so that this is true", while an `assert` means "I believe this is true — try to prove me wrong". Beginners often write the property they want to *check* as a `fact`, which silently makes the property true and the analysis useless. Facts constrain the world; assertions are what you test.

## Synthesizing instances: run

The first thing a newcomer should do is ask the analyzer to show an example world where everything fits:

```alloy
pred show[] {}
run show for exactly 3 Resource, 3 Folder
```

The Alloy Analyzer will draw the instance: three nodes, the relation arrows, and — usually within seconds — you will *see* with your own eyes that your model permits an orphaned folder or a document with no parent. No assertions needed at this stage; looking at concrete instances is already analysis. This loop of "edit a fact → look at the instance" is half of the daily work with Alloy and the fastest way to develop a *feel* for your specification.

Experienced Alloy users do this instinctively: before any `check`, they run a few `run` commands with different scopes, because an over-constrained model (one whose facts are contradictory) produces no instances at all — and Alloy will tell you "no instance found", which is the specification equivalent of a program that doesn't compile. A vacuous model proves nothing.

## Checking properties: assert and check

The real power comes from claims about *all* possible worlds within a horizon:

```alloy
assert acyclic {
  all r: Resource | r not in r.^children
}
check acyclic for 10
```

If a counterexample exists within 10 atoms, the analyzer will show it: a concrete configuration where the claim is false, drawn as a diagram you can click through.

An honest caveat: `check` is not a full mathematical proof — it is a proof **within the scope**. For most design invariants that is plenty: small-scale bugs almost always scale up, because the same relations and the same facts hold at 5 atoms and at 5 million. The "small scope hypothesis" — Jackson's term — is the empirical backbone of the whole approach: exhaustive checking of tiny instances finds a disproportionate share of real design flaws. When you do need unbounded proofs, Alloy 6 can emulate induction, but a beginner doesn't need to go there for months.

The classic teaching example, straight from the first chapters of Practical Alloy, is a file system model: the claim "deleting a folder leaves no unreachable files" breaks when the folder has subfolders — and you watch the counterexample appear on a diagram seconds after writing a one-line delete operation. Fifteen minutes of that exercise teaches more about state management than a week of debugging.

## Behavior: Alloy 6 and time

Modern Alloy (https://alloy.readthedocs.io/en/latest/) handles behavior too: the language gained temporal operators (`always`, `eventually`, `after`), and fields can change over time. A minimal bank-account example:

```alloy
sig State { balance: one Int }

pred transfer[s1, s2: State, amount: Int] {
  amount > 0
  s1.balance >= amount
  s2.balance = minus[s1.balance, amount]
}
```

For richly behavioral models — protocols, queues, failure and recovery — TLA+ is still more expressive. But for "structure plus light behavior", Alloy 6 closes ninety percent of the cases, and staying in one language for both structure and behavior keeps the cognitive load low.

## A workflow for real projects

Here is what it looks like when you apply Alloy outside of tutorials:

1. **Extract entities and invariants from your documentation.** Any RFC, spec or database diagram is already half a specification: "a user belongs to exactly one organization", "a deleted account cannot be restored twice", "an invoice's total equals the sum of its line items".
2. **Write down the three to five most expensive claims.** Don't try to model everything — the value is in invariants whose violation equals a production incident.
3. **Run checks, read counterexamples, refine facts.** Every counterexample is either a found design bug or an imprecision in your model — and the second is also useful, because it means you understood your own system worse than you thought.
4. **Keep the model alive next to the code.** When the design changes, re-run the checks. Treat it as a unit-test suite for the architecture — one that never rots, because it contains no mocks and no fixtures, only facts.

A practical tip from experience: name your counterexample-hunting. When Alloy shows a bad instance, take a minute to *say* in words what happened: "a folder is its own ancestor because the delete operation removes the parent link but keeps the child pointer". If you cannot phrase it, you haven't understood the counterexample — and an unexplained counterexample gets ignored, which is how teams fall out of love with formal methods.

Incidentally, the same principle — formal structure plus automatic checking — is spreading to adjacent areas: code-graph and knowledge-graph analysis (see https://code-graph-rag.com/ and https://github.com/vitali87/code-graph-rag). A machine builds the formal structure; a human formulates claims; the analyzer hunts for violations. Specifications are ceasing to be purely manual work.

## Beginner pitfalls in the language itself

A few syntax and modeling habits will save you an hour each. Multiplicity is declared on the field, not the type: `parent: lone Folder` means every document has *at most one* parent, while `children: some Resource` on Folder means every folder has *at least one* child — a subtle difference that produces surprisingly alive models when you swap the two by accident. The set operators take a moment to click: `+` is union, `&` is intersection, `-` is difference, `in` is subset, and `.` is a join — so `d.owner in d.viewers` reads "the owner of d is among the viewers of d". Casting everything to these five operators is what makes the language small enough to reason about formally.

Second, resist the urge to `fact` away anomalies. When the checker finds a weird instance, the beginner reflex is to add a fact that forbids it. Sometimes that is correct (physical impossibilities: a folder containing itself); sometimes it is denial (a user *can* end up with zero permissions — the system must handle it, so the model must represent it). A good rule: forbid states that are impossible by physics or by well-accepted external contracts; represent states that are merely embarrassing.

Third, keep scopes small while iterating — `for 3` — and only raise them at the end. Analysis time can grow steeply with scope, and a model that takes a minute per check will not get run often enough to matter. The final due-diligence run can afford `for 8` or `for 10`; the fifty runs you do while editing cannot.

Finally, use `one sig` for singleton concepts — a root folder, a global config — instead of facts saying "exactly one exists". It is shorter, clearer, and the visualizer labels the node, which makes counterexamples noticeably easier to read.

## A second worked example: access control


To make the workflow concrete, here is a compact model you can type into the Playground right now. Suppose your product has organizations, members with roles, and documents shared per-organization:

```alloy
sig Organization {}
sig Person {
  memberOf: some Organization
}
sig Doc {
  org: one Organization,
  owner: one Person,
  viewers: set Person
}

fact memberSeesOwnOrgDocs {
  all d: Doc | d.owner.memberOf = d.org
}

pred share[d, d2: Doc, p: Person] {
  d2.viewers = d.viewers + p
  p.memberOf = d2.org
}

assert ownersCanRead {
  all d: Doc | d.owner in d.viewers
}

check ownersCanRead for 4
```

Two things typically happen when people run this. First, the `fact` is a silent design decision ("an owner always belongs to the doc's organization") that the rest of the team may never have agreed to — the model just made a hidden assumption *visible*. Second, the check passes only because `viewers` happens to include the owner in every instance the analyzer can construct; add an `unshare` operation that removes owners from `viewers`, and the checker finds the exact instance where an owner loses access to their own document. That is a real class of bug — it has shipped in every major file-sharing product at least once — caught by seven lines of Alloy.

Notice also how the model forced a vocabulary decision: what does "shared" mean, is it per-document or per-organization, can a viewer who left the organization retain access? Each of those questions, answered in Alloy in one line, is a support ticket or a security review comment in a traditional workflow.

## Homework


Take a subsystem you know by heart and do three things: describe two or three signatures with fields; add fact-invariants straight from the documentation; write two `check` statements with claims that are "obviously true". With probability close to one, at least one check will fail — and that will be the cheapest bug of your career. For inspiration and tooling, keep https://github.com/elniak/awesome-formal-verification within reach, and when you outgrow Alloy's comfort zone, the same habit of thinking transfers directly to TLA+ and Dafny.
