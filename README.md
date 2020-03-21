# ALGAMES


<!-- ![Build Status](https://travis-ci.org/RoboticExplorationLab/TrajectoryOptimization.jl.svg?branch=master) -->
[![codecov](https://codecov.io/gh/RoboticExplorationLab/ALGAMES.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/RoboticExplorationLab/ALGAMES.jl)
<!-- [![](https://img.shields.io/badge/docs-dev-blue.svg)](https://RoboticExplorationLab.github.io/TrajectoryOptimization.jl/dev) -->


A package for solving constrained dynamic games written in Julia. Currently, the following methods are implemented with a common interface:

[ALGAMES (Augmented Lagrangian Games Theoretic Solver)](https://rexlab.stanford.edu/papers/ALGAMES.pdf): A fast solver for constrained dynamic games that features:
  * General nonlinear cost functions
  * General nonlinear state and input constraints


This package also features:
  * Several autonomous driving environments (ramp merging, intersection crossing, etc.)
  * A Model Predictive Control (MPC) implementation of ALGAMES
  * Plotting and visualization tools

![](plots/gif/merging_4pl_2x_white.gif)

All methods utilize Julia's extensive autodifferentiation capabilities via [ForwardDiff.jl](http://www.juliadiff.org/ForwardDiff.jl/) so that the user does not need to specify derivatives of dynamics, cost, or constraint functions.

## Installation
To install ALGAMES.jl, run the following from the Julia REPL:
```julia
Pkg.add(PackageSpec(name="TrajectoryOptimization", rev="v1.3"))
Pkg.add(PackageSpec(url="https://github.com/RoboticExplorationLab/ALGAMES.jl.git"))
```

## Quick Start
To run a simple example of a 2-player 2D double-integrator:
```julia
using ALGAMES
using LinearAlgebra
using StaticArrays
using TrajectoryOptimization
const TO = TrajectoryOptimization

# Discretization info
tf = 3.0  # final time
N = 41    # number of knot points
dt = tf / (N-1) # time step duration

# Instantiate dynamics model
model = DoubleIntegratorGame(p=2)
n,m,pu,p = size(model)
T = Float64

# Define initial and final states (be sure to use Static Vectors!)
x0 = @SVector [-0.50,  0.10, # position player 1
			   -0.50, -0.10, # position player 2
                0.50,  0.00, # velocity player 1
				0.40,  0.00] # velocity player 2
xf = @SVector [ 0.50, -0.10, # position player 1
				0.50,  0.10, # position player 2
                0.40,  0.00, # velocity player 1
				0.30,  0.10] # velocity player 2

# Define a quadratic cost for each player
diag_Q = [SVector{n}([1., 1., 0., 0., 1., 1., 0., 0.]), 	# Player 1 cost
	      SVector{n}([0., 0., 1., 1., 0., 0., 1., 1.])] 	# Player 2 cost
Q  = [0.1*Diagonal(diag_Q[i]) for i=1:p] # Players stage state costs
Qf = [1.0*Diagonal(diag_Q[i]) for i=1:p] # Players final state costs
# Players controls costs
R = [0.1*Diagonal(@SVector ones(length(pu[i]))) for i=1:p]

# Players objectives
obj = [LQRObjective(Q[i],R[i],Qf[i],xf,N) for i=1:p]

# Build problem
actor_radius = 0.08
actors_radii = [actor_radius for i=1:p]

# Create constraints
conSet = ConstraintSet(n,m,N)
con_inds = 2:N # Indices where the constraints will be applied

# Add collision avoidance constraints
add_collision_avoidance(conSet, actors_radii, model.px, p, con_inds)
u_min = - SVector{m}(ones(m))
u_max = + SVector{m}(ones(m))
con = BoundConstraint(n,m,u_min=u_min,u_max=u_max)
add_constraint!(conSet, con, con_inds)

# Define the problem
prob = GameProblem(model, obj, xf, tf, constraints=conSet, x0=x0, N=N)

# Specify the solver's options
opts = DirectGamesSolverOptions{T}()

solver = DirectGamesSolver(prob, opts)
solve!(solver)
```

## Examples
Notebooks with more detailed examples can be found [here](https://github.com/RoboticExplorationLab/ALGAMES.jl/tree/master/experiments/notebooks), including all the examples from our [RSS 2020 paper](https://github.com/RoboticExplorationLab/ALGAMES.jl/tree/master/experiments/rss_2020). Among these examples we solve a ramp merging problem and an intersection crossing problem:
![](plots/gif/intersection_3pl_2x.gif)
![](plots/gif/merging_3pl_2x.gif)

We also perform a Monte Carlo analysis of ALGAMES to evaluate the robustness and speed of the solver to noise in the initial condition.
![](plots/gif/monte_carlo_merging.gif)


<!-- ## Documentation
Detailed documentation for getting started with the package can be found [here](https://roboticexplorationlab.github.io/TrajectoryOptimization.jl/dev/). -->
