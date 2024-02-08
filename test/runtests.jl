using CompilerExplorer: _generate_code, Arguments
using Test

@testset "CompilerExplorer" begin
    @testset for format in ("lowered", "typed", "warntype", "llvm", "native"), debuginfo in (:default, :none), optimize in (true, false), verbose in (true, false), input in ("axpy", "square")
        mktempdir() do dir
            input_file = joinpath(@__DIR__, "input-$(input).jl")
            output_file = tempname(dir)
            args = Arguments(format, debuginfo, optimize, verbose, input_file, output_file)
            _generate_code(Module(), args; verbose_io=devnull)
            first_line = readlines(output_file)[1]
            expected = if input == "axpy"
                r"^<\d+ \d+ axpy! Vector\{Float32\}, Float32, Vector\{Float32\}>$"
            elseif input == "square"
                r"^<\d+ \d+ square Int32>$"
            end
            @test !isnothing(match(expected, first_line))
            output_file = tempname(dir)
            @test success(`$(Base.julia_cmd()) --startup-file=no $(joinpath(@__DIR__, "julia_wrapper.jl")) $(input_file) $(output_file)`)
        end
    end
end
