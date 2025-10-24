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

# Super fast modulation
gamma_1 = 10.0
R1 = 0.5

scenario_list = [scenario1, scenario2, scenario3, scenario4]
labels = ["scenario1", "scenario2", "scenario3", "scenario4"]

function jackson_thing(net::NetworkParameters)
    lambda = (I - net.P') \ net.alpha_vector
    average_mu = averaged_service_rate(net)
    rho = lambda ./ average_mu
    sum(rho ./ (1 .- rho))
end


rho_star_grid = 0.1:0.01:0.90
for (idx, scenario) in enumerate(scenario_list)
    simulated_vals = zeros(length(rho_star_grid))
    theoretical_vals = zeros(length(rho_star_grid))
    for (rho_star_idx, rho_star) in enumerate(rho_star_grid)
        adjusted_net = set_scenario(scenario, rho_star, kappa = 2.0, gamma_1 = gamma_1, R1 = R1)
        simulation_est = sim_net_estimation(adjusted_net, max_time = 10^5.0, warm_up_time = 10^3.0, seed = 42)

        theoretical_mean = jackson_thing(adjusted_net)

        simulated_vals[rho_star_idx] = simulation_est
        theoretical_vals[rho_star_idx]  = theoretical_mean
    end


    plt1 = plot(rho_star_grid, theoretical_vals; label = "theory (Super fast)",
                xlabel = "rho star", ylabel = "Total mean queue length",
                title = "Sim vs Theory — $(labels[idx])")
    plot!(plt1, rho_star_grid, simulated_vals; label = "Simulation")

    display(plt1)

    relative_errors = abs.((simulated_vals .- theoretical_vals) ./ theoretical_vals)
    plt2 = plot(rho_star_grid, relative_errors, label = "abs relative error super fast", 
                xlabel = "rho star", ylabel = "Relative errors", 
                title = "Sim vs Theory super fast errors - $(labels[idx])")

    display(plt2)
end