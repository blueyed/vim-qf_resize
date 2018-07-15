SHELL:=/bin/bash -o pipefail

VADER_ARGS:=$(VADER_OPTIONS) test/*.vader

TESTS_VADER_DIR:=build/vader

test: test_nvim

# Add coloring to Vader's output.
_SED_HIGHLIGHT_ERRORS:=| contrib/highlight-log --compact vader
# Need to close stdin to fix spurious 'sed: couldn't write X items to stdout: Resource temporarily unavailable'.
# Redirect to stderr again for Docker (where only stderr is used from).
_REDIR_STDOUT:=2>&1 </dev/null >/dev/null $(_SED_HIGHLIGHT_ERRORS)

test_nvim: TEST_VIM_BIN ?= nvim
test_nvim: $(TESTS_VADER_DIR)
	$(call func-run-tests,env VADER_OUTPUT_FILE=/dev/stderr $(TEST_VIM_BIN) --headless)

test_nvim_interactive: TEST_VIM_BIN ?= nvim
test_nvim_interactive: _REDIR_STDOUT:=
test_nvim_interactive: $(TESTS_VADER_DIR)
	$(call func-run-tests,$(TEST_VIM_BIN))

run_nvim: _REDIR_STDOUT:=
run_nvim: TEST_VIM_ARGS:=
run_nvim: TEST_VIM_BIN ?= nvim
run_nvim: $(TESTS_VADER_DIR)
	$(call func-run-tests)

test_vim: TEST_VIM_BIN ?= vim
test_vim: $(TESTS_VADER_DIR)
	$(call func-run-tests,$(TEST_VIM_BIN) -X)

test_vim_interactive: _REDIR_STDOUT:=
test_vim_interactive: test_vim

# Ad-hoc, to cover the intermediate case (patch-8.0.0677).
# Uses v8.0.0688, which fixed the :resize also disallowed in v8.0.0677.
test_docker: _REDIR_STDOUT:=
test_docker: TEST_VIM_BIN=docker run --rm -v $(PWD):/testplugin -w /testplugin -e TESTS_VADER_DIR=/testplugin/build/vader thinca/vim:v8.0.0688
test_docker: $(TESTS_VADER_DIR)
	$(call func-run-tests,$(TEST_VIM_BIN) -X)

_COVIMERAGE=$(if $(filter-out 0,$(VIM_QF_RESIZE_DO_COVERAGE)),covimerage run --profile-file build/covimerage.profile --no-report --no-write-data ,)
TEST_VIM_ARGS=-c 'Vader! $(VADER_ARGS)'
define func-run-tests
	$(_COVIMERAGE)env HOME=$(shell mktemp -d) TESTS_VADER_DIR=$(TESTS_VADER_DIR) $(or $(1),$(1),$(TEST_VIM_BIN)) --noplugin -Nu test/vimrc -s /dev/null $(TEST_VIM_ARGS) $(_REDIR_STDOUT)
	$(if $(filter-out 0,$(VIM_QF_RESIZE_DO_COVERAGE)),sed -i 's~/testplugin/~$(CURDIR)/~' build/covimerage.profile;covimerage write_coverage build/covimerage.profile,)
endef

build:
	mkdir $@

LINT_ARGS:=./plugin ./autoload

build/vader: | build
	mkdir -p $(dir $@)
	git clone --depth=1 -b display-source-with-exceptions https://github.com/blueyed/vader.vim $@

build/vint: | build
	virtualenv -p python3 $@
	$@/bin/pip install vim-vint
vint: build/vint
	build/vint/bin/vint $(LINT_ARGS)
vint-errors: build/vint
	build/vint/bin/vint --error $(LINT_ARGS)

# vimlint
build/vimlint: | build
	git clone --depth=1 https://github.com/syngan/vim-vimlint $@
build/vimlparser: | build
	git clone --depth=1 https://github.com/ynkdir/vim-vimlparser $@
vimlint: build/vimlint build/vimlparser
	build/vimlint/bin/vimlint.sh -u -l build/vimlint -p build/vimlparser $(LINT_ARGS)

testcoverage:
	$(RM) .coverage.covimerage
	@ret=0; \
	for testfile in $(VADER_ARGS); do \
	  make test VADER_ARGS=$$testfile VIM_QF_RESIZE_DO_COVERAGE=1 || (( ++ret )); \
	done; \
	exit $$ret
