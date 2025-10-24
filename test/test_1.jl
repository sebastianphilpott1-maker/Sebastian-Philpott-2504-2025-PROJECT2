# Activating and instantiating the script
using Pkg
using Random
using LinearAlgebra
using Plots
using Statistics

Pkg.activate(".")
Pkg.instantiate()

include("../src/ModulatedJacksonSim.jl")

using .ModulatedJacksonSim

# Always slow modulation
gamma_1 = 10^-8
R1 = 1 - 10^-8

# Scenario list and labels for plotting ease
scenario_list = [scenario1, scenario2, scenario3, scenario4]
labels = ["scenario1", "scenario2", "scenario3", "scenario4"]

# Compute the theoretical mean queue length - CHANGE NAME BUDDY
function jackson_thing(net::NetworkParameters)
    lambda = (I - net.P') \ net.alpha_vector
    rho = lambda ./ net.mu_vector
    sum(rho ./ (1 .- rho))
end


rho_star_grid = 0.1:0.01:0.90
# For each scenario
for (idx, scenario) in enumerate(scenario_list)

    # Arrays for the values to store
    simulated_vals = zeros(length(rho_star_grid))
    theoretical_vals = zeros(length(rho_star_grid))

    # For each rho star, we adjust the scenario and run the sim
    for (rho_star_idx, rho_star) in enumerate(rho_star_grid)
        adjusted_net = set_scenario(scenario, rho_star; kappa = 2.0, gamma_1 = gamma_1, R1 = R1)

        # Making warm up time and max_time a bit lower because it takes 9 years to run
        simulation_est = sim_net_estimation(adjusted_net; max_time = 10^6.0, warm_up_time = 10^4.0, seed = 42)

        # Get the theoretical mean
        theoretical_mean = jackson_thing(adjusted_net)

        # For each rho_star, store the estimate and theoretical mean
        simulated_vals[rho_star_idx] = simulation_est
        theoretical_vals[rho_star_idx] = theoretical_mean
    end

    # Plot the theoretical means for each rho star
    plt1 = plot(rho_star_grid, theoretical_vals; label = "theory (always slow)", 
                xlabel = "rho star", ylabel = "Total mean queue length", 
                title = "Sim vs Theory — $(labels[idx])")
    
    # Plot estimated means
    plot!(plt1, rho_star_grid, simulated_vals; label = "Simulation")

    display(plt1)

    # Calc the relative errors element wise
    relative_errors = abs.((simulated_vals .- theoretical_vals) ./ theoretical_vals)
    plt2 = plot(rho_star_grid, relative_errors, label = "abs relative error always slow",  
                xlabel = "rho star", ylabel = "Relative errors",  
                title = "Sim vs Theory errors - $(labels[idx])")

    display(plt2)
end
