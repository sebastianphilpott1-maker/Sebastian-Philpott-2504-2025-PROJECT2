using Random, Distributions, DataStructures, StatsBase


# This is an abstract function 
"""
It will generally be called as 
new_timed_events = process_event(time, state, event)
It will generate 0 or more new timed events based on the current event
"""
function process_event end

# copied tute code genuinely don't know if I need this or not
function process_event(time::Float64, state::JacksonQueueNetworkState, es_event::EndSimEvent)
    return TimedEvent[]
end

function process_event(time::Float64, state::JacksonQueueNetworkState, ls_event::LogStateEvent)
    return TimedEvent[]
end;

"""
Handles turning the system slow to fast
"""
function process_event(time::Float64, state::JacksonQueueNetworkState, fast_event::Fast)
    new_timed_events = TimedEvent[]

    # Change the system version
    state.mod_version += 1

    # We are going fast now
    state.is_slow = false

    for queue_i in 1:state.params.L

        # For each queue that has a job in progress
        if state.queues[queue_i] > 0

            # push a new event at this queue and imbue the event with the
            # updated system version
            push!(new_timed_events, 
            TimedEvent(EndOfServiceAtQueueEvent(queue_i, state.mod_version), 
            time + next_service_duration(state, queue_i)))
        end
    end

    # Prepare next modulation change
    # Since we now in fast state, queue up the time we leave this state
    push!(new_timed_events, TimedEvent(Slow(), time + time_leave_fast(state)))

    return new_timed_events
end

"""
Ditto above but for fast to slow

Same version logic above
"""
function process_event(time::Float64, state::JacksonQueueNetworkState, slow_event::Slow)
    new_timed_events = TimedEvent[]
    state.mod_version += 1

    # We are going slow now
    state.is_slow = true

    for queue_i in 1:state.params.L
        if state.queues[queue_i] > 0
            push!(new_timed_events, TimedEvent(EndOfServiceAtQueueEvent(queue_i, state.mod_version), time + next_service_duration(state, queue_i)))
        end
    end

    # Prepare next modulation change
    # Since we now in slow state, queue up the time we leave this state
    push!(new_timed_events, TimedEvent(Fast(), time + time_leave_slow(state)))

    return new_timed_events
end



"""
A function that can process an external arrival
"""
function process_event(time::Float64, state::JacksonQueueNetworkState, external_arrival_event::ExternalArrivalEvent)
    i = external_arrival_event.i

    # Someone will arrive to queue i, rather than the first
    state.queues[i] += 1
    new_timed_events = TimedEvent[]

    # Prepare next arrival
    push!(new_timed_events, TimedEvent(ExternalArrivalEvent(i), time + next_arrival_duration(state, i)))

    # If this is the only person in queue i 
    if state.queues[i] == 1

        # Make sure we imbue this job with the current mod version
        push!(new_timed_events, 
        TimedEvent(EndOfServiceAtQueueEvent(i, state.mod_version), 
        time + next_service_duration(state, i)))
    end

    return new_timed_events
end

"""
A function that can process an internal arrival
"""
function process_event(time::Float64, state::JacksonQueueNetworkState, internal_arrival_event::InternalArrivalEvent)
    i = internal_arrival_event.i

    # Someone - or something - has moved to queue i
    state.queues[i] += 1
    new_timed_events = TimedEvent[]

    # Sanity comment: We don't prepare a new arrival
    # This is because the system says nothing about someone leaving queue i 
    # for queue i means someone must replace the lost spot in queue i 

    # If this is the only person in queue i
    if state.queues[i] == 1
        push!(new_timed_events, 
        TimedEvent(EndOfServiceAtQueueEvent(i, state.mod_version), 
        time + next_service_duration(state, i)))
    end

    return new_timed_events
end

"""
A function that can process the completion of a job at queue i

The way this version stuff works is that say we have a job in a queue
We start processing it, but the system modulates. mod_ver += 1

We start processing the same event but with the new rate.
Again, if the system modulates again, push the same event with new version

Say we finally process the event to completion. We check system version.
If 2 = current job version, we proceed with the rest of the code

If the event version doesn't match the current mod_ver then the event has
an incorrect service duration and is ignored BUT the event will complete
at some point when the versions match
"""
function process_event(time::Float64, state::JacksonQueueNetworkState, end_of_service_event::EndOfServiceAtQueueEvent)
    # If the thing we have popped from the pq and are looking at
    # has a version mismatch, we are yet to/already have processed
    # the correct version of this event and so we ignore it
    if end_of_service_event.version != state.mod_version
        return TimedEvent[]
    end 
    i = end_of_service_event.i
    new_timed_events = TimedEvent[]

    # A job at queue i has been completed so the length reduces by 1
    state.queues[i] -= 1
    @assert state.queues[i] >= 0

    # If there is still jobs to be complete in queue i, start processing
    if state.queues[i] >= 1
        push!(new_timed_events, TimedEvent(EndOfServiceAtQueueEvent(i, state.mod_version), time + next_service_duration(state, i)))
    end

    # https://juliastats.org/StatsBase.jl/v0.30/sampling/#StatsBase.sample

    # Probability of staying in the network
    stay_prob = sum(state.params.P[i, :])

    # -1 signifies we leave
    possible_visits = [-1]

    # For each queue, note all the possible (all of them, maybe) locations
    # we can go to
    for queue in 1:state.params.L
        push!(possible_visits, queue)
    end

    # As per the spec
    leave_prob = 1 - stay_prob

    # Make a list of all the weighted probabilities of going to i, j
    probabilities = [leave_prob]
    for queue in 1:state.params.L
        push!(probabilities, state.params.P[i, queue])
    end

    # Where we decided to go
    j = sample(possible_visits, Weights(probabilities))

    # If we didnt leave, then we went to the sampled location
    if j != -1
        state.queues[j] += 1

        # If the queue wasn't busy before, we need to make it busy
        if state.queues[j] == 1
            push!(new_timed_events, TimedEvent(EndOfServiceAtQueueEvent(j, state.mod_version), time + next_service_duration(state, j)))
        end
    end

    return new_timed_events
end

"""
My understanding is that we need a vector of timed events for init_timed_event
since we have queues and not a single queue compared to the tute

Basically copied the tute code as per Yonis explainer video 
"""
function do_sim(init_state::JacksonQueueNetworkState, 
                init_timed_event::Vector{TimedEvent}; 
                max_time::Float64 = 10.0, 
                log_times::Vector{Float64} = Float64[],
                call_back = (time, state) -> nothing)

    #The event queue
    priority_queue = BinaryMinHeap{TimedEvent}()

    # Put the standard events in the queue
    for events in init_timed_event
        push!(priority_queue, events)
    end
    
    push!(priority_queue, TimedEvent(EndSimEvent(), max_time))
    for lt in log_times
        push!(priority_queue, TimedEvent(LogStateEvent(), lt))
    end

    #initilize the state
    state = deepcopy(init_state)
    time = 0.0

    call_back(time, state)

    #The main discrete event simulation loop - SIMPLE!
    while true
        #Get the next event
        timed_event = pop!(priority_queue)

        #advance the time
        time = timed_event.time

        #Act on the event
        new_timed_events = process_event(time, state, timed_event.event) 

        #if the event was an end of simulation then stop
        isa(timed_event.event, EndSimEvent) && break 

        #The event may spawn 0 or more events which we put in the priority queue 
        for nte in new_timed_events
            push!(priority_queue, nte)
        end

        call_back(time, state)
    end
end;

