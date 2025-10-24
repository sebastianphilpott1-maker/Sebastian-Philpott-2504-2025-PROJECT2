# Activating and instantiating the script
using Pkg
using Plots
using Statistics
Pkg.activate(".")
Pkg.instantiate()

include("src/ModulatedJacksonSim.jl")

# Using calls
using LinearAlgebra, .ModulatedJacksonSim

# UNCOMMENT FOR LINE BELOW TO WHERE STATED FOR TASK 2
# Task two:
# scenario_list = [scenario1, scenario2, scenario3, scenario4]

# plot_total_steady_state_mean_queues(scenario_list, 10^-8, 1 - 10^-8, 1, 2.0)

# plot_total_steady_state_mean_queues(scenario_list, 1000.0, 10^-8, 2, 2.0)

# plot_total_steady_state_mean_queues(scenario_list, 10.0, 0.5, 67, 2.0)
# DON'T UNCOMMENT ME UNCOMMENT LINE ABOVE FOR TASK 3

# UNCOMMENT FROM LINE BELOW TO WHERE STATED FOR TASK 3
# Task 3 - Setting params, pulled R1 from nowhere
# gamma_1 = 0.10
# R1 = 0.67
# rho_star = 0.80
# scenarios = [set_scenario(scenario1, rho_star; kappa = 2.0, gamma_1 = gamma_1, R1 = R1), 
#              set_scenario(scenario2, rho_star; kappa = 2.0, gamma_1 = gamma_1, R1 = R1), 
#              set_scenario(scenario3, rho_star; kappa = 2.0, gamma_1 = gamma_1, R1 = R1)]

# # For each scenario, get the instance and store the index of the loop
# for (i, net) in enumerate(scenarios)

#     # Run sim, store time traj, queue length wrt time and modulation
#     # Note that I didn't know how to plot this properly so the trace is Three
#     # But looks god awful when plotted so I left it out
#     times, queues, modulation = sim_net_trace(net; max_time = 100.0, seed = 42)

#     plt = plot(xlabel = "Time", ylabel = "Queue size", title = "Scenario $(i)")
#     # just grab true length of any queue so we have something to loop over
#     L = length(queues[1])
#     for j in 1:L
#         yj = [queue[j] for queue in queues]
#         plot!(plt, times, yj; label = "q$(j)")
#     end
#     display(plt)
# end
# DON'T UNCOMMENT ME STOP ABOVE FOR TASK 3

# TASK 4 I AM A DUMB IDIOT AND MY TESTS ARE NOT FUNCTIONS
# THEY ARE JUST SCRIPTS SO YOU HAVE TO CALL THEM IN THE TEST FILE
# ITSELF I DONT KNOW WHY I DID THIS I WAS JUST TRYING TO GET SOMETHING
# WORKING ASAP SORRY


# Task 5 - Setting params
gamma_1 = 0.10
kappa = 2.0
R1_vals = [0.1, 0.2, 0.3, 0.4, 0.5, 0.9]

scenario_list = [scenario1, scenario2, scenario3, scenario4]
labels = ["scenario1", "scenario2", "scenario3", "scenario4"]

rho_star_grid = 0.1:0.01:0.90

# For each scenario
for (idx, scenario) in enumerate(scenario_list)

    # Make a matrix for the scenario to store values to plot
    # Rows = rho star vals, Cols = R1 vals
    ret_plot = zeros(length(rho_star_grid), length(R1_vals))

    # For each R1 val in the given scenario
    for (R1_val_index, R1_val) in enumerate(R1_vals)

        # For each rho star in the grid
        for (rho_star_idx, rho_star) in enumerate(rho_star_grid)

            # Set the scenario as per the params
            adjusted_scenario = set_scenario(scenario, rho_star; kappa = kappa, gamma_1 = gamma_1, R1 = R1_val)

            # Run the sim
            sim_est = sim_net_estimation(adjusted_scenario; max_time = 10^5.0, warm_up_time = 10^3.0, seed = 42)

            # Store values to plot
            # So each ret_plot[i, j] stores a value for scenario idx
            # evaluated at a given rho star and r1 val
            ret_plot[rho_star_idx, R1_val_index] = sim_est
        end
    end

    # After we have built a matrix of values to plot for a scenario
    # Make a plot for given scenario indexed by scenario idx
    plt = plot(; xlabel = "rho star", ylabel = "Estimated mean queue length", 
                title = "Quantifying modulation effect for $(labels[idx])")
    
    # On the plot created above for scenario idx, plot estimations evaluated
    # at some rho_star and some R1
    for (blah, R1_val) in enumerate(R1_vals)
        plot!(plt, rho_star_grid, ret_plot[:, blah], label = "R1 = $(R1_val)")
    end

    display(plt)

end
