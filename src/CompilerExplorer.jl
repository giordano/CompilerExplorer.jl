module CompilerExplorer

const doc = """Julia wrapper.

Usage:
  julia_wrapper.jl <input_code> <output_path> [--format=<fmt>] [--debuginfo=<info>] [--optimize=<opt>] [--verbose]
  julia_wrapper.jl --help

Options:
  -h --help                Show this screen.
  --format=<fmt>           Set output format (One of "lowered", "typed", "warntype", "llvm", "native") [default: native]
  --debuginfo=<info>       Controls amount of generated metadata (One of "default", "none") [default: default]
  --optimize={true*|false} Controls whether "llvm" or "typed" output should be optimized or not [default: true]
  --verbose                Prints some process info
"""

using InteractiveUtils

struct Arguments
    format::String
    debuginfo::Symbol
    optimize::Bool
    verbose::Bool
    input_file::String
    output_path::String
end

function parse_arguments(ARGS)
    if first(ARGS) == "--"
        popfirst!(ARGS)
    end

    format = "native"
    debuginfo = :default
    optimize = true
    verbose = false
    show_help = false
    arg_parser_error = false
    positional_ARGS = String[]

    for x in ARGS
        if startswith(x, "--format=")
            format = x[10:end]
        elseif startswith(x, "--debuginfo=")
            if x[13:end] == "none"
                debuginfo = :none
            end
        elseif startswith(x, "--optimize=")
            # Do not error out if we can't parse the option
            optimize = something(tryparse(Bool, x[12:end]), true)
        elseif x == "--verbose"
            verbose = true
        elseif x == "--help" || x == "-h"
            show_help = true
        elseif !startswith(x, "-")
            push!(positional_ARGS, x)
        else
            arg_parser_error = true
            println("Unknown argument ", x)
        end
    end

    if show_help
        println(doc)
        exit(Int(arg_parser_error)) # exit(1) if failed to parse
    end

    if length(positional_ARGS) != 2
        arg_parser_error = true
        println("Expected two position args", positional_ARGS)
    end

    if arg_parser_error
        println(doc)
        exit(1)
    end

    input_file = popfirst!(positional_ARGS)
    output_path = popfirst!(positional_ARGS)

    return Arguments(format, debuginfo, optimize, verbose, input_file, output_path)
end

function _main(m::Module, args::Arguments; verbose_io::IO=stdout)
    # Include user code into module
    Base.include(m, args.input_file)

    # Find functions and method specializations
    m_methods = Any[]
    for name in names(m, all=true, imported=true)
        local fun = getfield(m, name)
        if fun isa Function
            if args.verbose
                println(verbose_io, "Function: ", fun)
            end
            # only show methods found in input module
            for me in methods(fun, m)
                # In julia v1.7-1.9 `me.specializations` is always a `Core.SimpleVector`, but in
                # Julia v1.10+ it can also be a single instance of `Core.MethodInstance`, which
                # isn't iterable, so we put it in a tuple to be able to do the for loop below.
                specs = if me.specializations isa Core.SimpleVector
                    me.specializations
                elseif me.specializations isa Core.MethodInstance
                    (me.specializations,)
                else
                    error("Cannot handle specializations of type $(typeof(me.specializations))")
                end
                for s in specs
                    if s != nothing
                        spec_types = s.specTypes
                        # In case of a parametric type, see https://docs.julialang.org/en/v1/devdocs/types/#UnionAll-types
                        while typeof(spec_types) == UnionAll
                            spec_types = spec_types.body
                        end
                        me_types = getindex(spec_types.parameters, 2:length(spec_types.parameters))
                        push!(m_methods, (fun, me_types, me))
                        if args.verbose
                            println(verbose_io, "    Method types: ", me_types)
                        end
                    end
                end
            end
        end
    end

    # open output file
    open(args.output_path, "w") do io
        # For all found methods
        for (me_fun, me_types, me) in m_methods
            io_buf = IOBuffer() # string buffer
            if args.format == "typed"
                ir, retval = InteractiveUtils.code_typed(me_fun, me_types; optimize=args.optimize, debuginfo=args.debuginfo)[1]
                Base.IRShow.show_ir(io_buf, ir)
            elseif args.format == "lowered"
                cl = Base.code_lowered(me_fun, me_types; debuginfo=args.debuginfo)
                print(io_buf, cl)
            elseif args.format == "llvm"
                InteractiveUtils.code_llvm(io_buf, me_fun, me_types; optimize=args.optimize, debuginfo=args.debuginfo)
            elseif args.format == "native"
                InteractiveUtils.code_native(io_buf, me_fun, me_types; debuginfo=args.debuginfo)
            elseif args.format == "warntype"
                InteractiveUtils.code_warntype(io_buf, me_fun, me_types; debuginfo=args.debuginfo)
            end
            code = String(take!(io_buf))
            line_num = count("\n",code)
            # Print first line: <[source code line] [number of output lines] [function name] [method types]>
            print(io, "<")
            print(io, me.line)
            print(io, " ")
            print(io, line_num)
            print(io, " ")
            print(io, me_fun)
            print(io, " ")
            print(io, join(me_types, ", "))
            println(io, ">")
            # Print code for this method
            println(io, code)
        end
    end
end

function main()
    _main(Module(:Godbolt), parse_arguments(ARGS))
    exit(0)
end

precompile(_main, (Module, Arguments))

end
