BROWSER ?= /Applications/Google Chrome.app/Contents/MacOS/Google Chrome

.PHONY: demo test

demo:
	BROWSER="$(BROWSER)" vhs docs/demo.tape

test:
	bash tests/test_dj.sh
