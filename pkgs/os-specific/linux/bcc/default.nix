{ stdenv, fetchFromGitHub, fetchpatch, makeWrapper, cmake, llvmPackages, kernel
, flex, bison, elfutils, python, luajit, netperf, iperf, libelf
, systemtap
}:

python.pkgs.buildPythonApplication rec {
  version = "0.5.0";
  name = "bcc-${version}";

  src = fetchFromGitHub {
    owner = "iovisor";
    repo = "bcc";
    rev = "v${version}";
    sha256 = "0bb3244xll5sqx0lvrchg71qy2zg0yj6r5h4v5fvrg1fjhaldys9";
  };

  format = "other";

  buildInputs = [
    llvmPackages.llvm llvmPackages.clang-unwrapped kernel
    elfutils luajit netperf iperf
    systemtap.stapBuild
  ];

  patches = [
    # fix build with llvm > 5.0.0 && < 6.0.0
    (fetchpatch {
      url = "https://github.com/iovisor/bcc/commit/bd7fa55bb39b8978dafd0b299e35616061e0a368.patch";
      sha256 = "1sgxhsq174iihyk1x08py73q8fh78d7y3c90k5nh8vcw2pf1xbnf";
    })

    # This is needed until we fix
    # https://github.com/NixOS/nixpkgs/issues/40427
    ./fix-deadlock-detector-import.patch
  ];

  nativeBuildInputs = [ makeWrapper cmake flex bison ]
    # libelf is incompatible with elfutils-libelf
    ++ stdenv.lib.filter (x: x != libelf) kernel.moduleBuildDependencies;

  cmakeFlags = [
    "-DBCC_KERNEL_MODULES_DIR=${kernel.dev}/lib/modules"
    "-DREVISION=${version}"
    "-DENABLE_USDT=ON"
    "-DENABLE_CPP_API=ON"
  ];

  postPatch = ''
    substituteAll ${./libbcc-path.patch} ./libbcc-path.patch
    patch -p1 < libbcc-path.patch
  '';

  propagatedBuildInputs = [
    python.pkgs.netaddr
  ];

  postInstall = ''
    mkdir -p $out/bin $out/share
    rm -r $out/share/bcc/tools/old
    mv $out/share/bcc/tools/doc $out/share
    mv $out/share/bcc/man $out/share/

    find $out/share/bcc/tools -type f -executable -print0 | \
    while IFS= read -r -d ''$'\0' f; do
      bin=$out/bin/$(basename $f)
      if [ ! -e $bin ]; then
        ln -s $f $bin
      fi
    done

    sed -i -e "s!lib=.*!lib=$out/bin!" $out/bin/{java,ruby,node,python}gc
  '';

  postFixup = ''
    wrapPythonProgramsIn "$out/share/bcc/tools" "$out $pythonPath"
  '';

  meta = with stdenv.lib; {
    description = "Dynamic Tracing Tools for Linux";
    homepage = https://iovisor.github.io/bcc/;
    license = licenses.asl20;
    maintainers = with maintainers; [ ragge mic92 ];
  };
}
