VIM ?= vim

.PHONY: test
test:
	$(VIM) -Nu NONE -i NONE -es --cmd 'set rtp^=.' -S test/test.vim
