import Base: isless
"""
A file containing the definition for events
"""
abstract type Event end


"""
An external arrival event 

Someone enters Dreamworld and immediately enters ride i for 1 <= i <= L
"""
struct ExternalArrivalEvent <: Event
    i::Int 
end

"""
An internal arrival event 

Someone within Dreamworld leaves ride i
"""
struct InternalArrivalEvent <: Event
    i::Int
end

"""
An end of service event

Someone within Dreamworld finishes on ride i

End of service events have a "version" which communicates
with the system state about what speed it was queued up with
"""
struct EndOfServiceAtQueueEvent <: Event
    i::Int
    version::Int
end

#Generic events that we can always use
struct EndSimEvent <: Event end
struct LogStateEvent <: Event end

"""
An event that has its time recorded
"""
struct TimedEvent
    event::Event
    time::Float64
end


struct Fast <: Event end
struct Slow <: Event end

# Comparison of two timed events - this will allow us to use them in a heap/priority-queue
isless(te1::TimedEvent, te2::TimedEvent) = te1.time < te2.time