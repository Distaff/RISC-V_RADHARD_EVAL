#!/bin/sh
#############################################################################
#  Author: Piotr Kadziela
#  Description:
#      Runs every testbench under testbench-unit/ and testbench-integration/
#      and prints a summary.
#      The whole tree is compiled once into a single library; each testbench
#      is then elaborated and run on its own, so one failure does not take the
#      rest down with it.
#      A testbench counts as passed only if its log carries the token printed
#      by TB_FINISH, so one that dies early is reported as a failure.
#      Requires the Vivado tools on PATH.
#
#      Usage:
#          ./run-tests.sh              run every testbench
#          ./run-tests.sh alu          run only the ones matching a fragment
#############################################################################

set -u

HW=$(cd "$(dirname "$0")/.." && pwd)
SRC="$HW/src"
UNIT="$HW/test/testbench-unit"
INTEG="$HW/test/testbench-integration"
WORK="$HW/test/.xsim"
FILTER="${1:-}"

# Look for the tools in the usual places before giving up, so that running
# this does not depend on remembering to source anything first.
if ! command -v xvlog >/dev/null 2>&1; then
    for cand in /e/SDKs/Xilinx/*/Vivado/bin                 /c/Xilinx/*/Vivado/bin                 /d/Xilinx/*/Vivado/bin                 /c/Program Files/Xilinx/*/Vivado/bin; do
        if [ -x "$cand/xvlog" ]; then
            PATH="$cand:$PATH"
            export PATH
            echo "using $cand"
            break
        fi
    done
fi

command -v xvlog >/dev/null 2>&1 || {
    echo "xvlog not found - put the Vivado bin directory on PATH first" >&2
    exit 127
}

# The Vivado tools are native Windows programs and do not understand the paths
# a POSIX shell hands them, so every path crossing the boundary is converted.
if command -v cygpath >/dev/null 2>&1; then
    winpath() { cygpath -m "$1"; }
    winlist() { cygpath -m -f -; }
else
    winpath() { printf '%s' "$1"; }
    winlist() { cat; }
fi

cd "$HW" || exit 1     # never sit inside the directory about to be removed
# Windows keeps a handle on the work directory for a while after a simulation,
# so a failed removal is not worth reporting - the compile overwrites it.
rm -rf "$WORK" 2>/dev/null
mkdir -p "$WORK"
cd "$WORK" || exit 1

# Packages define types the interfaces use, and the interfaces are used by the
# modules, so the file list is ordered rather than left to the tool.
{
    ls "$SRC"/interfaces/*_pkg.sv
    ls "$SRC"/interfaces/*_if.sv
    find "$SRC" -name '*.sv' ! -path '*/interfaces/*'
    find "$UNIT" "$INTEG" -name '*_tb.sv'
} | winlist > files.f

echo "compiling..."
if ! xvlog -sv -i "$(winpath "$SRC/core")" -i "$(winpath "$UNIT")"              -f files.f > compile.log 2>&1; then
    echo "COMPILATION FAILED"
    grep -i 'error' compile.log | head -40
    exit 1
fi

pass=0
fail=0

# Colours only on a terminal, so a redirected log stays plain text.
if [ -t 1 ]; then
    GREEN=$(printf '\033[32m')
    RED=$(printf '\033[31m')
    CYAN=$(printf '\033[36m')
    RESET=$(printf '\033[0m')
else
    GREEN=''; RED=''; CYAN=''; RESET=''
fi

for tb in $(find "$UNIT" -name '*_tb.sv' | sort) $(find "$INTEG" -name '*_tb.sv' | sort); do
    top=$(basename "$tb" .sv)
    case "$top" in
        *"$FILTER"*) ;;
        *) continue ;;
    esac

    case "$tb" in
        "$INTEG"/*) kind=INTG ;;
        *)          kind=UNIT ;;
    esac
    name="$CYAN$kind$RESET $(printf '%-28s' "$top")"

    if ! xelab -s "${top}_snap" "$top" > "$top.elab.log" 2>&1; then
        printf '%s %sELAB FAIL%s\n' "$name" "$RED" "$RESET"
        grep -i 'error' "$top.elab.log" | head -10 | sed 's/^/    /'
        fail=$((fail + 1))
        continue
    fi

    xsim "${top}_snap" -runall > "$top.log" 2>&1

    if grep -q 'TB_RESULT PASS' "$top.log"; then
        printf '%s %sPASS%s  %s\n' "$name" "$GREEN" "$RESET" "$(grep -o '[0-9]* checks' "$top.log" | head -1)"
        pass=$((pass + 1))
    else
        printf '%s %sFAIL%s\n' "$name" "$RED" "$RESET"
        grep '  FAIL' "$top.log" | head -20 | sed 's/^/    /'
        grep -q 'TB_RESULT' "$top.log" || echo "    testbench did not finish - see $WORK/$top.log"
        fail=$((fail + 1))
    fi
done

echo "--------------------------------------------"
[ "$fail" -eq 0 ] && colour=$GREEN || colour=$RED
echo "$colour$pass passed, $fail failed$RESET"
[ "$fail" -eq 0 ]
