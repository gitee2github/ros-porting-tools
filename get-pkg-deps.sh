#!/bin/bash

. base.sh

ROS_PKG_SRC=${OUTPUT}/ros-pkg-src.list

prepare()
{
	if [ "${ROS_SRC_BASE}" = "" ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	if [ ! -d ${ROS_SRC_BASE} ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	if [ ! -f ${ROS_PKG_LIST} ]
	then
		error_log "Can not find ${ROS_PKG_LIST}, you can use get-repo-list.sh to create it"
		exit 1
	fi

	if [ ! -f ${ROS_PKG_SRC} ]
	then
		error_log "Can not find ${ROS_PKG_SRC}, you can use get-pkg-src.sh to create it"
		exit 1
	fi

	mkdir -p ${ROS_DEPS_BASE}
	rm -f ${ROS_DEPS_BASE}/*
}

write_dep()
{
	require_type=$1
	dep=$2
	require_file=$3

	grep -qP "$dep$" ${require_file} 2>/dev/null
	[ $? -eq 0 ] && return

	echo "${require_type}: ${dep}" >> ${require_file}
}

gen_depend()
{
	pkg=$1
	base_path=$2
	depend_name=$3
	dep_type=$4

	#depend=`sed -n "/<${depend_name}/p" ${ROS_SRC_BASE}/${base_path}/package.xml | grep -v "ROS_VERSION == 1" |sed "s#<${depend_name}>##g" | sed "s#</${depend_name}>##g" | sed "s#<${depend_name}.*>##g" | sed "s/[[:space:]]//g" | grep -v "\-\-"`
	depend=`grep -P "^${depend_name}:" ${ROS_DEPS_BASE}/$pkg-PackageXml | awk -F"${depend_name}:" '{print $2}'`
	if [ "$depend" = "" ]
	then
		return 0
	fi

	case $depend_name in
	"depend")
		echo "$depend" >> ${ROS_DEPS_BASE}/$pkg-BuildDepends
		echo "$depend" >> ${ROS_DEPS_BASE}/$pkg-ExecDepends
		;;
	"build_depend")
		echo "$depend" >> ${ROS_DEPS_BASE}/$pkg-BuildDepends
		;;
	"build_export_depend")
		echo "$depend" >> ${ROS_DEPS_BASE}/$pkg-BuildExportDepends
		echo "$depend" >> ${ROS_DEPS_BASE}/$pkg-ExecDepends
		;;
	"exec_depend")
		echo "$depend" >> ${ROS_DEPS_BASE}/$pkg-ExecDepends
		;;
	"run_depend")
		echo "$depend" >> ${ROS_DEPS_BASE}/$pkg-ExecDepends
		;;
	"test_depend")
		echo "$depend" >> ${ROS_DEPS_BASE}/$pkg-TestDepends
		;;
	"buildtool_depend")
		echo "$depend" >> ${ROS_DEPS_BASE}/$pkg-BuildToolDepends
		;;
	"buildtool_export_depend")
		echo "$depend" >> ${ROS_DEPS_BASE}/$pkg-BuildToolExportDepends
		;;
	"*")
		error_log "Wrong dep_name $dep_name"
		;;
	esac

	for i in $depend
	do
		match_ros_pkg=`echo $i | sed "s#_#-#g"`
		grep -Pq "^${match_ros_pkg}\t" ${ROS_PKG_LIST}
		if [ $? -eq 0 ]
		then
			dep="ros-%{ros_distro}-${match_ros_pkg}"
		else
			dep=$i
			echo "$i" >>${ROS_DEPS_BASE}/$pkg-ExtDeps
		fi

		case $dep_type in
		"all")
			write_dep Requires $dep ${ROS_DEPS_BASE}/$pkg-Requires
			write_dep BuildRequires $dep ${ROS_DEPS_BASE}/$pkg-BuildRequires
			;;
		"exec")
			write_dep Requires $dep ${ROS_DEPS_BASE}/$pkg-Requires
			;;
		"build")
			write_dep BuildRequires $dep ${ROS_DEPS_BASE}/$pkg-BuildRequires
			;;
		"test")
			write_dep BuildRequires $dep ${ROS_DEPS_BASE}/$pkg-test-BuildRequires
			;;
		"*")
			error_log "Wrong dep_type $dep_type"
			;;
		esac
	done

}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	while read pkg path version
	do
		if [ "$pkg" = "" -o "$path" = "" ]
		then
			continue
		fi

		if [ ! -f ${ROS_SRC_BASE}/${path}/package.xml ]
		then
			error_log "can not find package.xml in ${ROS_SRC_BASE}/${path}/"
			continue
		fi

		#if [ "$pkg" != "control-box-rst" ]
		#then
		#	continue
		#fi

		info_log "Gen depends for $pkg"

		>${ROS_DEPS_BASE}/$pkg-PackageXml
		python3 get-package-xml.py ${ROS_DEPS_BASE}/$pkg-PackageXml ${ROS_SRC_BASE}/${path}/package.xml

		gen_depend $pkg $path depend all
		gen_depend $pkg $path build_depend build
		gen_depend $pkg $path build_export_depend exec
		gen_depend $pkg $path exec_depend exec
		gen_depend $pkg $path run_depend exec
		gen_depend $pkg $path test_depend test
		gen_depend $pkg $path buildtool_depend build
		gen_depend $pkg $path buildtool_export_depend exec

	done < ${ROS_PKG_SRC}

	info_log "Gen ros-pkg-src.list done, you can find it in ${ROS_DEPS_BASE}"
}

main $*
