// Shared helpers for the unit testbenches.
//
// A testbench declares its counters with `TB_VARS inside the module, checks
// with `CHECK or `CHECK_EQ, and ends with `TB_FINISH. The last one prints
// the token the runner script looks for, so a testbench that dies early
// counts as a failure without needing a reliable exit code.
//
// The counters are declared inside the module rather than here, because
// declarations at file scope would land in the compilation unit and collide
// between testbenches compiled into the same library.

`ifndef TB_UTILS_SVH
`define TB_UTILS_SVH

`define TB_VARS \
    int tb_errors = 0; \
    int tb_checks = 0;

`define CHECK(cond, msg) \
    begin \
        tb_checks++; \
        if (!(cond)) begin \
            tb_errors++; \
            $display("  FAIL %m  %s", msg); \
        end \
    end

`define CHECK_EQ(got, exp, msg) \
    begin \
        tb_checks++; \
        if ((got) !== (exp)) begin \
            tb_errors++; \
            $display("  FAIL %m  %s: got %08h, expected %08h", msg, (got), (exp)); \
        end \
    end

`define TB_FINISH \
    begin \
        if (tb_errors == 0) \
            $display("TB_RESULT PASS  %0d checks", tb_checks); \
        else \
            $display("TB_RESULT FAIL  %0d of %0d checks failed", tb_errors, tb_checks); \
        $finish; \
    end

// Watchdog for anything that waits on a clock or a handshake. Without it a
// testbench whose DUT never answers hangs xsim -runall instead of failing.
`define TB_TIMEOUT(limit_ns) \
    initial begin \
        #(limit_ns); \
        $display("  FAIL %m  timed out after %0d ns", limit_ns); \
        $display("TB_RESULT FAIL  timeout"); \
        $finish; \
    end

`endif
