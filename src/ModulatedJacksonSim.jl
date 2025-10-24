module ModulatedJacksonSim

using Parameters
using Accessors
using LinearAlgebra
using Random
using Plots
using DataStructures
using StatsBase
using Distributions

include("events.jl")


# Export so we can call the functions directly
export NetworkParameters
export scenario1, scenario2, scenario3, scenario4
export averaged_service_rate, maximal_alpha_scaling, set_scenario, plot_total_steady_state_mean_queues
export sim_net_trace, sim_net_estimation

@with_kw struct NetworkParameters # The @with_kw macro comes from the Parameters.jl package and makes nice constructors
    L::Int
    alpha_vector::Vector{Float64} # This vector is a vector of α_i which can then be scaled
    mu_vector::Vector{Float64} # This is the vector of service rates considered fixed
    P::Matrix{Float64} # Routing matrix
    gamma_1::Float64 = (10^-8) # The rate of modulation slow to fast (default is that system is almost always slow)
    gamma_2::Float64 = 1.0 # The rate of modulation fast to slow
    kappa::Float64 = 2.0 # The speedup parameter
end

include("states.jl")
include("utils.jl")
include("engine.jl")

#################
### SCENARIOS ###
#################

############################
# Three queues in tandem ###
############################
scenario1 = NetworkParameters(L=3, 
alpha_vector = [0.5, 0, 0], 
mu_vector = ones(3), 
P = [0 1.0 0; 0 0 1.0; 0 0 0])

####################################################################
# Three queues in tandem with option to return back to first queue #
####################################################################
scenario2 = @set scenario1.P = [0 1.0 0; # The @set macro is from Accessors.jl and allows to easily make a 
                                0 0 1.0; # modified copy of an (immutable) struct
                                0.3 0 0] 

############################
# A ring of 5 queues #######
############################
scenario3 = NetworkParameters(L = 5, 
alpha_vector = ones(5), 
mu_vector = collect(1:5), 
P = [0  .8   0    0   0; 
0   0  .8   0    0; 
0   0   0   .8   0; 
0   0   0    0  .8; 
.8  0   0    0   0])

############################
# A large arbitrary network

#Generate some random (arbitrary) matrix P
Random.seed!(0)
L = 100
P = rand(L, L)
P = P ./ sum(P, dims = 2) #normalize rows by the sum
P = P .* (0.2 .+ 0.7rand(L)) # multiply rows by factors in [0.2,0.9] 

scenario4 = NetworkParameters(  L=L, 
                                alpha_vector = ones(L),
                                mu_vector = 0.5 .+ rand(L),
                                P = P);




#############
# FUNCTIONS #
#############

# Returns the averaged service rate vector (this is tilde μ)
averaged_service_rate(net::NetworkParameters) = (net.gamma_1 * net.kappa + net.gamma_2) * net.mu_vector / (net.gamma_1 + net.gamma_2)


"""
Compute the maximal value by which we can scale the α_vector and be stable.
"""
function maximal_alpha_scaling(net::NetworkParameters)
    lambda_base = (I - net.P') \ net.alpha_vector # Solve the traffic equations
    rho_base = lambda_base ./ averaged_service_rate(net) # Determine the load rho
    return minimum(1 ./ rho_base) 
end

"""
Use this function to adjust the network parameters to the desired ρ⋆, and other parameters
"""
function set_scenario(net::NetworkParameters, rho_star::Float64; kappa::Float64 = 2.0, gamma_1::Float64 = 10^-8, R1::Float64 = 1-10^-8)
    kappa ≤ 1 && error("kappa is out of range")  
    (rho_star ≤ 0 || rho_star ≥ 1) && error("rho star is out of range")  
    (R1 ≤ 0 || R1 > 1) && error("R^1 is out of range")  
    net = @set net.gamma_1 = gamma_1
    net = @set net.gamma_2 = net.gamma_1 * R1/(1 - R1) # set gamma_2 based on given gamma_1 and R1
    net = @set net.kappa = kappa
    max_scaling = maximal_alpha_scaling(net)

    # max_scaling * ρstar is the scaling factor applied to the original alpha
    net = @set net.alpha_vector = net.alpha_vector*max_scaling*rho_star
    return net
end;

function plot_total_steady_state_mean_queues(scenarios::Vector{NetworkParameters}, gamma_1::Float64, R1::Float64, mode::Int = 0, kappa::Float64 = 2.0)
    title = ""
    if mode == 1
        title = "Always slow"
    elseif mode == 2
        title = "Always fast"
    else
        title = "Super fast"
    end
    rho_star_grid = 0.01:0.01:0.95
    plt = plot(xlabel = "rho star", ylabel = "Total steady state mean queue length", title = title)

    # For every scenario
    for (idx, scenario) in enumerate(scenarios)

        # Create a list to store plots
        scenario_means_list = Float64[]
        for rho_star in rho_star_grid

            # Instead of manually adjusting parameters for a given rho star in the test examples
            # we adjust for every rho star
            adjusted_net = set_scenario(scenario, rho_star; kappa = kappa, gamma_1 = gamma_1, R1 = R1)

            # Calculate lambda
            lambda = (I - adjusted_net.P') \ adjusted_net.alpha_vector

            # Calculate rho where rho_i = lambda_i/mu_i
            rho = lambda ./ averaged_service_rate(adjusted_net)
            
            # Sum all queue lengths for given scenario
            mean_over_all_queues_for_scenario = 0.0
            for queue_i in 1:adjusted_net.L
                mean_over_all_queues_for_scenario += rho[queue_i] / (1 - rho[queue_i])
            end

            push!(scenario_means_list, mean_over_all_queues_for_scenario)
        end
        plot!(plt, rho_star_grid, scenario_means_list, label = "scenario $(idx)")
    end
    display(plt)
end



"""
Runs a discrete event simulation of a Modulated Jackson Network `net` and produces traces of queue sizes and the `slow`-`fast` state.

The simulation runs from time `0` to `max_time`.  The simulation starts with empty queues and in `slow` modulation state.

The return value is a trace of the queue sizes of each of the individual stations ( (time, value) pairs). 
It is also a trace of the simulation state (`slow`/`fast`,time) pairs. 
The combination of all these traces can be plotted to reconstruct the simulation.

This simulation does NOT keep individual customers state, it only keeps the following minimal state: 
* The number of jobs in each queue.
* A boolean value indicating if `slow` or `fast` (for the whole network)
"""
function sim_net_trace(net::NetworkParameters; max_time = 10^2, seed::Int64 = 42)
    
    #Set the random seed
    Random.seed!(seed)
    
    time_traj = Float64[]
    queues_traj = Vector{Int}[]
    modulation_traj = Bool[]

    function record_traj(time::Float64, state::JacksonQueueNetworkState)
        push!(time_traj, time)
        push!(queues_traj, copy(state.queues))
        push!(modulation_traj, state.is_slow)
        return nothing
    end

    init_state = JacksonQueueNetworkState(fill(0, net.L), net, true, 0)

    # Was copying the tutorial but in our case, each queue has its own
    # arrival rate so we need to queue up arrivals for each queue
    init_timed_events = TimedEvent[]
    for queue_i in 1:net.L
        # If we were to add timed events for alpha_i = 0 then we would be 
        # recording events that litearally cannot take place
        if net.alpha_vector[queue_i] > 0
            push!(init_timed_events, TimedEvent(ExternalArrivalEvent(queue_i), next_arrival_duration(init_state, queue_i)))
        end
    end

    # Kickstart modulation 
    push!(init_timed_events, TimedEvent(Fast(), time_leave_slow(init_state)))

    do_sim(init_state, init_timed_events; max_time = max_time, call_back = record_traj)

    return time_traj, queues_traj, modulation_traj
end;

"""
Runs a discrete event simulation of a Modulated Jackson Network `net` and collects statistics during the run. Returns an estimate of the total mean queue length.

The simulation runs from time `0` to `max_time`.  The simulation starts with empty queues and in `slow` modulation state.

Statistics about the total mean queue lengths are recorded from `warm_up_time` onwards and the estimated value is returned. 

This simulation does NOT keep individual customers state, it only keeps the following minimal state: 
* The number of jobs in each queue.
* A boolean value indicating if `slow` or `fast` (for the whole network)
"""
function sim_net_estimation(net::NetworkParameters; max_time = 10^6, warm_up_time = 10^4, seed::Int64 = 42)::Float64
    
    #Set the random seed
    Random.seed!(seed)
    
    #The function would execute the simulation here - and this would use multiple other functions, types, and files
    queues_integral = zeros(net.L)
    last_time = 0.0

    # Just saying: Thank you to Alistair you are an edstem warrior
    # Your comment https://edstem.org/au/courses/24848/discussion/3022047
    # cleared up so much for me and helped me fix my cooked rel err graphs
    prev_states = zeros(net.L)

    """
    Cheeky docstring to explain whats going on (Ty Alistair)

    In the tut code (which is what was basically here), I did not have 
    a prev_states variable. This made the relative error graphs look crazy
    because what the old code was doing was as follows (thanks to sim logic)

    1) Get the current event at t = time 
    2) Update the system to reflect this process
    3) Call record_integral which computes CURRENT state relative to previous
       interval (basically new system/queue population multipled by the 
       slice of time in which the system had the CURRENT - 1 population)
    
    So all of that is wrong and now since we track the previous state of the 
    system, the integral doesn't overcount
    """
    function record_integral(time::Float64, state::JacksonQueueNetworkState)
        if time > warm_up_time
            queues_integral .+= prev_states .* (time - last_time)
        end
        last_time = time
        prev_states .= state.queues
        return nothing
    end

    # Start in slow
    init_state = JacksonQueueNetworkState(fill(0, net.L), net, true, 0)

    init_timed_events = TimedEvent[]
    for queue_i in 1:net.L
        if net.alpha_vector[queue_i] > 0
            push!(init_timed_events, TimedEvent(ExternalArrivalEvent(queue_i), 0.0))
        end
    end

    # If we start in slow (we do) then we have to start modulation
    push!(init_timed_events, TimedEvent(Fast(), time_leave_slow(init_state)))

    do_sim(init_state, init_timed_events; max_time = max_time, call_back = record_integral)

    estimated_total_mean_queue_length = sum(queues_integral) / (max_time - warm_up_time)

    return estimated_total_mean_queue_length
end;


end

