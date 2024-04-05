using CompilerExplorer: _generate_code, Arguments
using Test

@testset "CompilerExplorer" begin
    mktempdir() do dir
        @testset for format in ("lowered", "typed", "warntype", "llvm", "llvm-module", "native"),
                     optimize in (true, false),
                     verbose in (true, false),
                     input in ("axpy", "square")
            input_file = joinpath(@__DIR__, "input-$(input).jl")
            output_file = tempname(dir)
            debuginfo = :source
            args = Arguments(format, debuginfo, optimize, verbose, input_file, output_file)
            _generate_code(Module(), args; verbose_io=devnull)
            output_file = tempname(dir)
            @test success(`$(Base.julia_cmd()) --startup-file=no $(joinpath(@__DIR__, "julia_wrapper.jl")) $(input_file) $(output_file)`)
        end
    end
end
