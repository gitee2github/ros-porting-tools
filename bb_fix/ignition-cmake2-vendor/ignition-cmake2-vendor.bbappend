FILES:${PN}:prepend = " \
    ${ros_prefix}/lib/cpptoml/* \
"
do_configure:prepend() {
	cp ${OPENEULER_SP_DIR}/ignition_cmake2_vendor/ignition-cmake2_2.8.0.tar.gz ${S}/
}
