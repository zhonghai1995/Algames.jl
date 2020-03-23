using ALGAMES
using LinearAlgebra
using StaticArrays
using TrajectoryOptimization
const TO = TrajectoryOptimization
const AG = ALGAMES


# Instantiate dynamics model
model = UnicycleGame(p=3)
n,m,pu,p = size(model)
T = Float64
px = model.px

# Discretization info
tf = 3.0  # final time
N = 41    # number of knot points
dt = tf / (N-1) # time step duration

# Define initial and final states (be sure to use Static Vectors!)
x0 = @SVector [# p1   # p2  # p3
              -0.50,  1.40,  0.43, # x
              -0.15,  0.15, -0.30, # y
			   0.00,    pi,  pi/2, # θ
			   0.60,  0.60,  0.10, # v
               ]
xf = @SVector [# p1   # p2  # p3
               1.30, -0.30,  0.43 ,# x
              -0.15,  0.15,  0.35 ,# y
			   0.00,    pi,  pi/2 ,# θ
			   0.60,  0.60,  0.30 ,# v
              ]

diag_Q = [SVector{n}([0.,  0.,  0.,
					  1.,  0.,  0.,
					  1.,  0.,  0.,
					  1.,  0.,  0.]),
	      SVector{n}([0.,  0.,  0.,
		  			  0.,  1.,  0.,
					  0.,  1.,  0.,
					  0.,  1.,  0.]),
		  SVector{n}([0.,  0.,  0.,
					  0.,  0.,  1.,
					  0.,  0.,  1.,
					  0.,  0.,  1.])]
Q  = [0.1*Diagonal(diag_Q[i]) for i=1:p] # Players stage state costs
Qf = [1.0*Diagonal(diag_Q[i]) for i=1:p] # Players final state costs
# Players controls costs
R = [0.1*Diagonal(@SVector ones(length(pu[i]))) for i=1:p]

# Players objectives
obj = [LQRObjective(Q[i],R[i],Qf[i],xf,N) for i=1:p]

# Build problem
actor_radius = 0.08
actors_radii = [actor_radius for i=1:p]
actors_types = [:car, :car, :pedestrian]
top_road_length = 4.0
road_width = 0.60
bottom_road_length = 1.0
cross_width = 0.25
bound_radius = 0.05
lanes = [1, 2, 5]
scenario = TIntersectionScenario(
    top_road_length, road_width, bottom_road_length, cross_width, actors_radii, actors_types, bound_radius)

# Create constraints
algames_conSet = ConstraintSet(n,m,N)
ilqgames_conSet = ConstraintSet(n,m,N)
con_inds = 2:N # Indices where the constraints will be applied

# Add collision avoidance constraints
add_collision_avoidance(algames_conSet, actors_radii, px, p, con_inds)
add_collision_avoidance(ilqgames_conSet, actors_radii, px, p, con_inds)
# Add scenario specific constraints
add_scenario_constraints(algames_conSet, scenario, lanes, px, con_inds; constraint_type=:constraint)
add_scenario_constraints(ilqgames_conSet, scenario, lanes, px, con_inds; constraint_type=:constraint)

algames_ramp_merging_3_players_prob = GameProblem(model, obj, xf, tf, constraints=algames_conSet, x0=x0, N=N)
ilqgames_ramp_merging_3_players_prob = GameProblem(model, obj, xf, tf, constraints=ilqgames_conSet, x0=x0, N=N)

algames_opts = DirectGamesSolverOptions{T}(
    iterations=10,
    inner_iterations=20,
    iterations_linesearch=10,
    min_steps_per_iteration=0,
    log_level=TO.Logging.Debug)
algames_ramp_merging_3_players_solver = DirectGamesSolver(algames_ramp_merging_3_players_prob, algames_opts)

ilqgames_opts = PenaltyiLQGamesSolverOptions{T}(
    iterations=200,
    gradient_norm_tolerance=1e-2,
    cost_tolerance=1e-4,
    line_search_lower_bound=0.0,
    line_search_upper_bound=0.02,
    log_level=TO.Logging.Debug,
    )
ilqgames_ramp_merging_3_players_solver = PenaltyiLQGamesSolver(ilqgames_ramp_merging_3_players_prob, ilqgames_opts)
pen = ones(length(ilqgames_ramp_merging_3_players_solver.constraints))*100.0
set_penalty!(ilqgames_ramp_merging_3_players_solver, pen);

# @time timing_solve(algames_ramp_merging_3_players_solver)
# @time timing_solve(ilqgames_ramp_merging_3_players_solver)
#
# visualize_trajectory_car(algames_ramp_merging_3_players_solver)
# visualize_trajectory_car(ilqgames_ramp_merging_3_players_solver)
