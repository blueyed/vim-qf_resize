test: test_nvim

DEFAULT_VADER_DIR:=test/vim/plugins/vader
export TESTS_VADER_DIR:=$(firstword $(realpath $(wildcard test/vim/plugins/vader.override)) $(DEFAULT_VADER_DIR))
$(DEFAULT_VADER_DIR):
	mkdir -p $(dir $@)
	git clone --depth=1 -b display-source-with-exceptions https://github.com/blueyed/vader.vim $@

test_nvim: $(TESTS_VADER_DIR)
	$(call func-run-tests,VADER_OUTPUT_FILE=/dev/stderr nvim --headless)

test_nvim_interactive: $(TESTS_VADER_DIR)
	HOME=$(shell mktemp -d) nvim -u test/vimrc -c 'Vader test/*.vader'

run_nvim: $(TESTS_VADER_DIR)
	HOME=$(shell mktemp -d) nvim -u test/vimrc

test_vim: $(TESTS_VADER_DIR)
	$(call func-run-tests,vim -X)

define func-run-tests
	$(1) --noplugin -Nu test/vimrc -c 'Vader! test/*.vader' >/dev/null
endef
