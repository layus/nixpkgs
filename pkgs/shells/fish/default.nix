{ stdenv, fetchurl, coreutils, utillinux,
  nettools, kbd, bc, which, gnused, gnugrep,
  groff, man-db, glibc, libiconv, pcre2,
  gettext, ncurses, python, vim, glibcLocales
}:

with stdenv.lib;

stdenv.mkDerivation rec {
  name = "fish-${version}";
  version = "2.3.0";

  patches = [ ./etc_config.patch ];

  src = fetchurl {
    url = "http://fishshell.com/files/${version}/${name}.tar.gz";
    sha256 = "1ralmp7lavdl0plc09ppm232aqsn0crxx6m3hgaa06ibam3sqawi";
  };

  buildInputs = [ ncurses libiconv pcre2 ];
  configureFlags = [ "--without-included-pcre2" ];

  # Required binaries during execution
  # Python: Autocompletion generated from manpages and config editing
  propagatedBuildInputs = [
    coreutils gnugrep gnused bc
    python which groff gettext
  ] ++ optional (!stdenv.isDarwin) man-db;

  postPatch = ''
    # /bin/{echo,ls} do not exist, but /bin/sh will
    # These executables are tested for their executable bit, never executed
    sed -e "s!/bin/\(echo\|ls\)!/bin/sh!" -i src/fish_tests.cpp tests/test6.in

    # Really use our wicked PATH.
    sed -i '/highlight_shell/ s/env_vars_snapshot_t(/&env_vars_snapshot_t::highlighting_keys/' src/fish_tests.cpp

    sed -e 's|xxd |${vim}/bin/xxd |' -i tests/*.in

    # Do not assume `-e /bin/echo`.
    sed -e 's|/bin/echo |command echo |' -i tests/test1.in

  '' + optionalString stdenv.isLinux ''
    sed -e "s| ul| ${utillinux}/bin/ul|" \
        -i "share/functions/__fish_print_help.fish"
    for cur in share/functions/*.fish; do
      sed -e "s|/usr/bin/getent|${glibc.bin}/bin/getent|" -i "$cur"
    done
  '';

  doCheck = true;
  TERM = "xterm";
  TERMINFO = "${ncurses}/share/terminfo";
  LC_ALL = "en_US.UTF-8";
  LOCALE_ARCHIVE = stdenv.lib.optionalString stdenv.isLinux
    "${glibcLocales}/lib/locale/locale-archive";
  checkPhase = ''
    make test HOME=$TMPDIR
  '';

  postInstall = ''
    sed -r "s|command grep|command ${gnugrep}/bin/grep|" \
        -i "$out/share/fish/functions/grep.fish"
    sed -e "s|bc|${bc}/bin/bc|"                          \
        -e "s|/usr/bin/seq|${coreutils}/bin/seq|"        \
        -i "$out/share/fish/functions/seq.fish"          \
           "$out/share/fish/functions/math.fish"
    sed -i "s|which |${which}/bin/which |"               \
            "$out/share/fish/functions/type.fish"
    sed -e "s|\|cut|\|${coreutils}/bin/cut|"             \
        -i "$out/share/fish/functions/fish_prompt.fish"
    sed -e "s|gettext |${gettext}/bin/gettext |"         \
        -e "s|which |${which}/bin/which |"               \
        -i "$out/share/fish/functions/_.fish"
    sed -e "s|uname|${coreutils}/bin/uname|"             \
        -i "$out/share/fish/functions/__fish_pwd.fish"   \
           "$out/share/fish/functions/prompt_pwd.fish"
    sed -e "s|sed |${gnused}/bin/sed |"                  \
        -i "$out/share/fish/functions/alias.fish"        \
           "$out/share/fish/functions/prompt_pwd.fish"
    sed -i "s|nroff |${groff}/bin/nroff |"               \
           "$out/share/fish/functions/__fish_print_help.fish"
    sed -i "s|/sbin /usr/sbin||" \
           "$out/share/fish/functions/__fish_complete_subcommand_root.fish"
    sed -e "s|clear;|${ncurses.out}/bin/clear;|" \
        -i "$out/share/fish/functions/fish_default_key_bindings.fish" \

  '' + optionalString (!stdenv.isDarwin) ''
    sed -i "s|(hostname\||(${nettools}/bin/hostname\||"           \
           "$out/share/fish/functions/fish_prompt.fish"
    sed -i "s|Popen(\['manpath'|Popen(\['${man-db}/bin/manpath'|" \
            "$out/share/fish/tools/create_manpage_completions.py"
    sed -i "s|command manpath|command ${man-db}/bin/manpath|"     \
            "$out/share/fish/functions/man.fish"
  '' + ''
    tee -a $out/share/fish/config.fish << EOF

    # make fish pick up completions from nix profile
    if status --is-interactive
      set -l profiles (echo $NIX_PROFILES | ${coreutils}/bin/tr ' ' '\n')
      set fish_complete_path $profiles"/share/fish/vendor_completions.d" $fish_complete_path
    end
    EOF
  '';

  meta = with stdenv.lib; {
    description = "Smart and user-friendly command line shell";
    homepage = "http://fishshell.com/";
    license = licenses.gpl2;
    platforms = platforms.unix;
    maintainers = with maintainers; [ ocharles ];
  };
}
