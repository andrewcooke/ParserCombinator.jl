

# transform successes (Empty and Value)
# function must return a Value instance

@auto_hash_equals mutable struct Transform<:Delegate
    name::Symbol
    matcher::Matcher
    f::Function
    Transform(matcher, f) = new(:Transform, matcher, f)
end

@auto_hash_equals struct TransformState<:DelegateState
    state::State
end

always_print(::Transform) = false

# execute and failure come from Delegate

success(k::Config, m::Transform, s, t, i, r::Value) = Success(TransformState(t), i, m.f(r))


# as above, but function also takes iterator

@auto_hash_equals mutable struct ITransform<:Delegate
    name::Symbol
    matcher::Matcher
    f::Function
    ITransform(matcher, f) = new(:ITransform, matcher, f)
end

@auto_hash_equals struct ITransformState<:DelegateState
    state::State
end

always_print(::ITransform) = false

success(k::Config, m::ITransform, s, t, i, r::Value) = Success(ITransformState(t), i, m.f(i, r))



# simplified versions for transforming Success (remove and re-add the
# Success wrapper).

Appl(m::Matcher, f::Applicable) = Transform(m, x -> Any[f(x)])

function App(m::Matcher, f::Applicable)
    if f == vcat
        Transform(m, x -> Any[x])
    else
        Transform(m, x -> Any[f(x...)])
    end
end

IAppl(m::Matcher, f::Applicable) = ITransform(m, (i, x) -> Any[f(i, x)])

function IApp(m::Matcher, f::Applicable)
    ITransform(m, (i, x) -> Any[f(i, x...)])
end
