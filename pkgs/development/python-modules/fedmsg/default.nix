{ stdenv, buildPythonPackage, fetchurl
, M2Crypto
, arrow
, click
, cryptography
, kitchen
, m2ext
, moksha_hub
, psutil
, pyopenssl #, pyOpenSSL
, pygments
, pyzmq
, requests
, six
}:

buildPythonPackage rec {
  pname = "fedmsg";
  version = "1.1.0";
  name  = "${pname}-${version}";

  src = fetchurl {
    url = "mirror://pypi/f/fedmsg/${name}.tar.gz";
    sha256 = "0s75ngh2llqssxh5fswkahijaki3mwbcyi6na455m6b0a3jr9a8j";
  };

  propagatedBuildInputs = [
    M2Crypto
    arrow
    click
    cryptography
    kitchen
    m2ext
    moksha_hub
    psutil
    pyopenssl #pyOpenSSL
    pygments
    pyzmq
    requests
    six
  ];

  doCheck = false; # requires fedora_cert which isn't used anymore

  meta = with stdenv.lib; {
    description = "Subclass of the rpkg project for dealing with rpm packaging";
    homepage = https://pagure.io/fedpkg;
    license = licenses.gpl2;
    maintainers = with maintainers; [ ];
  };
}
