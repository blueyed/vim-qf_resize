SHELL:=/bin/bash -o pipefail

test: test_nvim

DEFAULT_VADER_DIR:=test/vim/plugins/vader
export TESTS_VADER_DIR:=$(firstword $(realpath $(wildcard test/vim/plugins/vader.override)) $(DEFAULT_VADER_DIR))
$(DEFAULT_VADER_DIR):
	mkdir -p $(dir $@)
	git clone --depth=1 -b display-source-with-exceptions https://github.com/blueyed/vader.vim $@

# Add coloring to Vader's output.
_SED_HIGHLIGHT_ERRORS:=| contrib/highlight-log --compact vader
# Need to close stdin to fix spurious 'sed: couldn't write X items to stdout: Resource temporarily unavailable'.
# Redirect to stderr again for Docker (where only stderr is used from).
_REDIR_STDOUT:=2>&1 </dev/null >/dev/null $(_SED_HIGHLIGHT_ERRORS) >&2

test_nvim: $(TESTS_VADER_DIR)
	$(call func-run-tests,VADER_OUTPUT_FILE=/dev/stderr nvim --headless)

test_nvim_interactive: $(TESTS_VADER_DIR)
	HOME=$(shell mktemp -d) nvim -u test/vimrc -c 'Vader test/*.vader'

run_nvim: $(TESTS_VADER_DIR)
	HOME=$(shell mktemp -d) nvim -u test/vimrc

test_vim: TEST_VIM_BIN ?= vim
test_vim: $(TESTS_VADER_DIR)
	$(call func-run-tests,$(TEST_VIM_BIN) -X)

define func-run-tests
	$(1) --noplugin -Nu test/vimrc -c 'Vader! test/*.vader' $(_REDIR_STDOUT)
endef

build:
	mkdir $@

LINT_ARGS:=./plugin ./autoload

build/vint: | build
	virtualenv $@
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
