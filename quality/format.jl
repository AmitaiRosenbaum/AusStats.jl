using JuliaFormatter

const ROOT = dirname(@__DIR__)
const FIX = "--fix" in ARGS

formatted = JuliaFormatter.format(ROOT; verbose=true, overwrite=FIX)

if !formatted
    if FIX
        @info "Formatted Julia files."
    else
        @error "Formatting check failed. Run `julia --project=quality quality/format.jl --fix`."
        exit(1)
    end
end
