#
# Makefile for device
#

# To define any local-target
PWD=`pwd`
ORGIN_SECOND_FRAMEWORK_NAME := 
UPDATA_PACKAGE := ${PWD}/update.zip
CUSTOM_UPDATE := ${PWD}/custom-update
updater := $(ZIP_DIR)/META-INF/com/google/android/updater-script

COLOR_FRAMEWORK_JARS := android.policy framework telephony-common services pm
DST_SMALI_OUT := $(addsuffix .jar.out,$(COLOR_FRAMEWORK_JARS))
TMP_SYSTEM_DIR := ${PWD}/tmp_system
DST_JAR_OUT := $(addsuffix .jar,$(COLOR_FRAMEWORK_JARS))

default :
	@echo "This is default, do nothing "
	@echo "This is project written by oppo"
	@echo "Thank you for using this tool"

unzip_package :
	@echo "unzip package"
	@echo "${UPDATA_PACKAGE}"
	@echo "$(wildcard update.zip)"
    ifeq ($(wildcard update.zip), update.zip)
		rm -rf update
		unzip -q update.zip -d update
    else
		@echo "No update.zip in the compiled dir! Please put update.zip here!!!"
    endif

#below modified by oppo jizhengkang#
resource : unzip_package
#	cd $PORT_PORT
	rm -rf out/*
#	rm -rf framework-res
	mkdir -p out/gen
	mkdir -p out/gen-oppo
	
	java -jar ${PORT_TOOLS}/apktool.jar d -f update/system/framework/framework-res.apk  out/framework-res
	
	#compile framework-res.apk
	${PORT_TOOLS}/aapt p -f -m -x -z -J out/gen -S ${PORT_BUILD}/res-build/oppo-overlay/res/ -S out/framework-res/res  -M out/framework-res/AndroidManifest.xml -F out/framework-res-unsigned.apk -P out/gen/public_resources.xml -A out/framework-res/assets --auto-add-overlay 
	
	#sign framework-res.apk
	java -jar ${PORT_TOOLS}/signapk.jar ${PORT_BUILD}/res-build/oppo-security/platform.x509.pem ${PORT_BUILD}/res-build/oppo-security/platform.pk8  out/framework-res-unsigned.apk  out/framework-res.apk
	
	#compile oppo res
	${PORT_TOOLS}/aapt p -f -m -x -z -J out/gen-oppo -S ${PORT_BUILD}/res-build/oppo-framework-res/res  -M ${PORT_BUILD}/res-build/oppo-framework-res/AndroidManifest.xml -F out/oppo-framework-res-unsigned.apk -P out/gen-oppo/public_resources.xml -A ${PORT_BUILD}/res-build/oppo-framework-res/assets --oppo-package 12 --oppo-public-id 1024 -I out/framework-res.apk
	
	#sign oppo-framework-res.apk
	java -jar ${PORT_TOOLS}/signapk.jar ${PORT_BUILD}/res-build/oppo-security/platform.x509.pem ${PORT_BUILD}/res-build/oppo-security/platform.pk8  out/oppo-framework-res-unsigned.apk  out/oppo-framework-res.apk

baksmali-jar : unzip_package
	rm -rf smali/
	mkdir smali
	${PORT_TOOLS}/baksmali -a 17 -l update/system/framework/android.policy.jar -o smali/android.policy.jar.out
	${PORT_TOOLS}/baksmali -a 17 -l update/system/framework/framework.jar -o smali/framework.jar.out
	${PORT_TOOLS}/baksmali -a 17 -l update/system/framework/pm.jar -o smali/pm.jar.out
	${PORT_TOOLS}/baksmali -a 17 -l update/system/framework/services.jar -o smali/services.jar.out
	${PORT_TOOLS}/baksmali -a 17 -l update/system/framework/telephony-common.jar -o smali/telephony-common.jar.out
    ifneq ($(ORGIN_SECOND_FRAMEWORK_NAME), )
		${PORT_TOOLS}/baksmali -a 17 -l update/system/framework/${ORGIN_SECOND_FRAMEWORK_NAME} -o smali/${ORGIN_SECOND_FRAMEWORK_NAME}.out
		cp -rf smali/${ORGIN_SECOND_FRAMEWORK_NAME}.out/* smali/framework.jar.out/
		rm -rf smali/${ORGIN_SECOND_FRAMEWORK_NAME}.out
    endif



define JAR_template
${1}.jar.out : 
	echo "baksmali single jar file ->${1}.jar.out "
	mkdir -p smali
	rm -f ${TMP_SYSTEM_DIR}/system/framework/${1}.jar
	unzip ${UPDATA_PACKAGE} system/framework/${1}.jar -d ${TMP_SYSTEM_DIR}
	${PORT_TOOLS}/apktool d ${TMP_SYSTEM_DIR}/system/framework/${1}.jar smali/$$@
	
${1}.jar :
	echo "smali single jar file ->${1}.jar"
#	rm -rf smali_out
#	mkdir -p smali_out
	mkdir -p out/framework
#	cp -rf smali/${1}.jar.out smali_out/smali
#	echo "version: 1.5.2" > smali_out/apktool.yml
#	echo "apkFileName: ${1}.jar" >> smali_out/apktool.yml
	${PORT_TOOLS}/apktool b smali/${1}.jar.out out/framework/${1}.jar
endef


$(foreach jar, $(COLOR_FRAMEWORK_JARS), \
	$(eval $(call JAR_template,$(jar))))

cleansmali :
	echo "cleansmali"
	rm -rf ${TMP_SYSTEM_DIR}
	rm -rf smali
	
	mkdir -p ${TMP_SYSTEM_DIR}
	mkdir -p smali
	
	echo ""

getsmali1 : ${DST_SMALI_OUT} ${TMP_OUT_DIR}
	echo "test"
	rm -rf ${TMP_SYSTEM_DIR}
	rm -rf smali
	
	mkdir -p ${TMP_SYSTEM_DIR}
	mkdir -p smali

makesmali : ${DST_JAR_OUT}
.PHONY : makesmali

getsmali : cleansmali ${DST_SMALI_OUT} ${TMP_OUT_DIR}
.PHONY : getsmali

firstpatch : getsmali resource
        ifneq ($(ORGIN_SECOND_FRAMEWORK_NAME), )
		cp -rf smali/${ORGIN_SECOND_FRAMEWORK_NAME}.out/* smali/framework.jar.out/
		rm -rf smali/${ORGIN_SECOND_FRAMEWORK_NAME}.out
        endif
	${PORT_TOOLS}/patch_color_framework.sh ${PORT_ROOT}/smali/android ${PORT_ROOT}/smali/color ${PWD}/smali/
	
fullota : ${DST_JAR_OUT}
	@echo "Build the full update package"
	rm -rf new-update/
	cp -rf update/ new-update/
	rm -rf new-update/system/app/*
	@echo "${PORT_BUILD}/ColorSystem/*"
	cp -rf ${PORT_BUILD}/ColorSystem/* new-update/system
	cp -rf out/framework new-update/system
	cp out/framework-res.apk new-update/system/framework/
	cp out/oppo-framework-res.apk new-update/system/framework/

#we will use $(CUSTOM_UPDATE) to cover, so you need put your change file or some apk can't be deleted
    ifeq ($(wildcard ${PWD}/${CUSTOM_UPDATE}), ${PWD}/${CUSTOM_UPDATE})
		cp -rf ${PWD}/${CUSTOM_UPDATE}/* new-update/
    endif

	${PORT_TOOLS}/resign.sh dir new-update
	rm -f color-update.zip
	cd new-update/; zip -q -r -y color-update.zip .; mv color-update.zip ..

clean :
	rm -rf out/
	rm -rf smali/
	rm -rf temp/
	rm -rf update/
	rm -rf new-update/
	rm -rf tmp_*
	
