# constrained-bidirectional-ccd
A compact experimental constrained CCD inverse-kinematics solver implemented in GDScript.

## Status
This repository is experimental and is not intended to be a general-purpose Godot IK library.

## Overview
The solver is fundamentally a constrained cyclic coordinate descent solver but actually developed independently.

Its main distinction is the use of alternating sweep directions to represent hierarchical effort recruitment rather than minimizing endpoint error through a single fixed update order.

## Design
### Constraints
Each segment uses two constrained rotational coordinates:
- **Flex** rotates around the preceding segment's X axis
- **Yaw** rotates around the segment itself's Y axis

Flex is applied before yaw.

The flex angle represents the angle between adjacent segment directions:
- 0° represents a fully folded joint
- 180° represents a fully extended joint

All rotations are clamped to the joint’s permitted range before being applied.

### Solving
The solver interprets distal and proximal adjustments differently:
- Distal adjustments are small, local, and lazy;
- Proximal adjustments represent larger structural changes to the pose.

It builds three solving modes in:
- **Distal-first passes only**
Conventional CCD-style solving. This often converges quickly and keeps corrections local.
- **Proximal-first passes only**
Redistributes movement across the chain and may produce broader, more natural pose changes, but can require more iterations.
- **Alternating passes**
Alternates between distal-first and proximal-first solving. The proximal pass acts as a larger corrective response when local distal adjustments are insufficient.

The biological interpretation is a design heuristic rather than a biomechanical simulation.

### Time-based solving
The solver can perform one adjustment step instead of converging fully within one frame.

A caller can:
1. solve one pass from the current pose;
2. interpolate partially toward the result;
3. use the resulting pose as the starting state for the next frame.
This allows convergence to occur over time rather than instantaneously.

The approach may produce smoother motion, preserves dependence on the current pose, and makes the chain easier to combine with external forces, animation blending, or other procedural controls.

It is also possible to run multiple passes in one frame when immediate convergence is preferred.

### Buffered evaluation
Resolved poses are evaluated in internal position, basis, and joint-angle buffers rather than being committed directly to scene nodes after every adjustment.

### Scene model
Each segment places its origin at the beginning of the segment rather than at its center.

Segments are expected to be siblings under a common parent instead of forming a nested tree hierarchy. Positions and bases are calculated in the shared parent's space.

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
