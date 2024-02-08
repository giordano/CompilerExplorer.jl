## CompilerExplorer.jl

This package is to be used to power the Julia compiler wrapper in [Compiler
Explorer](https://godbolt.org/).  The code of Compiler Explorer is maintained at
<https://github.com/compiler-explorer/compiler-explorer>.

The only public function of this package is `CompilerExplorer.generate_code()`,
it doesn't take any argument but it's supposed to be called in a script which
receives specific arguments, read its docstring for the usage.
