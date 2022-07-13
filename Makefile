print-%  : ; @echo $* = $($*)
PROJECT_NAME   = torchopt
COPYRIGHT      = "MetaOPT Team. All Rights Reserved."
PROJECT_PATH   = ${PROJECT_NAME}
SHELL          = /bin/bash
SOURCE_FOLDERS = $(PROJECT_PATH) examples include src tests
PYTHON_FILES   = $(shell find $(SOURCE_FOLDERS) -type f -name "*.py" -o -name "*.pyi")
CXX_FILES      = $(shell find $(SOURCE_FOLDERS) -type f -name "*.h" -o -name "*.cpp" -o -name "*.cuh" -o -name "*.cu")
COMMIT_HASH    = $(shell git log -1 --format=%h)
PATH           := $(HOME)/go/bin:$(PATH)
PYTHON         ?= $(shell command -v python3 || command -v python)

.PHONY: default
default: install

install:
	$(PYTHON) -m pip install .

# Tools Installation

check_pip_install = $(PYTHON) -m pip show $(1) &>/dev/null || (cd && $(PYTHON) -m pip install $(1) --upgrade)
check_pip_install_extra = $(PYTHON) -m pip show $(1) &>/dev/null || (cd && $(PYTHON) -m pip install $(2) --upgrade)

flake8-install:
	$(call check_pip_install,flake8)
	$(call check_pip_install_extra,bugbear,flake8_bugbear)

py-format-install:
	$(call check_pip_install,isort)
	$(call check_pip_install,yapf)

mypy-install:
	$(call check_pip_install,mypy)

docs-install:
	$(call check_pip_install,pydocstyle)
	$(call check_pip_install,doc8)
	$(call check_pip_install,sphinx)
	$(call check_pip_install,sphinx_rtd_theme)
	$(call check_pip_install_extra,sphinxcontrib.spelling,sphinxcontrib.spelling pyenchant)

pytest-install:
	$(call check_pip_install,pytest)
	$(call check_pip_install,pytest_cov)
	$(call check_pip_install,pytest_xdist)

cpplint-install:
	$(call check_pip_install,cpplint)

clang-format-install:
	command -v clang-format || sudo apt-get install -y clang-format

clang-tidy-install:
	command -v clang-tidy || sudo apt-get install -y clang-tidy

go-install:
	# requires go >= 1.16
	command -v go || (sudo apt-get install -y golang-1.16 && sudo ln -sf /usr/lib/go-1.16/bin/go /usr/bin/go)

addlicense-install: go-install
	command -v addlicense || go install github.com/google/addlicense@latest

# Tests

pytest: pytest-install
	cd tests && $(PYTHON) -m pytest unit --cov ${PROJECT_PATH} --durations 0 -v --cov-report term-missing --color=yes

test: pytest

# Python linters

flake8: flake8-install
	$(PYTHON) -m flake8 $(PYTHON_FILES) --count --select=E9,F63,F7,F82,E225,E251 --show-source --statistics

py-format: py-format-install
	$(PYTHON) -m isort --project torchopt --check $(PYTHON_FILES) && \
	$(PYTHON) -m yapf --in-place --recursive $(PYTHON_FILES)

mypy: mypy-install
	$(PYTHON) -m mypy $(PROJECT_NAME)

# C++ linters

cpplint: cpplint-install
	$(PYTHON) -m cpplint $(CXX_FILES)

clang-format: clang-format-install
	clang-format --style=file -i $(CXX_FILES) -n --Werror

# Documentation

addlicense: addlicense-install
	addlicense -c $(COPYRIGHT) -l apache -y 2022 -check $(SOURCE_FOLDERS)

docstyle: docs-install
	$(PYTHON) -m pydocstyle $(PROJECT_NAME) && doc8 docs && make -C docs html SPHINXOPTS="-W"

docs: docs-install
	make -C docs html && cd _build/html && $(PYTHON) -m http.server

spelling: docs-install
	make -C docs spelling SPHINXOPTS="-W"

clean-docs:
	make -C docs clean

# Utility functions

lint: flake8 py-format mypy clang-format cpplint addlicense

format: py-format-install clang-format-install addlicense-install
	$(PYTHON) -m isort --project torchopt $(PYTHON_FILES)
	$(PYTHON) -m yapf --in-place --recursive $(PYTHON_FILES)
	clang-format -style=file -i $(CXX_FILES)
	addlicense -c $(COPYRIGHT) -l apache -y 2022 $(SOURCE_FOLDERS)

clean-py:
	find . -type f -name  '*.py[co]' -delete
	find . -depth -type d -name ".mypy_cache" -exec rm -r "{}" +
	find . -depth -type d -name ".pytest_cache" -exec rm -r "{}" +

clean-build:
	rm -rf build/ dist/
	rm -rf *.egg-info .eggs

clean: clean-py clean-build clean-docs