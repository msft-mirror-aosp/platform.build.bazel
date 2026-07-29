#!/usr/bin/env python3
"""Parses run-time CPU detection (RTCD) definitions to generate C header files.

This script replaces the original perl-based rtcd.pl compiler in the libvpx
Bazel build workflow. It compiles the DSL from .pl configuration files
(e.g., vp8_rtcd_defs.pl) into Python syntax dynamically, executes it within
a mock Perl bareword-compatible sandbox, and outputs C function declarations,
typedefs, and optimized pointer initialization logic.
"""

import sys
import re
import argparse
from typing import Dict, List, Set, Any, Optional


class BarewordDict(dict):
    """A dictionary wrapper used to emulate Perl's bareword string behavior.

    Under Perl's `no strict 'refs'`, accessing an undefined variable evaluates to
    its own name as a string (bareword). In Python, this causes a NameError.
    By mapping globals to a BarewordDict during exec(), undefined names evaluate
    to their own name as a string, letting the evaluated Perl DSL code run cleanly.
    """

    def __getitem__(self, key: str) -> Any:
        try:
            return super().__getitem__(key)
        except KeyError:
            return key


# DSL compilation state variables
ALL_FUNCS: Dict[str, Dict[str, Any]] = (
    {}
)  # Maps: fn -> { 'rtyp': ..., 'args': ..., 'specializations': {}, 'default': None, 'links': {}, 'indirect': False }
ALL_FORWARD_DECLS: List[Any] = []
disabled: Set[str] = set()
required: Set[str] = set()
config: Dict[str, str] = {}
opts: Dict[str, str] = {}


def aom_config(key: str) -> str:
    """Retrieves a value from the build's configuration settings."""
    val = config.get(key, "")
    if val == "1":
        return "yes"
    if val == "0":
        return "no"
    return val


def add_proto(*args: Any) -> None:
    """Registers a C function prototype with its return type and arguments.

    Invoked by the compiled DSL files (e.g. add_proto qw/void vp8_dequantize_b/, ...).
    """
    fn = args[-2]
    rtyp = " ".join(args[:-2])
    func_args = args[-1]
    ALL_FUNCS[fn] = {
        "rtyp": rtyp,
        "args": func_args,
        "specializations": {},
        "default": None,
        "links": {},
        "indirect": False,
    }
    specialize(fn, "c")


def specialize(fn: str, *opts_list: str) -> None:
    """Registers optimized target specializations for a registered function.

    Invoked by the compiled DSL files (e.g. specialize qw/vp8_dequantize_b mmx neon .../).
    """
    if fn not in ALL_FUNCS:
        return
    for opt in opts_list:
        if not opt:
            continue
        ALL_FUNCS[fn]["specializations"][opt] = f"{fn}_{opt}"


def forward_decls(*funcs: Any) -> None:
    """Registers forward declaration generator subroutines to run during output generation."""
    for func in funcs:
        ALL_FORWARD_DECLS.append(func)


def require(*opts_list: str) -> None:
    """Selects the best available implementation for each function.

    When an optimized instruction set (like sse2) is required/target compiled,
    this updates each function's default pointer to use the SSE2 specialization and
    unlinks lower-priority versions (like C).
    """
    for fn in ALL_FUNCS:
        for opt in opts_list:
            if opt in ALL_FUNCS[fn]["specializations"]:
                ofn = ALL_FUNCS[fn]["specializations"][opt]
                best = ALL_FUNCS[fn]["default"]
                if best:
                    for prev_opt, prev_fn in ALL_FUNCS[fn]["specializations"].items():
                        if prev_fn == best:
                            ALL_FUNCS[fn]["links"][prev_opt] = False
                ALL_FUNCS[fn]["default"] = ofn
                ALL_FUNCS[fn]["links"][opt] = True


def get_specialization_value(fn: str, opt: str, local_vars: Dict[str, Any]) -> str:
    """Helper to retrieve the resolved symbol name for a specialization."""
    var_name = f"{fn}_{opt}"
    if var_name in local_vars:
        return local_vars[var_name]
    return var_name


def determine_indirection(*archs: str, local_vars: Dict[str, Any]) -> None:
    """Determines if a function needs dynamic dispatch via pointer or static mapping.

    If only one implementation is linked/compiled (e.g. when static compiling for
    a specific ISA), the function is statically mapped using a preprocessor #define.
    Otherwise, a dynamic function pointer is declared.
    """
    if aom_config("CONFIG_RUNTIME_CPU_DETECT") != "yes":
        require(*archs)

    for fn, info in ALL_FUNCS.items():
        n = 0
        for opt in archs:
            if opt in info["specializations"]:
                link = info["links"].get(opt, False)
                if link and link != "false":
                    n += 1
        if n == 1:
            info["indirect"] = False
        else:
            info["indirect"] = True


def declare_function_pointers(*archs: str, local_vars: Dict[str, Any]) -> None:
    """Prints extern pointer declarations or static preprocessor #defines for functions."""
    for fn in sorted(ALL_FUNCS.keys()):
        info = ALL_FUNCS[fn]
        rtyp = info["rtyp"]
        args = info["args"]

        dfn = info["default"]
        if dfn in local_vars:
            dfn = local_vars[dfn]

        for opt in archs:
            if opt in info["specializations"]:
                ofn = get_specialization_value(fn, opt, local_vars)
                print(f"{rtyp} {ofn}({args});")

        if not info["indirect"]:
            print(f"#define {fn} {dfn}")
        else:
            print(f"RTCD_EXTERN {rtyp} (*{fn})({args});")
        print()


def set_function_pointers(*archs: str, local_vars: Dict[str, Any]) -> None:
    """Prints the C init statements assigning function pointers at runtime."""
    for fn in sorted(ALL_FUNCS.keys()):
        info = ALL_FUNCS[fn]
        dfn = info["default"]
        if dfn in local_vars:
            dfn = local_vars[dfn]

        if info["indirect"]:
            print(f"    {fn} = {dfn};")
            for opt in archs:
                if opt in info["specializations"]:
                    ofn = get_specialization_value(fn, opt, local_vars)
                    if ofn == dfn:
                        continue
                    link = info["links"].get(opt, False)
                    if link and link != "false":
                        cond = f"have_{opt}"
                        cond_val = local_vars.get(cond, "")
                        print(f"    if ({cond_val}) {fn} = {ofn};")


def filter_opts(*args: str) -> List[str]:
    """Filters out cpu targets that have been disabled via flags."""
    return [opt for opt in args if opt not in disabled]


def common_top(sym: str, archs: List[str], local_vars: Dict[str, Any]) -> None:
    """Outputs the top segment of the generated RTCD C header file."""
    include_guard = sym.upper() + "_H_"
    print(f"""
// This file is generated. Do not edit.
#ifndef {include_guard}
#define {include_guard}

#ifdef RTCD_C
#define RTCD_EXTERN
#else
#define RTCD_EXTERN extern
#endif
""")
    for func_name in ALL_FORWARD_DECLS:
        fn_val = local_vars[func_name]
        if callable(fn_val):
            fn_val()

    print("""
#ifdef __cplusplus
extern "C" {
#endif
""")
    declare_function_pointers("c", *archs, local_vars=local_vars)
    print(f"void {sym}(void);")
    print()


def common_bottom(sym: str) -> None:
    """Outputs the bottom segment of the generated RTCD C header file."""
    include_guard = sym.upper() + "_H_"
    print(f"""
#ifdef __cplusplus
}}  // extern "C"
#endif

#endif  // {include_guard}""")


def x86(archs: List[str], sym: str, local_vars: Dict[str, Any]) -> None:
    """Outputs the initialization logic segment for x86 architectures."""
    determine_indirection("c", *archs, local_vars=local_vars)
    for opt in archs:
        local_vars[f"have_{opt}"] = f"flags & HAS_{opt.upper()}"
    common_top(sym, archs, local_vars)
    print(f"""#ifdef RTCD_C
#include "aom_ports/x86.h"
static void setup_rtcd_internal(void)
{{
    int flags = x86_simd_caps();

    (void)flags;
""")
    set_function_pointers("c", *archs, local_vars=local_vars)
    print("""}
#endif""")
    common_bottom(sym)


def arm(archs: List[str], sym: str, local_vars: Dict[str, Any]) -> None:
    """Outputs the initialization logic segment for ARM architectures."""
    determine_indirection("c", *archs, local_vars=local_vars)
    for opt in archs:
        opt_uc = opt.upper()
        if opt == "neon_asm":
            opt_uc = "NEON"
        local_vars[f"have_{opt}"] = f"flags & HAS_{opt_uc}"
    common_top(sym, archs, local_vars)
    print(f"""#include "config/aom_config.h"

#ifdef RTCD_C
#include "aom_ports/arm.h"
static void setup_rtcd_internal(void)
{{
    int flags = aom_arm_cpu_caps();

    (void)flags;
""")
    set_function_pointers("c", *archs, local_vars=local_vars)
    print("""}
#endif""")
    common_bottom(sym)


def mips(archs: List[str], sym: str, local_vars: Dict[str, Any]) -> None:
    """Outputs the initialization logic segment for MIPS architectures."""
    determine_indirection("c", *archs, local_vars=local_vars)
    for opt in archs:
        local_vars[f"have_{opt}"] = f"flags & HAS_{opt.upper()}"
    common_top(sym, archs, local_vars)
    print(f"""#include "vpx_config.h"

#ifdef RTCD_C
#include "vpx_ports/mips.h"
static void setup_rtcd_internal(void)
{{
    int flags = mips_cpu_caps();

    (void)flags;
""")
    set_function_pointers("c", *archs, local_vars=local_vars)
    print("""#if HAVE_DSPR2
void vpx_dsputil_static_init();
#if CONFIG_VP8
void dsputil_static_init();
#endif

vpx_dsputil_static_init();
#if CONFIG_VP8
dsputil_static_init();
#endif
#endif
}
#endif""")
    common_bottom(sym)


def ppc(archs: List[str], sym: str, local_vars: Dict[str, Any]) -> None:
    """Outputs the initialization logic segment for PowerPC architectures."""
    determine_indirection("c", *archs, local_vars=local_vars)
    for opt in archs:
        local_vars[f"have_{opt}"] = f"flags & HAS_{opt.upper()}"
    common_top(sym, archs, local_vars)
    print(f"""#include "config/aom_config.h"

#ifdef RTCD_C
#include "aom_ports/ppc.h"
static void setup_rtcd_internal(void)
{{
    int flags = ppc_simd_caps();
    (void)flags;""")
    set_function_pointers("c", *archs, local_vars=local_vars)
    print("""}
#endif""")
    common_bottom(sym)


def loongarch(archs: List[str], sym: str, local_vars: Dict[str, Any]) -> None:
    """Outputs the initialization logic segment for LoongArch architectures."""
    determine_indirection("c", *archs, local_vars=local_vars)
    for opt in archs:
        local_vars[f"have_{opt}"] = f"flags & HAS_{opt.upper()}"
    common_top(sym, archs, local_vars)
    print(f"""#include "vpx_config.h"

#ifdef RTCD_C
#include "vpx_ports/loongarch.h"
static void setup_rtcd_internal(void)
{{
    int flags = loongarch_cpu_caps();

    (void)flags;""")
    set_function_pointers("c", *archs, local_vars=local_vars)
    print("""}
#endif""")
    common_bottom(sym)


def riscv(archs: List[str], sym: str, local_vars: Dict[str, Any]) -> None:
    """Outputs the initialization logic segment for RISC-V architectures."""
    determine_indirection("c", *archs, local_vars=local_vars)
    for opt in archs:
        local_vars[f"have_{opt}"] = f"flags & HAS_{opt.upper()}"
    common_top(sym, archs, local_vars)
    print(f"""#ifdef RTCD_C
#include "aom_ports/riscv.h"
static void setup_rtcd_internal(void)
{{
    int flags = riscv_simd_caps();

    (void)flags;
""")
    set_function_pointers("c", *archs, local_vars=local_vars)
    print("""}
#endif""")
    common_bottom(sym)


def unoptimized(archs: List[str], sym: str, local_vars: Dict[str, Any]) -> None:
    """Outputs the static C-only fallback initialization logic segment."""
    determine_indirection("c", local_vars=local_vars)
    common_top(sym, archs, local_vars)
    print(f"""#include "config/aom_config.h"

#ifdef RTCD_C
static void setup_rtcd_internal(void)
{{""")
    set_function_pointers("c", local_vars=local_vars)
    print("""}
#endif""")
    common_bottom(sym)


def compile_perl_to_python(content: str) -> str:
    """Translates the Perl RTCD DSL source file format into executable Python code.

    Processes subroutines, print heredocs, Perl operators, variables, lists, and block braces,
    translating them statement by statement to be safely executed using Python's exec().
    """
    raw_lines = content.splitlines()
    lines = []
    current_statement = ""
    in_heredoc = False

    for line in raw_lines:
        stripped = line.strip()
        if in_heredoc:
            lines.append(line)
            if stripped == "EOF":
                in_heredoc = False
            continue
        if "print <<EOF" in stripped:
            in_heredoc = True
            if current_statement:
                lines.append(current_statement)
                current_statement = ""
            lines.append(line)
            continue
        if stripped.startswith("#"):
            # Skip comments in the middle of a multiline statement
            if not current_statement:
                lines.append(line)
            continue
        if not stripped:
            continue

        if current_statement:
            current_statement += " " + stripped
        else:
            current_statement = line

        check_stmt = current_statement
        if "#" in check_stmt:
            check_stmt = check_stmt.split("#", 1)[0]
        check_stmt = check_stmt.strip()

        if check_stmt.endswith(";") or check_stmt.endswith("{") or check_stmt.endswith("}") or check_stmt == "1;":
            lines.append(current_statement)
            current_statement = ""

    if current_statement:
        lines.append(current_statement)

    py_lines: List[str] = []
    indent = 0

    state = "NORMAL"
    sub_name = ""
    heredoc_lines: List[str] = []

    for line in lines:
        stripped = line.strip()

        if state == "NORMAL":
            # Match sub name() {
            if re.match(r"^sub\s+(\w+)\(\)\s*\{", stripped):
                sub_name = re.match(r"^sub\s+(\w+)\(\)\s*\{", stripped).group(1)
                state = "SUB"
                continue

            if not stripped:
                py_lines.append("")
                continue
            if stripped.startswith("#"):
                py_lines.append(" " * indent + line)
                continue
            if stripped == "1;":
                continue

            t_line = line.strip()
            # Translate Perl regex matches =~ and !~
            t_line = re.sub(r"(\S+)\s*=~\s*/([^/]+)/", r're.search(r"\2", \1)', t_line)
            t_line = re.sub(r"(\S+)\s*!~\s*/([^/]+)/", r'not re.search(r"\2", \1)', t_line)

            # Operator replacements
            t_line = re.sub(r"\beq\b", "==", t_line)
            t_line = re.sub(r"\bne\b", "!=", t_line)
            t_line = re.sub(r"\|\|", " or ", t_line)
            t_line = re.sub(r"&&", " and ", t_line)
            t_line = re.sub(r"!(?![=~])", "not ", t_line)
            t_line = re.sub(r"\b&(\w+)\b", r"\1", t_line)
            t_line = re.sub(r"aom_config", r"aom_config", t_line)
            t_line = re.sub(r"\$opts\{(\w+)\}", r"opts['\1']", t_line)
            t_line = re.sub(r"\$\{(\w+)\}", r"{\1}", t_line)
            t_line = re.sub(r"\$(\w+)", r"\1", t_line)
            t_line = re.sub(r"@(\w+)", r"\1", t_line)
            t_line = re.sub(r'"([^"]*?{[^"]*?}[^"]*?)"', r'f"\1"', t_line)

            # Translate Perl my keyword and foreach loops
            t_line = re.sub(r"\bmy\s+", "", t_line)
            t_line = re.sub(r"\bforeach\s+(\w+)\s*\((.*?)\)", r"for \1 in \2", t_line)
            t_line = re.sub(r"\bforeach\s*\((.*?)\)", r"for _ in \1", t_line)

            # Translate Perl empty lists, if statement modifiers, and push functions
            t_line = re.sub(r"(\w+)\s*=\s*\(\);?$", r"\1 = []", t_line)
            t_line = re.sub(r"^(.*?)\s+\bif\s+(.*?);?$", r"if \2: \1", t_line)
            t_line = re.sub(r"\bpush\s+(\w+),\s+(.*?);?$", r"\1.append(\2)", t_line)

            # Translate Perl ternary operators
            t_line = re.sub(r"\((.*?)\)\s*\?\s*(.*?)\s*:\s*(.*?)(;|$)", r"\2 if \1 else \3\4", t_line)

            # qw/.../ lists translation
            def repl_qw(m: Any) -> str:
                words = m.group(1).split()
                return ", ".join(repr(w) for w in words)

            t_line = re.sub(r"qw/([^/]+)/", repl_qw, t_line)

            # Wrap DSL function calls in Python call syntax
            for fn_name in ["add_proto", "specialize", "forward_decls", "require"]:
                pattern = r"\b" + fn_name + r"\s+(.*?);"
                t_line = re.sub(pattern, lambda m: f"{fn_name}({m.group(1)})", t_line)

            # Block structure translation
            parse_line = t_line
            comment = ""
            if "#" in parse_line:
                parse_line, comment = parse_line.split("#", 1)
                comment = "#" + comment
            parse_line = parse_line.strip()

            if parse_line == "}":
                indent = max(0, indent - 4)
                if comment:
                    py_lines.append(" " * indent + comment)
                continue
            elif parse_line.startswith("} else {") or parse_line.startswith("} elsif"):
                indent = max(0, indent - 4)
                parse_line = parse_line.replace("} else {", "else:")
                parse_line = re.sub(
                    r"\}\s*elsif\s*\((.*?)\)\s*\{", r"elif \1:", parse_line
                )
                py_lines.append(
                    " " * indent + parse_line + (("  " + comment) if comment else "")
                )
                indent += 4
                continue
            elif parse_line.endswith("{"):
                parse_line = parse_line[:-1].strip() + ":"
                py_lines.append(
                    " " * indent + parse_line + (("  " + comment) if comment else "")
                )
                indent += 4
                continue

            py_lines.append(" " * indent + t_line.strip())

        elif state == "SUB":
            # Match print <<EOF
            if "print <<EOF" in stripped:
                state = "HEREDOC"
                heredoc_lines = []
                continue
            if stripped == "}":
                state = "NORMAL"
                continue

        elif state == "HEREDOC":
            # Match heredoc block termination
            if stripped == "EOF":
                py_lines.append(" " * indent + f"def {sub_name}():")
                py_lines.append(
                    " " * (indent + 4)
                    + "print_heredoc('''"
                    + "\n".join(heredoc_lines)
                    + "''')"
                )
                py_lines.append("")
                state = "SUB"
                continue
            heredoc_lines.append(line)

    return "\n".join(py_lines)


def main() -> None:
    global disabled, required, config, opts

    # Parse arguments
    argv = sys.argv[1:]
    defs_files = []

    for arg in argv:
        if arg.startswith("--disable-"):
            disabled.add(arg[len("--disable-") :])
        elif arg.startswith("--require-"):
            required.add(arg[len("--require-") :])
        elif arg.startswith("--arch="):
            opts["arch"] = arg[len("--arch=") :]
        elif arg.startswith("--sym="):
            opts["sym"] = arg[len("--sym=") :]
        elif arg.startswith("--config="):
            opts["config"] = arg[len("--config=") :]
        elif arg.startswith("--out="):
            opts["out"] = arg[len("--out=") :]
        else:
            defs_files.append(arg)

    if "arch" not in opts or "config" not in opts:
        print("--arch and --config are required!", file=sys.stderr)
        sys.exit(1)

    # Read config settings with explicit utf-8 encoding
    with open(opts["config"], "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            # Support both key=value format and #define KEY VALUE format
            m = re.match(r"^#define\s+(CONFIG_\w+|HAVE_\w+)\s+(.*)$", line)
            if m:
                key, val = m.group(1), m.group(2).strip()
                val = val.split("/*")[0].strip()
                config[key] = val
            elif "=" in line:
                key, val = line.split("=", 1)
                if key.startswith("CONFIG_") or key.startswith("HAVE_"):
                    config[key.strip()] = val.strip()

    # Redirect stdout to target output file if specified
    stdout_saved = sys.stdout
    if "out" in opts:
        sys.stdout = open(opts["out"], "w", encoding="utf-8")

    # Priority indexing matching upstream precedence order
    PRIORITY_ARCH = [
        "c",
        "mmx",
        "sse",
        "sse2",
        "sse3",
        "ssse3",
        "sse4_1",
        "sse4_2",
        "avx",
        "avx2",
        "avx512",
        "arm_crc32",
        "neon",
        "neon_dotprod",
        "neon_i8mm",
        "sve",
        "sve2",
        "rvv",
        "vsx",
        "dspr2",
        "msa",
    ]
    PRIORITY_INDEX = {arch: i for i, arch in enumerate(PRIORITY_ARCH)}

    # Evaluate the definition files inside BarewordDict namespace
    local_vars = BarewordDict(
        {
            "aom_config": aom_config,
            "add_proto": add_proto,
            "specialize": specialize,
            "forward_decls": forward_decls,
            "print_heredoc": lambda text: sys.stdout.write(text + "\n"),
            "opts": opts,
            "re": re,
        }
    )

    for f in defs_files:
        with open(f, "r", encoding="utf-8") as file_obj:
            content = file_obj.read()
        py_code = compile_perl_to_python(content)
        exec(py_code, local_vars)

    require("c")
    sorted_required = sorted(list(required), key=lambda x: PRIORITY_INDEX.get(x, 999))
    require(*sorted_required)

    arch = opts["arch"]
    all_archs: List[str] = []

    # Select target cpu architecture and generate corresponding RTCD code
    if arch == "x86":
        all_archs = filter_opts(
            "mmx", "sse", "sse2", "sse3", "ssse3", "sse4_1", "sse4_2", "avx", "avx2", "avx512"
        )
        x86(all_archs, opts["sym"], local_vars)
    elif arch == "x86_64":
        all_archs = filter_opts(
            "mmx", "sse", "sse2", "sse3", "ssse3", "sse4_1", "sse4_2", "avx", "avx2", "avx512"
        )
        if len(required) == 0:
            requires = filter_opts("mmx", "sse", "sse2")
            require(*requires)
        x86(all_archs, opts["sym"], local_vars)
    elif arch in ("mips32", "mips64"):
        have_dspr2 = False
        have_msa = False
        have_mmi = False
        all_archs = filter_opts(arch)
        with open(opts["config"], "r", encoding="utf-8") as f:
            for line in f:
                if "HAVE_DSPR2=yes" in line:
                    have_dspr2 = True
                if "HAVE_MSA=yes" in line:
                    have_msa = True
                if "HAVE_MMI=yes" in line:
                    have_mmi = True
        if have_dspr2:
            all_archs = filter_opts(arch, "dspr2")
        elif have_msa and have_mmi:
            all_archs = filter_opts(arch, "mmi", "msa")
        elif have_msa:
            all_archs = filter_opts(arch, "msa")
        elif have_mmi:
            all_archs = filter_opts(arch, "mmi")
        else:
            unoptimized(all_archs, opts["sym"], local_vars)
            if "out" in opts:
                sys.stdout.close()
            sys.exit(0)
        mips(all_archs, opts["sym"], local_vars)
    elif re.match(r"^armv7\w?", arch):
        all_archs = filter_opts("neon_asm", "neon")
        arm(all_archs, opts["sym"], local_vars)
    elif arch in ("armv8", "arm64"):
        all_archs = filter_opts("arm_crc32", "neon", "neon_dotprod", "neon_i8mm", "sve", "sve2")
        if len(required) == 0:
            requires = filter_opts("neon")
            require(*requires)
        arm(all_archs, opts["sym"], local_vars)
    elif arch.startswith("ppc"):
        all_archs = filter_opts("vsx")
        ppc(all_archs, opts["sym"], local_vars)
    elif arch == "riscv":
        all_archs = filter_opts("rvv")
        riscv(all_archs, opts["sym"], local_vars)
    elif "loongarch" in arch:
        all_archs = filter_opts("lsx", "lasx")
        loongarch(all_archs, opts["sym"], local_vars)
    else:
        unoptimized(all_archs, opts["sym"], local_vars)

    if "out" in opts:
        sys.stdout.close()
        sys.stdout = stdout_saved


if __name__ == "__main__":
    main()
