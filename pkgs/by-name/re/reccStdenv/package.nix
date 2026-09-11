# recc-wrapped compiler + stdenv: the Remote Execution analogue of
# ccacheWrapper / ccacheStdenv.  Where ccache caches object files in a local
# directory, `recc` (shipped in buildbox) offloads each compile — and its
# caching — to a nixception Remote Execution endpoint, which builds it as a
# Nix derivation via recursive-nix.
#
# Exposed as `pkgs.reccStdenv`.  Select it like ccacheStdenv:
#    replaceStdenv = { pkgs }: pkgs.reccStdenv;
# or per-package via `.override { stdenv = reccStdenv; }`.
{
  lib,
  stdenv,
  stdenvAdapters,
  overrideCC,
  reccStdenv,
  runCommand,
  runCommandLocal,
  makeWrapper,
  buildbox,
  nixceptionHook,
  hello,
}:

let
  # The recc-links tree: an unwrapped-cc-shaped directory whose compiler
  # drivers (cc/gcc/g++/c++) are `recc <real-driver>` wrappers and whose every
  # other file is symlinked straight through, so the surrounding cc-wrapper's
  # NIX_* handling and suffix-salt are unchanged.  `extraConfig` is shell run
  # (via makeWrapper --run) right before recc execs; it is where the RECC_*
  # endpoints are set.  Direct analogue of `ccache.links`.
  reccLinks =
    { unwrappedCC, extraConfig }:
    runCommand "${unwrappedCC.name}-recc"
      {
        passthru = {
          isClang = unwrappedCC.isClang or false;
          isGNU = unwrappedCC.isGNU or false;
          isRecc = true;
        }
        // builtins.intersectAttrs {
          hardeningUnsupportedFlagsByTargetPlatform = null;
          hardeningUnsupportedFlags = null;
        } unwrappedCC;
        lib = lib.getLib unwrappedCC;
        nativeBuildInputs = [ makeWrapper ];
        meta = { inherit (unwrappedCC.meta) mainProgram; };
      }
      (
        let
          targetPrefix = lib.optionalString (
            unwrappedCC ? targetConfig && unwrappedCC.targetConfig != null && unwrappedCC.targetConfig != ""
          ) "${unwrappedCC.targetConfig}-";
        in
        ''
          mkdir -p $out/bin

          wrap() {
            local cname="${targetPrefix}$1"
            if [ -x "${unwrappedCC}/bin/$cname" ]; then
              makeWrapper ${buildbox}/bin/recc $out/bin/$cname \
                --run ${lib.escapeShellArg extraConfig} \
                --add-flags ${unwrappedCC}/bin/$cname
            fi
          }

          wrap cc
          wrap c++
          wrap gcc
          wrap g++
          wrap clang
          wrap clang++

          # Every remaining tool and every non-bin file falls through to the
          # real compiler, so the tree stays a drop-in replacement.
          for executable in $(ls ${unwrappedCC}/bin); do
            [ -x "$out/bin/$executable" ] || ln -s ${unwrappedCC}/bin/$executable $out/bin/$executable
          done
          for file in $(ls ${unwrappedCC} | grep -vw bin); do
            ln -s ${unwrappedCC}/$file $out/$file
          done
        ''
      );

  # The RECC_* endpoint config baked into every wrapper.  Each value defers to
  # anything already in the environment, so a dev shell or the nixceptionHook
  # can point recc elsewhere without rebuilding the wrapper.
  reccExtraConfig = ''
    export RECC_SERVER="''${RECC_SERVER:-127.0.0.1:50051}"
    export RECC_CAS_SERVER="''${RECC_CAS_SERVER:-$RECC_SERVER}"
    export RECC_ACTION_CACHE_SERVER="''${RECC_ACTION_CACHE_SERVER:-$RECC_SERVER}"
    export RECC_INSTANCE="''${RECC_INSTANCE:-main}"

    # recc uploads $PATH verbatim as part of every remote action, so it must
    # match what a real sandboxed build would see for the cache to cross the
    # nix-build / nix-develop boundary. A sandboxed build's $PATH is entirely
    # /nix/store/*/bin entries; an interactive `nix develop` session can pick
    # up extra, non-store entries afterwards (e.g. on NixOS, /etc/profile's
    # system-wide PATH: /run/wrappers/bin, ~/.nix-profile/bin,
    # /run/current-system/sw/bin, …) that a plain env-var snapshot taken in
    # shellHook can't reliably survive — some shell integration (direnv, a
    # prompt hook, …) can still clobber it before this wrapper ever runs.
    # Rather than trying to capture or detect that, filter it out here, every
    # time: keep only /nix/store/* entries, which is exactly what a real
    # sandboxed build's $PATH already consists of, so this is a no-op there.
    PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep '^/nix/store/' | paste -sd: -)"

    # recc also always forwards LANG and LD_LIBRARY_PATH when they're set,
    # independent of RECC_ENV_TO_READ/RECC_PRESERVE_ENV. A sandboxed build
    # never has either (Nix's build sandbox doesn't set them), so they're
    # absent from a real build's action. The same NixOS /etc/profile that
    # contaminates PATH in an interactive nix-develop session also sets both
    # — unset them so there's nothing for recc to pick up, matching what a
    # real sandboxed build already has.
    unset LANG LD_LIBRARY_PATH

    # RECC_PROJECT_ROOT is the top-level source dir: recc uploads every
    # input path inside it and reconstructs each remote output at
    #   RECC_PROJECT_ROOT / <action working_directory> / <output_path>.
    # It must be an ancestor of both the sources and the build directory.
    # $NIX_BUILD_TOP (e.g. /build) is an ancestor of the unpacked source
    # tree and every build dir under it, so out-of-tree cmake/meson builds
    # get correct output placement and all sources still upload.  Keep any
    # value a caller already exported.
    export RECC_PROJECT_ROOT="''${RECC_PROJECT_ROOT:-''${NIX_BUILD_TOP:-$(cd .. && pwd)}}"
  '';

  # A cc-wrapper whose underlying compiler is the recc-links tree above.
  reccWrapper = stdenv.cc.override {
    cc = reccLinks {
      unwrappedCC = stdenv.cc.cc;
      extraConfig = reccExtraConfig;
    };
  };

  # In addition to the recc-wrapped compiler, every derivation built with this
  # stdenv gets `nixceptionHook` in nativeBuildInputs and the `recursive-nix`
  # system feature.  Together they make a pure `nix build` self-contained: the
  # hook starts a nixception server on the sandbox loopback (127.0.0.1:50051)
  # before configurePhase, and recc — invoked through the wrapped compiler —
  # connects to it.  No external server is needed; the Remote Execution actions
  # are cached in the shared Nix store.  Requires `recursive-nix`
  # (experimental-features + system-features in nix.conf); otherwise pure — the
  # nixception package is fetched from a released tag — so no `--impure`.
  #
  # NIX_OUTPATH_USED_AS_RANDOM_SEED pins every -frandom-seed the
  # reproducible-builds setup hook bakes into NIX_CFLAGS_COMPILE to a fixed
  # constant, instead of nixpkgs' default (the last 10 chars of $out).  $out
  # differs between a real `nix build` and the synthetic shell-env derivation
  # `nix develop` builds for the same package, so the default would make an
  # otherwise byte-identical compile — the whole point of routing it through
  # nixception — hash to two different REAPI actions depending on which one
  # produced it, permanently defeating the cache across that boundary.  A
  # fixed seed keeps every reccStdenv build reproducible in exactly the same
  # (weaker) sense ccache/sccache already accept: symbol names are stable
  # across builds, not diversified per output the way plain nixpkgs prefers.
  base = lib.lowPrio (
    stdenvAdapters.overrideMkDerivationArgs (args: {
      nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [ nixceptionHook ];
      requiredSystemFeatures = (args.requiredSystemFeatures or [ ]) ++ [ "recursive-nix" ];
      # Every reccStdenv derivation is __structuredAttrs (below), where
      # mkDerivation's own convention is that env vars belong under `env`, not
      # as bare top-level attrs — merge into args.env (rather than a bare
      # NIX_OUTPATH_USED_AS_RANDOM_SEED = "…";) so this follows that
      # convention and composes with whatever the consuming derivation itself
      # already puts in `env`, instead of silently overwriting it.
      env = (args.env or { }) // {
        NIX_OUTPATH_USED_AS_RANDOM_SEED = args.env.NIX_OUTPATH_USED_AS_RANDOM_SEED or "0000000000";
      };
    }) (overrideCC stdenv reccWrapper)
  );

  # Pure packaging check (ordinary CI, no recursive-nix): assert
  # reccStdenv's compiler is genuinely recc-wrapped — the unwrapped cc
  # carries the `isRecc` marker and its drivers forward to `recc`.
  cc-is-recc-wrapped =
    runCommandLocal "reccStdenv-cc-is-recc-wrapped-test"
      {
        reccCC = base.cc.cc;
      }
      ''
        test "${lib.optionalString (base.cc.cc.isRecc or false) "1"}" = "1" \
          || { echo "FAIL: reccStdenv.cc.cc is not recc-wrapped (isRecc unset)"; exit 1; }
        echo "ok: reccStdenv.cc.cc.isRecc is set"

        found=0
        for tool in cc c++ gcc g++ clang clang++; do
          [ -e "$reccCC/bin/$tool" ] || continue
          grep -q "/bin/recc" "$reccCC/bin/$tool" \
            || { echo "FAIL: $tool does not forward to recc"; exit 1; }
          echo "  ok: $tool -> recc"
          found=$((found + 1))
        done
        [ "$found" -ge 1 ] || { echo "FAIL: no recc-forwarding drivers"; exit 1; }

        echo "reccStdenv cc-is-recc-wrapped assertions passed ($found drivers)"
        touch $out
      '';

  # End-to-end check (recursive-nix gated; Hydra skips it via the
  # inherited system feature).  Build GNU hello through reccStdenv: the
  # recc-wrapped compiler dispatches every compile to the nixception
  # server the hook starts in the sandbox, and the result must run.  A
  # maintainer with `recursive-nix` can run it to exercise the whole
  # REAPI→Nix path.
  recc-hello = (hello.override { stdenv = reccStdenv; }).overrideAttrs (old: {
    pname = "reccStdenv-recc-hello-test";
    # hello sets doInstallCheck = true and drives it through
    # versionCheckHook + postInstallCheck; append our assertion there so
    # both run (an installCheckPhase override would silently not run).
    postInstallCheck = (old.postInstallCheck or "") + ''
      echo "running hello built through reccStdenv..."
      greeting=$("''${!outputBin}/bin/${old.meta.mainProgram}")
      echo "  output: $greeting"
      [ "$greeting" = "Hello, world!" ] \
        || { echo "FAIL: unexpected hello output"; exit 1; }
      echo "reccStdenv recc-hello end-to-end assertion passed"
    '';
  });

in
base
// {
  tests = { inherit cc-is-recc-wrapped recc-hello; };

  # Make nixpkgs-vet happy.
  strictDeps = true;
  __structuredAttrs = true;
}
