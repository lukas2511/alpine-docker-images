.PHONY: all
all:
	@./make.sh

%:
	@./make.sh $@ || true
