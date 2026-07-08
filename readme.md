# constrained-bidirectional-ccd
A compact experimental constrained CCD inverse-kinematics solver implemented in GDScript.


## Status
This repository is experimental. It's mainly a place to test CCD variants and constrained chain convergence. It can be used as a general purpose library to test and implement CCD variants in Godot. 


## Why this exists
The original development wasn't to build a CCD solver at all but actually to build a **biological plausible** kinematics resolver. It everntually evolved to CCD nonethelss. But the original ideas still stand and give rise to the CCD variants tested here.


## Quick start
(Skip for now)


## Ideas
### Biological meaning
Commonly, a limb default to cheap, local and distable corrections first, and only recruit the more disruptive proximal joints when distal corrections alone aren't enough. 

Based on this **hierarchical effort recruitment** idea, it's natural to want to explore models that's alternating or lazy escalting, thus this project.

### Progressive convergence
The solver doesn't need to fully converge within a single call. A caller can run one pass, interpolate partway toward the resulting pose, and use that intermediate pose as the starting point for the next call. 

This may produces a smoother, more animatable and more externally-aware result. 


## Models
### Flex and yaw
This project abstracts a segment's orientation to two numbers: how much it folds or extends (**flex**), and how much it turns side to side (**yaw**). Every segment's rotation can be constrained to the joint's allowed range.
In this project's implementation, flex is applied first, then yaw. A flex of 0° is a fully folded joint, 180° is fully extended, or "unfold".

### Model layer
This project divides into 2 layers: model and control. 

The model layer consists `joint`, `segment` and `chain`. `joint` determines the rotation limits, `segment` specifies the length, and `chain` groups its constituent segments. 

Segments are modeled as *siblings* under a shared parent chain rather than a nested parent-child tree. Each segment places the origin at the start rather than the center.

### Control layer
The control layer is mainly about `adjuster`. The adjuster operates in the shared *parent's space* instead of the global space or segments' local space. 

To improve performance, all the passes are dry-run in the adjuster. Resolved poses are held in internal **buffers** and are not committed to the chain. Commits is the caller's responsibility. 

Adjuster heavily **caches and reuses** internal states. To reduce allocations and given the temporary nature of kinematics, returned results are only views into the cache, and are not safe to hold onto unless explicitly duplicated. Therefore, the adjuster is not thread-safe.

The adjuster exposes methods for full converging to a target position and for a single pass, for progressive convergence

### Addons
This project provides editor plugins for **adjusting** chains or **visualizing** the motion paths, with chains and segments already being `@tool` classes. 

The visualizer draws one path per iteration, not one path per segment per iteration. The visualizer works by adding immediate line meshes to the scene tree.

The plugins should offer a convenient interface to experiment with and compare CCD variants, as well as set the start state of chains. 


## Solving
This project tests some CCD variants. The sample size is small and the test chain is heavily constrained. The results were consistent and explainable enough but need further experiments. 

All tests are carried out by analyzing:
* the iterations needed before converging;
* the result pose after converging;
* the paths the convergence walked through;

### Background
Traditional CCD corrects one joint at a time. It sweeps through the segments either from the tip toward the base or from the base toward the tip. These are usually called **backward** and **forward** passes.

#### What settles each sweep direction
Regardless which direction is in use, every joint runs the same local rule: align its vector to the effector at its vector to the target. However, within one pass, the corretion of upstream joints will disturb the alignment of downstream joints, since every joint only evaluates its own effector-to-target difference. Proximal joints causes more "disturbance". 

Therefore, a distal-first sweep eventually aligns the base-tip vector to the base-target vector, and a proximal-first sweep aligns the last joint-tip vector last joint-target vector. This can be read as the *criteria* difference between different directions.

Besides causing more "damage", proximal joints also contributes more. The same rotation at a proximal joint makes bigger changes as it carries the lengths of downstream segments as well. This is exactly why proximal joints feels **global** and **forceful** and distal joints feels **local** and **limited**.

Because of this, each joint's alignment affects the effector position later adjustments see, which explains why distal-first and proximal-first sweeps produce very different results, despite they sounds like mirrored processes.

### Tested modes
#### Backward only
Baseline mode. Works as expected. The paths are gradual and nartual. Polarized rotation can often be seen on distal joints.

#### Forward only
Work as expected. It can often converge in far fewer iterations compared to the backward-only model on large corrections. But the motion paths read forceful and base-driven and may fit organic limbs poorly. 

#### Simple alternating
It was expected to blend the benefits of the two sweep directions and represent the idea of hierarchical effort recruitment. But in practice, it often failed to converge. The motion paths looked like a pendulum orbiting the target rather than approaching it. This is a predictable consequence of alternating between two conflicting  alignment criteria. More on this on the later explanation section.

#### Forward segments
Deprecated. 

This mode aligns the segement attached to a joint directly to the target instead of the joint-effector vector. It does not converge, since each pass resets to a fixed pose.

#### Forward align segments first, then sweep backwards
This mode works surprisingly strong. 

A proximal-first sweep that aligns segments instead of joint-effector vectors computes a *deterministic* pose. This is then used as a *nearly-unfolded* starting pose for the backward sweep, which significantly reduce its usual bottleneck, resulting in *faster convergence*. It also improves the rotation *distribution* across joints.

However, since it's effectively stateless and ignores the starting pose entirely, it may be incompatible with progressive convergence.

#### Forward align segments first, then sweep forwards
This worked unpredictably and made no meaningful improvements. This may be because forward sweep is already global oriented, so aligning segments first doesn't introduce any help, besides adding clamp-interation noises. 

#### Sweep forwards first, then sweep backwards
The warm start doesn't help in significance and eventually gets dominated by later sweeps. The benefit is even more doubtable considering the criteria difference between two sweep directions. 

#### Sweep backwards first, then sweep forwards
Same as previous mode.

However, this mode may help short-circuits cases where the required change is small and local, at the cost of only one iteration checking.

#### Improved alternating
Aimed at the pendulum problem in the simple alternating model above, three variants were tried: 
* forward sweeps aligned: apply an additional base-effector correction after forward pass;
* backward sweeps aligned: apply an additional last segment correction after backward pass;
* both directions aligned.

The backward aligned mode closely resembles the simple alterating mode. This is expected, since correcting the last segment is too local a fix to hold much significance. 

The forward aligned variant shows a clear benefit, though the difference isn't dramatic. It interpolates between backward-only and forward-only, as expected, but is heavily biased towards the backward-only mode in iteration counts, motion paths and final poses. Still, it can sometimes improve the rotation distribution and convergence speed at negligible cost. 

The both aligned variant is nearly identical to the forward-aligned variant. This is also expected as correcting the last segment adds little on its own and gets dominated by the influence of the base-effector correction. 

### Kept modes
Four modes stand out with a genuine and explainable reason:
1. Backward only: A safe default. Predictable, local, gradual, and well behaved for lightly constrained chains or small corrections; a "feeling along a wall" motion vibe.
2. Forward only: A good alterantive for heavily constrained chains or large corrections. The tradeoff is a forceful, base-driven motion look. 
3. Forward-aligned alternating: Closely tracks with backward-only with potentional extra help at negligible cost. Whether this holds up on a less constrained chain is still an open question.
4. Segments-aligned-first backward: The strongest mode. It's more deterministic, more evenly distributed across joints, and consistently faster than backward-only. 

### Test limitaions
* Limited test objects
* Limited smaples
* Tested with static targets only


## Explainations
### The limitations of plain distal-first CCD
Distal-first CCD is the industry default for good reasons. Its corrections stay local and it degrades gracefully on lightly constrained chains. But because it commits to the whole-chain reach question only at the base, and only once per pass, a heavily constrained chain that needs a large structural change can spend more passes. It also put more work on distal joints, resulting in distal-biased poses.

### Why proximal-first also works
While distal-first is often treated as simply better, under the situation of heavily constrained chain or large structural change, proximal-first can often converge in fewer iterations, exactly due to the "global change first" reason.

### Why simple alteranting does not work
As promising as alternating between these two sweeps sounds, it doesn't combine both of their strengths in practice.

As mentioned, different sweep directions end in different *source of truth* after a pass: distal-first passes points the base-effector vector to the target, while proximal-first passes aligns the last joint-effector. This criteria disagreement result in oscillating when resolving alternatingly.


## What's next
* Batch plugin
* Test on lightly constrained or free hanging chains
* Per-pass logging of which joint absorbs the largest correction and whether that correction was clamp-limited


## History
The project began as a spider-specific 2D leg solver:
- Anatomical segments were grouped into larger functional bones;
- A deterministic pose was found through bisection;
- A single `hydraulic pressure` scalar coordinated extension and flexion across the leg.
    
The final two bones were later solved geometrically.

Lazy proximal recruitment was introduced, keeping proximal joints inactive unless the distal solution failed.

An initial yaw layer distributed a scalar yaw `effort` across the chain, but was deprecated because joint yaw values are not directly additive.

A second yaw solver attempted distal-first adjustment followed by restoration toward the rest pose, but was also deprecated because it treated yaw and flex as independent problems.

The model was redesigned so that flex and yaw were solved together through incremental distal-first adjustment.

A proximal-first pass was then added to redistribute the pose when local correction propagated back to the base without reaching the target.

The method eventually had independently converged toward constrained CCD while retaining the original ideas of preferred posture, local correction, delayed proximal recruitment, and gradual time-based solving.
