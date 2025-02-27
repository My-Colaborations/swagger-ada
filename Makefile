
NAME=swagger

-include Makefile.conf

STATIC_MAKE_ARGS = $(MAKE_ARGS) -XSWAGGER_LIBRARY_TYPE=static
SHARED_MAKE_ARGS = $(MAKE_ARGS) -XSWAGGER_LIBRARY_TYPE=relocatable
SHARED_MAKE_ARGS += -XSERVLETADA_CORE_BUILD=relocatable
SHARED_MAKE_ARGS += -XSERVLET_LIBRARY_TYPE=relocatable
SHARED_MAKE_ARGS += -XSERVLETADA_UNIT_BUILD=relocatable
SHARED_MAKE_ARGS += -XSERVLET_UNIT_LIBRARY_TYPE=relocatable
SHARED_MAKE_ARGS += -XELADA_BUILD=relocatable -XEL_LIBRARY_TYPE=relocatable
SHARED_MAKE_ARGS += -XSECURITYADA_BUILD=relocatable -XSECURITY_LIBRARY_TYPE=relocatable
SHARED_MAKE_ARGS += -XUTILADA_BASE_BUILD=relocatable -XUTIL_LIBRARY_TYPE=relocatable
SHARED_MAKE_ARGS += -XXMLADA_BUILD=relocatable
SHARED_MAKE_ARGS += -XXMLADA_BUILD=relocatable -XAWS_BUILD=relocatable
SHARED_MAKE_ARGS += -XUTILADA_HTTP_AWS_BUILD=relocatable
SHARED_MAKE_ARGS += -XUTILADA_HTTP_AWS_LIBRARY_TYPE=relocatable
SHARED_MAKE_ARGS += -XUTILADA_UNIT_BUILD=relocatable
SHARED_MAKE_ARGS += -XUTIL_UNIT_LIBRARY_TYPE=relocatable
SHARED_MAKE_ARGS += -XLIBRARY_TYPE=relocatable

include Makefile.defaults

build-test::  setup
	$(GNATMAKE) $(GPRFLAGS) -p -P$(NAME)_tests $(MAKE_ARGS)

ifeq (${HAVE_SERVER},yes)
setup:: src/server/swagger-servers-config.ads

src/server/swagger-servers-config.ads: Makefile src/server/swagger-servers-config.gpb
	gnatprep -DWEB_DIR=\"${prefix}/share/swagger-ada/web\" \
		src/server/swagger-servers-config.gpb $@
else
setup::
endif

SWAGGER=java -jar openapi-generator-cli.jar

generate:
	$(SWAGGER) generate --generator-name ada -i regtests/swagger.yaml \
            --additional-properties projectName=TestAPI \
            --model-package TestAPI -o regtests/client
	$(SWAGGER) generate --generator-name ada-server -i regtests/swagger.yaml \
            --additional-properties projectName=TestAPI \
            --model-package TestAPI -o regtests/server

# Build and run the unit tests
test:	build-test
ifeq (${HAVE_SERVER},yes)
	bin/testapi-server > testapi-server.log & \
        SERVER_PID=$$!; \
        sleep 1; \
	(test ! -f bin/swagger_harness_aws || \
          bin/swagger_harness_aws -l $(NAME):AWS: -p AWS -config tests.properties -xml swagger-aws-aunit.xml) ;\
	(test ! -f bin/swagger_harness_curl || \
          bin/swagger_harness_curl -l $(NAME):CURL: -p CURL -config tests.properties -xml swagger-curl-aunit.xml) ;\
        kill $$SERVER_PID
else
	test ! -f bin/swagger_harness_aws || \
          bin/swagger_harness_aws -p AWS -config tests-client.properties -xml swagger-aws-aunit.xml
	test ! -f bin/swagger_harness_curl || \
          bin/swagger_harness_curl -p CURL -config tests-client.properties -xml swagger-curl-aunit.xml
endif

install:: install-data

install-data::
	rm -rf $(DESTDIR)${prefix}/share/swagger-ada
	${MKDIR} -p $(DESTDIR)${prefix}/share/swagger-ada
	${CP} -rp web $(DESTDIR)${prefix}/share/swagger-ada/web
	${MKDIR} -p $(DESTDIR)${prefix}/bin
	$(INSTALL) openapi-generator.sh $(DESTDIR)$(prefix)/bin/openapi-generator
	$(CP) openapi-generator-cli.jar $(DESTDIR)$(prefix)/share/swagger-ada

$(eval $(call ada_library,$(NAME)))

ifeq ($(HAVE_SERVER),yes)
$(eval $(call ada_library,swagger_server))

build-test::
	$(GNATMAKE) $(GPRFLAGS) -p -Ptestapi_server $(MAKE_ARGS)

endif

