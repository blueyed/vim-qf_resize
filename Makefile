test: test_nvim

test_nvim:
	$(call func-run-tests,VADER_OUTPUT_FILE=/dev/stderr nvim --headless)

test_nvim_interactive:
	HOME=$(shell mktemp -d) nvim -u test/vimrc -c 'Vader test/*.vader'

test_vim:
	$(call func-run-tests,vim -X)

define func-run-tests
	$(1) --noplugin -Nu test/vimrc -c 'Vader! test/*.vader' >/dev/null
endef
