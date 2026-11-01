---
title: "Causal ML: Teaching Machine Learning to Find Causes, Not Correlations"
date: 2026-10-31
draft: false
description: "An introduction to causal machine learning for beginners: Pearl's ladder of causation, structural causal models, do-calculus, and the tools — DoWhy, CausalML, CausalNex, Tigramite."
author: "bio"
tags: ["causal inference", "causal ML", "DoWhy", "CausalML", "CausalNex", "Tigramite", "machine learning"]
---

## The problem: ML sees correlations, not causes

Classical machine learning is a correlation-finding machine. A model trained on sales history will dutifully learn that in winter, coat sales **and** flu incidence both go up. Ask such a model "what happens if everyone is forced to buy a coat?" and it will predict an epidemic. To any human this is absurd: coats don't cause colds — both are effects of cold weather. But to a model trained purely on correlations there is no difference between "coats cause flu" and "cold causes both".

Causal machine learning (causal inference, causal AI) is the branch of ML that answers the question **"what influences what"** and, crucially, **"what happens if we intervene"**. The best systematic introduction is Judea Pearl's overview "Causal Inference in Statistics" (https://ftp.cs.ucla.edu/pub/stat_ser/r354-corrected-reprint.pdf), and among free, readable explanations the LessWrong sequence is outstanding: https://www.lesswrong.com/posts/hzuSDMx7pd2uxFc5w/causal-diagrams-and-causal-models and the causality wiki entry at https://www.lesswrong.com/w/causality.

## Pearl's ladder of causation

Pearl organizes the whole field as a hierarchy of questions — memorize it and half of the literature will sort itself out:

1. **Association** ("I saw X — what do I expect from Y?"). The level of ordinary ML: prediction from correlations. Coats and flu go together.
2. **Intervention** ("if I *do* X, what happens to Y?"). The level of causal ML: do-calculus, A/B tests. "If I raise the price, what happens to churn?" — a question that regression on historical data answers incorrectly by construction.
3. **Counterfactuals** ("what would have happened had we acted differently?"). "The customer churned. Would they have stayed if we'd offered a discount a month ago?" — the level of individual causal explanation.

Each level requires strictly more knowledge than the data alone provides — it requires **causal assumptions**. That is the uncomfortable but liberating truth of the field: you cannot get causes out of observational data without putting assumptions in. The craft lies in making those assumptions explicit, minimal, and checkable.

## Structural causal models (SCM)

The mathematical machinery is structural causal models: the world is described by a **directed graph** (who influences whom) plus equations linking each variable to its causes. The graph encodes assumptions: `Cold → CoatSales`, `Cold → Flu`. The key concepts layered on top:

- **Confounder** — a hidden common cause. Confounders are what generate spurious correlations; the classic advice "correlation is not causation" is really "beware of confounders".
- **The do-operator**: `do(X = x)` denotes a forced intervention that severs every arrow into X. The difference between `P(Y | X)` and `P(Y | do(X))` is the whole subject in one formula: conditioning on observation versus forcing a change.
- **Do-calculus** — a set of rules for computing intervention effects from observed data, *given* that the graph is correct. Sometimes the graph proves the effect is not identifiable in principle from the data at hand — and that, too, is a valuable result: it saves you from running an A/B test that can never succeed, and tells you exactly which extra variable you'd need to measure.

The same machinery dissolves Simpson's paradox: statistics can show a treatment helps men and helps women, yet "overall" appears to hurt. A causal graph makes it obvious in one glance that aggregation across groups mixes two different causal questions — and tells you which one you should be answering.

## What causal discovery can do

A separate direction — **causal discovery** — aims to *build* the causal graph automatically from historical data. This is what makes the field accessible without a committee of domain experts drawing diagrams by hand:

- **Causal discovery from time series**: algorithms search the history of state changes for asymmetries — causes precede effects, and interventions break dependencies downstream — to orient the arrows.
- **Granger causality**: if the past of variable X improves the prediction of variable Y beyond the past of Y alone, X is "causal" for Y in the Granger sense. Strictly speaking this is *predictive* causality, not physical causation — a lamp switching on at dusk Granger-causes darkness, but does not cause it — yet for many time-series problems (server logs, market data, monitoring metrics) it is a serviceable first approximation, and it is the concept to know before touching the fancier algorithms.
- **Pearl-style SCM analysis** — identification and estimation of effects given a graph, possibly one that discovery algorithms partially inferred.

The realistic workflow combines all three: discovery proposes, domain knowledge disposes, SCM analysis delivers the number.

## The tools to start with

### DoWhy — a framework with a four-step methodology

DoWhy structures every causal analysis as an explicit pipeline: **model** (build the causal graph), **identify** (determine whether the effect is estimable from the available data), **estimate** (compute the estimate), **refute** (attack the estimate with stress tests — placebo interventions, random subsets, simulated confounders). That last step is the framework's main virtue: DoWhy forces you to try to falsify your own estimate instead of blindly reporting it. The canonical scenario is estimating the effect of a discount on retention when several confounders — customer tenure, seasonality, prior spend — lurk in the data.

### CausalML — uplift modeling from Uber

CausalML (https://github.com/uber/causalml) is about the conditional average treatment effect (CATE) and uplift: "which customers does the campaign actually move, and which would have converted anyway?" Inside you'll find the meta-learner family (T-, S-, X-learner), uplift trees, and interpretability support. The canonical use case is targeting promotions: sending discounts to people who would have bought regardless is pure margin loss, and uplift modeling is precisely the tool that separates persuadables from sure things.

### CausalNex — Bayesian networks and structure from expert knowledge

CausalNex (https://github.com/mckinsey/causalnex; tutorial: https://causalnex.readthedocs.io/en/latest/03_tutorial/01_first_tutorial.html#Structure-from-Domain-Knowledge) from QuantumBlack/McKinsey builds Bayesian networks where you can **seed the structure with domain knowledge** rather than learning it blindly from data — including NOTEARS for structure learning when data is rich. Their tutorial on scoring an inferred structure with ROC/AUC (https://causalnex.readthedocs.io/en/latest/03_tutorial/01_first_tutorial.html#ROC-/-AUC) is a gentle first exercise. CausalNex shines where data is scarce but experts are available, and where you need an interpretable "what influences what" model rather than a black-box score.

### Tigramite — causality in time series

Tigramite (https://github.com/jakobrunge/tigramite) specializes in causal analysis of time series: the PCMCI family of algorithms finds lagged causal links while filtering out spurious ones through conditional-independence tests. If your data is service metrics, sensor streams, or financial series, start here; the visualizations of lagged causal graphs alone are worth the install. For streaming signals there is also causalflow (https://github.com/lcastri/causalflow) — causal discovery for time series built on recurrent models.

## A worked line of thinking

Task: "an algorithm observes the history of a system's states — find the causes of failures." Unpacked:

1. **Data**: per-minute service metrics plus events for deploys and incidents.
2. **Discovery**: Tigramite/PCMCI builds a lagged causal graph: `deploy → latency_p99 (+3 min)`, `cache_hit_rate → db_load`. Spurious correlations get filtered as the conditional-independence tests do their work.
3. **Identification**: the graph shows the effect of "deploy → incident" runs through `latency_p99`; the confounder "Friday releases" is either conditioned away or handed to do-calculus.
4. **Estimation and refutation**: DoWhy estimates the effect, and refute tests probe its stability.
5. **Result**: not "correlation between deploys and incidents of 0.7" but a concrete causal chain — "releases without a run of test X raise p99, which raises incident probability by p" — and, with it, an exact point of intervention.

Notice what happened at step five: the output stopped being a number for a dashboard and became a decision. That is the practical dividend of causal thinking.

## Why not just run an A/B test?

The natural objection: "if I want to know the effect of an intervention, why not intervene — run the experiment?" When an experiment is feasible, you should; a randomized controlled trial is the gold standard because randomization breaks the arrows from confounders by construction. But three situations make causal modeling indispensable rather than optional.

First, **experiments you cannot run**: you cannot randomly deny insulin to diabetics to measure its effect, cannot throttle half your users' payment flows for a quarter, cannot re-run last year's pricing. Historical interventions — outages, policy changes, campaigns — are natural experiments, and causal methods (difference-in-differences, instrumental variables, do-calculus on observational graphs) are how you extract signal from them.

Second, **experiments that are too small**: with thousands of segments and dozens of candidate interventions, testing each pair is combinatorially hopeless. A causal model trained on observational data narrows the field to the few interventions worth the cost of a controlled test.

Third, **questions about individuals**: an A/B test gives you the average effect, but "should *this* customer get the discount?" is an uplift question, which is exactly what CausalML's meta-learners estimate from experiment *or* observational data. The mature practice uses both: causal models to prioritize, experiments to confirm, uplift models to personalize.

## A one-paragraph cheat sheet for choosing a tool

If you have a causal graph and observational data and want an effect estimate with honest robustness checks — DoWhy. If you have historical campaigns and want to know *whom* to target — CausalML. If your data is small and your experts are many, and you want an interpretable network — CausalNex. If your data is time series — Tigramite first, causalflow for streaming signals, and Granger causality as the sanity-check baseline. If none of these conditions hold and you just have correlated features, that in itself is information: it means you are not ready to ask causal questions yet, and any answer would be borrowed confidence.

## Four myths worth retiring

**"Causal discovery finds the true causal graph from data."** Discovery algorithms return *one graph consistent with the data under the assumptions* — usually several graphs fit equally well, and the algorithms output equivalence classes or confidence-weighted edges. Treat the output as a ranked hypothesis list for expert review, never as ground truth. Teams that skip the expert review step eventually rediscover why the field insists on it.

**"Granger causality is causality."** Granger's test answers a predictive question, and predictive questions are confounded by latent common drivers — the streetlight that switches on at dusk Granger-causes darkness. It remains a useful screening tool for time series, but any decision that costs money or lives deserves an SCM analysis with the graph made explicit.

**"Uplift models remove the need for experiments."** Uplift estimates from observational data inherit every confounder you failed to measure; the meta-learners are estimators, not magicians. The strongest setups combine them: causal models and uplift to *choose* what to test and for whom, experiments to confirm, then uplift to scale personalization.

**"If the estimate is significant, it is causal."** Statistical significance measures the stability of a number under sampling noise, not the truth of its causal reading. A p-value below 0.05 on a confounded comparison is a precisely estimated wrong answer. This is the quiet reason DoWhy's `refute` step matters more than its `estimate` step: robustness under placebo interventions and simulated confounders says something about causes; a p-value says something about variance.

## Honest limitations



- Causal ML **always rests on assumptions**. The graph is an assumption; data never "proves" it, at best it fails to refute it. Expert interviews are part of the pipeline, not a luxury.
- Hidden confounders — in biology there are thousands: temperature, pH, thousands of unmeasured molecules — can flip conclusions entirely; in such domains causal discovery works only in tandem with domain models like thermodynamics or molecular dynamics.
- Not everything is identifiable: sometimes an effect cannot in principle be computed from observational data — and it is a genuine feature of the framework that the graph tells you this *before* you burn months on an A/B test.

## Where to start

A route: Pearl's overview (https://ftp.cs.ucla.edu/pub/stat_ser/r354-corrected-reprint.pdf) → the LessWrong posts (https://www.lesswrong.com/posts/hzuSDMx7pd2uxFc5w/causal-diagrams-and-causal-models) → the CausalNex first-network tutorial (https://causalnex.readthedocs.io/en/latest/03_tutorial/01_first_tutorial.html#Structure-from-Domain-Knowledge) → DoWhy on your own data → Tigramite if your data is temporal.

The one-sentence summary: ordinary ML answers "what usually happens together"; causal ML answers "what happens if we intervene". The second question is the only one anyone making decisions actually cares about.
