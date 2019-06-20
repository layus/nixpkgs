{ stdenv, autoreconfHook, fetchFromGitLab, libX11, xauth, makeWrapper }:

let version = "1.4.0";
in stdenv.mkDerivation {
  name = "xtrace-${version}";
  src = fetchFromGitLab rec {
    domain = "salsa.debian.org";
    owner = "debian";
    repo = "xtrace";
    rev = "xtrace-${version}";
    name = "${rev}-source";
    sha256 = "1yff6x847nksciail9jly41mv70sl8sadh0m5d847ypbjmxcwjpq";
  };

  nativeBuildInputs = [ autoreconfHook ];
  buildInputs = [ libX11 makeWrapper ];

  postInstall = ''
    wrapProgram "$out/bin/xtrace" \
        --prefix PATH ':' "${xauth}/bin"
  '';

  meta = {
    homepage = "https://salsa.debian.org/debian/xtrace";
    description = "Tool to trace X11 protocol connections";
    license = stdenv.lib.licenses.gpl2;
    maintainers = with stdenv.lib.maintainers; [viric];
    platforms = with stdenv.lib.platforms; linux;
  };
}
