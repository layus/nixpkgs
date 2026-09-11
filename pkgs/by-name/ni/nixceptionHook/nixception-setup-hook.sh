# Setup hook for the nixception package.
# ======================================
#
# Two lifecycles, because stdenv's phase/hook machinery (preConfigurePhases,
# exitHook, failureHook) only exists inside genericBuild — nix-shell / nix
# develop never call it, they just source the setup hooks and run $shellHook.
#
# ── In a real build ───────────────────────────────────────────────────────
#
# Registers one extra phase: nixceptionStartPhase, registered via
# preConfigurePhases; starts the nixception server and waits until it is ready
# to accept connections on 127.0.0.1:50051.  The server is stopped by hooking
# into stdenv's failureHook and exitHook, which are called by exitHandler (the
# EXIT trap) on failure and success respectively.
#
# The phase is registered before configurePhase (rather than before buildPhase)
# because some build systems (e.g. CMake) probe the compiler during configure.
# When the compiler is wrapped by recc, the nixception server must already be
# listening or those probes will fail with connection-refused errors.
#
# It requires the recursive-nix system feature: the server talks to the Nix
# daemon socket the sandbox exposes at /build/.nix-socket.
#
# ── In `nix develop` / `nix-shell` ──────────────────────────────────────────
#
# Appends to $shellHook instead: starts the server the same way, but against
# the ambient host Nix daemon (there is no /build/.nix-socket outside a
# sandboxed build, and none is needed — the daemon a plain `nix build` would
# use is enough). A background watchdog stops the server when the shell
# exits — see _nixceptionShellStart below for why (not a trap: exitHook /
# failureHook don't exist outside genericBuild, and a plain `trap ... EXIT`
# doesn't survive `nix develop -c`). Detected via $IN_NIX_SHELL, which
# nix-shell/nix develop set. (PATH contamination in this mode — a
# "/no-such-path" sentinel from `nix develop`'s own PATH construction, or a
# whole system/user profile some systems append when starting the interactive
# shell afterwards — is not handled here; see reccStdenv's compiler wrapper.)
#
# ── Verbosity ────────────────────────────────────────────────────────────────
#
# By default the hook runs in quiet mode: the nixception server's output is
# sent to a log file and lifecycle messages are suppressed.  Set
# NIXCEPTION_VERBOSE=1 in the build environment to get all the debug messages
#
# On build *failure* the server log is always dumped to stderr regardless of
# the verbosity setting, so you can still debug without re-running. (In shell
# mode there is no failure to detect, so this only applies to real builds.)
#
# ── Shutdown (build mode) ────────────────────────────────────────────────────
#
# stdenv's exitHandler (set as the EXIT trap before any setup hook runs) calls:
#   runHook failureHook   – on non-zero exit
#   runHook exitHook      – on clean exit
#
# We append our stop command to both hooks so the server is always torn down,
# whether the build succeeds or fails.
#
# ── Extra sandbox tools ──────────────────────────────────────────────────────
#
# To make extra tools available inside the reapi-action sandbox, export
# NIXCEPTION_EXTRA_SANDBOX_PATHS (colon-separated /nix/store/… paths) in the
# build environment *before* this phase runs (build mode), or before entering
# the shell (shell mode).

# shellcheck shell=bash

# Helper: print a message only in verbose mode.
_nixception_log() {
    if [ "${NIXCEPTION_VERBOSE:-0}" = "1" ]; then
        echo "nixception-hook: $*" >&2
    fi
}

_nixception_pid=
_nixception_logfile=

_nixceptionStop() {
    _nixception_log "stopping server (pid $_nixception_pid)..."
    kill "$_nixception_pid" 2>/dev/null || true
    wait "$_nixception_pid" 2>/dev/null || true

    # Print timing summary
    if [ -s "$NIXCEPTION_STATS_FILE" ]; then
        echo '' >&2
        echo 'nixception-hook: ── timing statistics ──' >&2
        cat "$NIXCEPTION_STATS_FILE" >&2
    else
        _nixception_log "no timing statistics available"
    fi
    rm -f "$NIXCEPTION_STATS_FILE"
}

_nixceptionFailStop() {
    _nixceptionStop

    # In quiet mode, dump the server log on failure so the user can debug
    # without re-running in verbose mode.
    if [ "${NIXCEPTION_VERBOSE:-0}" != "1" ] && [ -s "$_nixception_logfile" ]; then
        echo '' >&2
        echo 'nixception-hook: ── server log (last 200 lines) ──' >&2
        tail -n 200 "$_nixception_logfile" >&2
        echo 'nixception-hook: ── end of server log ──' >&2
        echo '(set NIXCEPTION_VERBOSE=1 for full real-time output)' >&2
    fi
    rm -f "$_nixception_logfile"
}

# Clean exit: just stop the server (and remove the log file).
_nixceptionCleanStop() {
    _nixceptionStop
    rm -f "$_nixception_logfile"
}

# Start the nixception server in the background, wait until it accepts
# connections on 127.0.0.1:50051, and set $_nixception_pid / $_nixception_logfile
# / $NIXCEPTION_STATS_FILE. Shared by build mode (nixceptionStartPhase) and
# shell mode (_nixceptionShellStart) — everything about the server itself
# (verbosity, log file, stats file, readiness wait) is identical between them;
# only what surrounds it (the daemon-socket check, how it's torn down) differs.
_nixceptionLaunch() {
    local _verbose="${NIXCEPTION_VERBOSE:-0}"

    # Stats file
    export NIXCEPTION_STATS_FILE
    NIXCEPTION_STATS_FILE="$(mktemp -t nixception-stats.XXXXXX)"

    # Server log file (used in quiet mode)
    _nixception_logfile="$(mktemp -t nixception-server.log.XXXXXX)"

    # Verbosiy
    # In verbose mode the default RUST_LOG level is "info" and server output is
    # timestamped and forwarded to stderr.  In quiet mode the level drops to
    # "warn" and output goes to a log file that is only shown on failure.
    # If the caller already set RUST_LOG we never override it.
    local _rust_log
    if [ -n "${RUST_LOG:-}" ]; then
        _rust_log="$RUST_LOG"
    elif [ "$_verbose" = "1" ]; then
        _rust_log="info"
    else
        _rust_log="warn"
    fi

    # Start the server
    _nixception_log "starting nixception server..."
    if [ "$_verbose" = "1" ]; then
        RUST_LOG="$_rust_log" \
            RUST_BACKTRACE=1 \
            @nixception@/bin/nixception \
            > >(@moreutils@/bin/ts -s '[nixception] %H:%M:%.S' >&2) 2>&1 &
    else
        RUST_LOG="$_rust_log" \
            RUST_BACKTRACE=1 \
            @nixception@/bin/nixception \
            > "$_nixception_logfile" 2>&1 &
    fi
    _nixception_pid=$!

    # Wait for the server to be ready
    @wait4x@/bin/wait4x tcp 127.0.0.1:50051 --timeout 30s --quiet
    _nixception_log "server is ready (pid $_nixception_pid)"
}

nixceptionStartPhase() {
    # ── Sanity-check: recursive-nix socket ───────────────────────────────────
    # The Nix daemon socket is exposed at /build/.nix-socket when the sandbox
    # is started with the recursive-nix system feature.  Fail fast so the
    # error is obvious rather than a cryptic connection-refused from nixception.
    test -S /build/.nix-socket || {
        echo "nixception-hook: FAIL: recursive-nix daemon socket not found" \
            '– is requiredSystemFeatures = ["recursive-nix"] set?' >&2
        exit 1
    }

    _nixceptionLaunch

    # Register exit hooks
    exitHook+=$'\n_nixceptionCleanStop\n'
    failureHook+=$'\n_nixceptionFailStop\n'
}

# ── Shell mode ───────────────────────────────────────────────────────────────
# No genericBuild here, so no preConfigurePhases / exitHook / failureHook — and
# no reliable EXIT trap either: `nix develop -c CMD` sources this shellHook and
# then execs CMD *in the same shell process* (same PID, new process image), so
# a trap set here is simply gone — exec never returns to run it. (A plain
# interactive `nix develop`, with no -c, is the one case where that shell truly
# exits and a trap would fire — but relying on two different mechanisms for the
# two invocation styles is exactly the kind of thing that quietly breaks again.)
#
# So: no /build/.nix-socket check (outside a sandboxed build there's no such
# thing, and none is needed — the server just talks to whatever Nix daemon
# `nix build` would use), and instead of a trap, a tiny watchdog forked
# alongside the server. `exec` preserves the PID, so the server's direct parent
# stays *this* shell for as long as it's alive, under any exec chain; the
# watchdog polls that PID and kills the server the moment it's gone — covering
# -c, --command, and plain interactive shells uniformly. `disown` both so an
# interactive shell's job control doesn't warn "There are running jobs" on exit.
_nixceptionShellStart() {
    local _shell_pid=$$

    # PATH sees two kinds of contamination in shell mode compared to a real
    # sandboxed build: `nix develop`'s own from-scratch PATH build appends a
    # "/no-such-path" sentinel, and — on some systems (e.g. NixOS, via
    # /etc/bashrc -> /etc/profile, or a shell integration like direnv) —
    # starting the interactive shell can append or prepend a whole system/user
    # profile afterwards, which no snapshot taken here could reliably survive.
    # Nothing done about PATH in this hook: reccStdenv's compiler wrapper
    # filters $PATH down to /nix/store/* entries right before recc runs (every
    # legitimate sandboxed $PATH entry already is one), which removes both
    # kinds of contamination regardless of when or how they were added.

    _nixceptionLaunch
    disown "$_nixception_pid" 2>/dev/null || true
    echo "nixception-hook: server ready on 127.0.0.1:50051 (pid $_nixception_pid)" >&2

    (
        while kill -0 "$_shell_pid" 2>/dev/null; do
            sleep 1
        done
        _nixceptionCleanStop
    ) &
    disown "$!" 2>/dev/null || true
}

if [ -n "${IN_NIX_SHELL:-}" ]; then
    shellHook+=$'\n_nixceptionShellStart\n'
else
    preConfigurePhases="${preConfigurePhases:-} nixceptionStartPhase"
fi
