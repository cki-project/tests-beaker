TARGETS	= smart_testcases \
	  smart_xmlpieces

SRCS	= $(TARGETS) smart.py

all: $(TARGETS)

%: %.py
	cp $< $@ && chmod +x $@

clean:
	rm -f *.pyc

clobber: clean
	rm -f $(TARGETS)
cl: clobber

check: $(TARGETS)
	icat -c $(SRCS) && pep8 $(SRCS) && flake8 $(SRCS)
ck: check
