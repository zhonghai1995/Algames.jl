################################################################################
# Intro Example
################################################################################
include( joinpath(@__DIR__, "..", "src", "Algames.jl") )



using .Algames
using StaticArrays
using LinearAlgebra
using Plots

T = Float64

# Define the dynamics of the system
p = 3 # Number of players
model = BicycleGame(p=p) # game with 3 players with unicycle dynamics
n = model.n
m = model.m

# Define the horizon of the problem
N = 30 # N time steps
dt = 0.1 # each step lasts 0.1 second
probsize = ProblemSize(N,model) # Structure holding the relevant sizes of the problem

# Define the objective of each player
# We use a LQR cost
Q = [Diagonal(10*ones(SVector{model.ni[i],T})) for i=1:p] # Quadratic state cost

#I want to increase R a little bit
R = [Diagonal(0.1*ones(SVector{model.mi[i],T})) for i=1:p] # Quadratic control cost
# Desrired state
#xf = [SVector{model.ni[1],T}([2,+0.4,0,0]),
#      SVector{model.ni[2],T}([2, 0.0,0,0]),
#      SVector{model.ni[3],T}([3,-0.4,0,0]),
#      ]
xf=[SVector{model.ni[1],T}([0,0,0,0]),
    SVector{model.ni[2],T}([0,0,0,0]),
    SVector{model.ni[2],T}([0,0,0,0]),
    ]




# Desired control
uf = [zeros(SVector{model.mi[i],T}) for i=1:p]
# Objectives of the game
game_obj = GameObjective(Q,R,xf,uf,N,model)
radius = 1.0*ones(p)

#What is the meaning of u?
μ = 5.0*ones(p)


add_collision_cost!(game_obj, radius, μ)


#Figure out how to add state constraints
#非常简单，看下 Trajectoryoptimization package的 constraint_list.jl的add_constraint!函数，有介绍


# Define the constraints that each player must respect
game_con = GameConstraintValues(probsize)
# Add collision avoidance
radius = 0.08
add_collision_avoidance!(game_con, radius)
# Add control bounds
u_max =  5*ones(SVector{m,T})
u_min = -5*ones(SVector{m,T})
add_control_bound!(game_con, u_max, u_min)

#Remove wall constraints
# Add wall constraint
#walls = [Wall([0.0,-0.4], [1.0,-0.4], [0.,-1.])]
#add_wall_constraint!(game_con, walls)

# Add circle constraint
#we can use circle constraint directly to define the obstacles?
#xc = [1.,  5.]
#yc = [1.,  5.]
#radius = [0.1,  0.3]
#add_circle_constraint!(game_con, xc, yc, radius)

xg = MVector{model.n,T}([1.0,1.0,0,0,2.0,2.0,0,0,3.0,3.0,0,0])
    


add_goal_constraint!(game_con,xg)


# Define the initial state of the system
x0 = SVector{model.n,T}([
    0.1, 0.0, 0.5,
   -0.4, 0.0, 0.7,
    0.0, 0.0, 0.0,
    0.0, 0.0, 0.0,
    ])

# Define the Options of the solver
opts = Options()
# Define the game problem
prob = GameProblem(N,dt,x0,model,opts,game_obj,game_con)

# Solve the problem
@time newton_solve!(prob)

# Visualize the Results
Algames.plot_traj!(prob.model, prob.pdtraj.pr)
Algames.plot_violation!(prob.stats)
