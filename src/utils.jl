using Random, Distributions

"""

"""
function next_arrival_duration(s::JacksonQueueNetworkState, i::Int)
    return rand(Exponential(1 / s.params.alpha_vector[i]))
end

function next_service_duration(s::JacksonQueueNetworkState, i::Int)
    # As per assignment spec, when fast, service rate is scaled by kappa
    adjusted_service = 0.0
    if s.is_slow
        adjusted_service = 1.0
    else
        adjusted_service = s.params.kappa
    end
    blah = s.params.mu_vector[i] * adjusted_service
    return rand(Exponential(1 / blah))
end

"""
From STAT3004, in a CTMC the Sojourn times are distributed exponentially

So since mean of an exponentially distributed random variable is 1/ rate
We expect to leave slow to fast exp(1/gamma_1)
"""
function time_leave_slow(s::JacksonQueueNetworkState)
    return rand(Exponential(1 / s.params.gamma_1))
end

"""
From STAT3004, in a CTMC the Sojourn times are distributed exponentially

So since mean of an exponentially distributed random variable is 1/ rate
We expect to leave fast to slow exp(1/gamma_2)
"""
function time_leave_fast(s::JacksonQueueNetworkState)
    return rand(Exponential(1 / s.params.gamma_2))
end

