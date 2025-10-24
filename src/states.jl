"""
Master file for jackson state event related stuff
"""
abstract type State end

mutable struct JacksonQueueNetworkState
    queues::Vector{Int}
    params::NetworkParameters
    is_slow::Bool
    mod_version::Int
end

