project?=kubeedge
DESTDIR?=
USR_DIR?=/usr/local
INSTALL_DIR?=${DESTDIR}${USR_DIR}
INSTALL_BIN_DIR?=${INSTALL_DIR}/bin
INSTALL_EXT_DIR?=${INSTALL_DIR}/lib/${project}
INSTALL_SHARE_DIR?=${INSTALL_DIR}/share/${project}
INSTALL_ETC_DIR?=${DESTDIR}/etc/${project}

share_files+=$(shell find \
	cloud/conf \
	edge/conf \
	-type f -iname "*.yaml" \
	| sort)

# make all builds both cloud and edge binaries
.PHONY: all  
ifeq ($(WHAT),)
exes+=cloud/admission
exes+=cloud/cloudcore
exes+=edge/edgecore
exes+=edgesite/edgesite
exes+=keadm/keadm
all:
	cd cloud && $(MAKE)
	cd edge && $(MAKE)
	cd keadm && $(MAKE)
	cd edgesite && $(MAKE)
else ifeq ($(WHAT),cloudcore)
exes+=cloud/cloudcore
# make all WHAT=cloudcore
all:
	cd cloud && $(MAKE) cloudcore
else ifeq ($(WHAT),admission)
exes+=cloud/admission
# make all WHAT=admission
all:
	cd cloud && $(MAKE) admission
else ifeq ($(WHAT),edgecore)
exes+=edge/edgecore
all:
# make all WHAT=edgecore
	cd edge && $(MAKE)
else ifeq ($(WHAT),edgesite)
exes+=edgesite/edgesite
all:
# make all WHAT=edgesite
	$(MAKE) -C edgesite
else ifeq ($(WHAT),keadm)
exes+=keadm/keadm
all:
# make all WHAT=keadm
	cd keadm && $(MAKE)
else
# invalid entry
all:
	@echo $S"invalid option please choose to build either cloudcore, admission, edgecore, keadm, edgesite or all together"
endif

# unit tests
.PHONY: edge_test
edge_test:
	cd edge && $(MAKE) test

.PHONY: cloud_test
cloud_test:
	$(MAKE) -C cloud test

# lint
.PHONY: edge_lint
edge_lint:
	cd edge && $(MAKE) lint

.PHONY: edge_integration_test
edge_integration_test:
	cd edge && $(MAKE) integration_test

.PHONY: edge_cross_build
edge_cross_build:
	cd edge && $(MAKE) cross_build

.PHONY: edge_cross_build_v7
edge_cross_build_v7:
	$(MAKE) -C edge armv7

.PHONY: edge_cross_build_v8
edge_cross_build_v8:
	$(MAKE) -C edge armv8

.PHONY: edgesite_cross_build
edgesite_cross_build:
	$(MAKE) -C edgesite cross_build

.PHONY: edge_small_build
edge_small_build:
	cd edge && $(MAKE) small_build

.PHONY: edgesite_cross_build_v7
edgesite_cross_build_v7:
	$(MAKE) -C edgesite armv7

.PHONY: edgesite_cross_build_v8
edgesite_cross_build_v8:
	$(MAKE) -C edgesite armv8

.PHONY: cloud_lint
cloud_lint:
	cd cloud && $(MAKE) lint

.PHONY: e2e_test
e2e_test:
#	bash tests/e2e/scripts/execute.sh device_crd
#	This has been commented temporarily since there is an issue of CI using same master for all PRs, which is causing failures when run parallely
	bash tests/e2e/scripts/execute.sh

.PHONY: performance_test
performance_test:
	bash tests/performance/scripts/jenkins.sh

.PHONY: keadm_lint
keadm_lint:
	make -C keadm lint

QEMU_ARCH ?= x86_64
ARCH ?= amd64

IMAGE_TAG ?= $(shell git describe --tags)

.PHONY: cloudimage
cloudimage:
	docker build -t kubeedge/cloudcore:${IMAGE_TAG} -f build/cloud/Dockerfile .

.PHONY: admissionimage
admissionimage:
	docker build -t kubeedge/admission:${IMAGE_TAG} -f build/admission/Dockerfile .

.PHONY: csidriverimage
csidriverimage:
	docker build -t kubeedge/csidriver:${IMAGE_TAG} -f build/csidriver/Dockerfile .

.PHONY: edgeimage
edgeimage:
	mkdir -p ./build/edge/tmp
	rm -rf ./build/edge/tmp/*
	curl -L -o ./build/edge/tmp/qemu-${QEMU_ARCH}-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/v3.0.0/qemu-${QEMU_ARCH}-static.tar.gz 
	tar -xzf ./build/edge/tmp/qemu-${QEMU_ARCH}-static.tar.gz -C ./build/edge/tmp 
	docker build -t kubeedge/edgecore:${IMAGE_TAG} \
	--build-arg BUILD_FROM=${ARCH}/golang:1.12-alpine3.9 \
	--build-arg RUN_FROM=${ARCH}/docker:dind \
	-f build/edge/Dockerfile .

.PHONY: edgesiteimage
edgesiteimage:
	mkdir -p ./build/edgesite/tmp
	rm -rf ./build/edgesite/tmp/*
	curl -L -o ./build/edgesite/tmp/qemu-${QEMU_ARCH}-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/v3.0.0/qemu-${QEMU_ARCH}-static.tar.gz
	tar -xzf ./build/edgesite/tmp/qemu-${QEMU_ARCH}-static.tar.gz -C ./build/edgesite/tmp
	docker build -t kubeedge/edgesite:${IMAGE_TAG} \
	--build-arg BUILD_FROM=${ARCH}/golang:1.12-alpine3.9 \
	--build-arg RUN_FROM=${ARCH}/docker:dind \
	-f build/edgesite/Dockerfile .

.PHONY: verify
verify:
	bash hack/verify-golang.sh
	bash hack/verify-vendor.sh

.PHONY: bluetoothdevice
bluetoothdevice:
	make -C mappers/bluetooth_mapper

.PHONY: bluetoothdevice_image
bluetoothdevice_image:
	make -C mappers/bluetooth_mapper bluetooth_mapper_image

.PHONY: bluetoothdevice_lint
bluetoothdevice_lint:
	make -C mappers/bluetooth_mapper lint

install-binaries: ${exes}
	install -d ${INSTALL_BIN_DIR}
	install $^ ${INSTALL_BIN_DIR}

install-share: ${share_files}
	for file in $^ ; do \
install -d ${INSTALL_SHARE_DIR}/$${file}.tmp ; \
rmdir ${INSTALL_SHARE_DIR}/$${file}.tmp ; \
install -m 644 $${file} ${INSTALL_SHARE_DIR}/$${file} ; \
done

install-ext: build/tools/certgen.sh
	install -d ${INSTALL_EXT_DIR}/bin
	install $< ${INSTALL_EXT_DIR}/bin/

install-links:
	install -d ${INSTALL_ETC_DIR}
	ln -fs /usr/lib/${project}/certgen.sh ${INSTALL_ETC_DIR}/
	ln -fs /usr/share/${project}/cloud ${INSTALL_ETC_DIR}/
	ln -fs /usr/share/${project}/edge ${INSTALL_ETC_DIR}/

install: install-binaries install-share install-ext install-links
	-sync
